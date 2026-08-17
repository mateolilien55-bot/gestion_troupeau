import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import 'animal_screen.dart';

class GenealogyScreen extends StatefulWidget {
  const GenealogyScreen({super.key, required this.animal});

  final Animal animal;

  @override
  State<GenealogyScreen> createState() => _GenealogyScreenState();
}

class _GenealogyScreenState extends State<GenealogyScreen> {
  final _database = DatabaseHelper.instance;
  Map<int, Animal> _animals = const {};
  List<Animal> _children = const [];
  Map<int, List<Animal>> _grandchildrenByChild = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final animals = await _database.getAnimals();
    final id = widget.animal.id;
    final children = id == null ? <Animal>[] : await _database.getChildren(id);
    final grandchildrenByChild = <int, List<Animal>>{};
    for (final child in children) {
      final childId = child.id;
      if (childId != null) {
        grandchildrenByChild[childId] = await _database.getChildren(childId);
      }
    }
    if (!mounted) return;
    setState(() {
      _animals = {
        for (final animal in animals)
          if (animal.id != null) animal.id!: animal,
      };
      _children = children;
      _grandchildrenByChild = grandchildrenByChild;
      _loading = false;
    });
  }

  Animal? _animal(int? id) => id == null ? null : _animals[id];

  Future<void> _open(Animal animal) async {
    if (animal.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnimalScreen(animalId: animal.id!)),
    );
    if (mounted) await _load();
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  _TreeNode _nodeFor(int? id, String unknownLabel) {
    return _TreeNode(animal: _animal(id), unknownLabel: unknownLabel);
  }

  List<_TreeNode> get _parents => [
        _nodeFor(widget.animal.motherId, 'Mère inconnue'),
        _nodeFor(widget.animal.fatherId, 'Père inconnu'),
      ];

  List<_TreeNode> get _grandparents {
    final mother = _animal(widget.animal.motherId);
    final father = _animal(widget.animal.fatherId);
    return [
      _nodeFor(mother?.motherId, 'Grand-mère maternelle inconnue'),
      _nodeFor(mother?.fatherId, 'Grand-père maternel inconnu'),
      _nodeFor(father?.motherId, 'Grand-mère paternelle inconnue'),
      _nodeFor(father?.fatherId, 'Grand-père paternel inconnu'),
    ];
  }

  Widget _treeCard(_TreeNode node, {bool selected = false}) {
    final animal = node.animal;
    final sex = animal?.normalizedSex;
    final icon = sex == AnimalSex.male
        ? Icons.male
        : sex == AnimalSex.female
            ? Icons.female
            : Icons.help_outline;

    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : animal == null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.surface,
      elevation: selected ? 3 : 1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: animal == null || selected ? null : () => _open(animal),
        child: SizedBox(
          width: 146,
          height: 84,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: 4),
                Text(
                  animal?.identification ?? node.unknownLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (animal != null)
                  Text(
                    '${animal.race} • ${_date(animal.dateNaissance)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
      );

  Widget _ancestorTree() {
    const width = 760.0;
    const height = 460.0;
    const cardWidth = 146.0;
    const cardHeight = 84.0;

    List<Offset> rowPositions(int count, double y) {
      final gap = width / count;
      return List.generate(count, (index) => Offset((gap * index) + (gap / 2) - (cardWidth / 2), y));
    }

    final grandparentPositions = rowPositions(4, 38);
    final parentPositions = rowPositions(2, 188);
    final selectedPosition = Offset((width - cardWidth) / 2, 338);
    final positions = <Offset>[
      ...grandparentPositions,
      ...parentPositions,
      selectedPosition,
    ];
    final connections = const [
      _TreeConnection(from: 0, to: 4),
      _TreeConnection(from: 1, to: 4),
      _TreeConnection(from: 2, to: 5),
      _TreeConnection(from: 3, to: 5),
      _TreeConnection(from: 4, to: 6),
      _TreeConnection(from: 5, to: 6),
    ];
    final nodes = <_TreeNode>[
      ..._grandparents,
      ..._parents,
      _TreeNode(animal: widget.animal, unknownLabel: ''),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.account_tree),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ascendance — 2 générations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.swipe, size: 20),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GenealogyPainter(
                        positions: positions,
                        connections: connections,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        lineColor: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  Positioned(top: 8, left: 0, right: 0, child: _label('Grands-parents')),
                  Positioned(top: 158, left: 0, right: 0, child: _label('Parents')),
                  Positioned(top: 308, left: 0, right: 0, child: _label('Animal')),
                  for (var index = 0; index < nodes.length; index++)
                    Positioned(
                      left: positions[index].dx,
                      top: positions[index].dy,
                      child: _treeCard(nodes[index], selected: index == nodes.length - 1),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _descendantTree() {
    final grandchildren = _grandchildrenByChild.values.expand((items) => items).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Descendance — 2 générations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(child: _treeCard(_TreeNode(animal: widget.animal, unknownLabel: ''), selected: true)),
            const SizedBox(height: 10),
            const Center(child: Icon(Icons.arrow_downward)),
            const SizedBox(height: 8),
            _label('Enfants'),
            const SizedBox(height: 8),
            if (_children.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('Aucun enfant enregistré.')))
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: _children.map((child) => _treeCard(_TreeNode(animal: child, unknownLabel: ''))).toList(),
              ),
            const SizedBox(height: 18),
            if (_children.isNotEmpty) ...[
              const Center(child: Icon(Icons.arrow_downward)),
              const SizedBox(height: 8),
              _label('Petits-enfants'),
              const SizedBox(height: 8),
              if (grandchildren.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('Aucun petit-enfant enregistré.')))
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: grandchildren.map((animal) => _treeCard(_TreeNode(animal: animal, unknownLabel: ''))).toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Filiation — ${widget.animal.identification}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ancestorTree(),
                  const SizedBox(height: 12),
                  _descendantTree(),
                  const SizedBox(height: 12),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.touch_app_outlined),
                      title: Text('Navigation dans la famille'),
                      subtitle: Text('Touchez un ascendant, un enfant ou un petit-enfant pour ouvrir sa fiche complète.'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TreeNode {
  const _TreeNode({required this.animal, required this.unknownLabel});
  final Animal? animal;
  final String unknownLabel;
}

class _TreeConnection {
  const _TreeConnection({required this.from, required this.to});
  final int from;
  final int to;
}

class _GenealogyPainter extends CustomPainter {
  const _GenealogyPainter({
    required this.positions,
    required this.connections,
    required this.cardWidth,
    required this.cardHeight,
    required this.lineColor,
  });

  final List<Offset> positions;
  final List<_TreeConnection> connections;
  final double cardWidth;
  final double cardHeight;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final connection in connections) {
      final fromPosition = positions[connection.from];
      final toPosition = positions[connection.to];
      final start = Offset(fromPosition.dx + (cardWidth / 2), fromPosition.dy + cardHeight);
      final end = Offset(toPosition.dx + (cardWidth / 2), toPosition.dy);
      final middleY = (start.dy + end.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx, middleY)
        ..lineTo(end.dx, middleY)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GenealogyPainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.lineColor != lineColor;
}
