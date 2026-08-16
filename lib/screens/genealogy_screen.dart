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
    if (!mounted) return;
    setState(() {
      _animals = {
        for (final animal in animals)
          if (animal.id != null) animal.id!: animal,
      };
      _children = children;
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
    final animal = _animal(id);
    return _TreeNode(animal: animal, unknownLabel: unknownLabel);
  }

  List<_TreeNode> get _generation1 {
    return [
      _nodeFor(widget.animal.motherId, 'Mère inconnue'),
      _nodeFor(widget.animal.fatherId, 'Père inconnu'),
    ];
  }

  List<_TreeNode> get _generation2 {
    final mother = _animal(widget.animal.motherId);
    final father = _animal(widget.animal.fatherId);
    return [
      _nodeFor(mother?.motherId, 'Grand-mère maternelle inconnue'),
      _nodeFor(mother?.fatherId, 'Grand-père maternel inconnu'),
      _nodeFor(father?.motherId, 'Grand-mère paternelle inconnue'),
      _nodeFor(father?.fatherId, 'Grand-père paternel inconnu'),
    ];
  }

  List<_TreeNode> get _generation3 {
    final grandparents = _generation2.map((node) => node.animal).toList();
    final labels = [
      'Arrière-grand-mère inconnue',
      'Arrière-grand-père inconnu',
      'Arrière-grand-mère inconnue',
      'Arrière-grand-père inconnu',
      'Arrière-grand-mère inconnue',
      'Arrière-grand-père inconnu',
      'Arrière-grand-mère inconnue',
      'Arrière-grand-père inconnu',
    ];
    final nodes = <_TreeNode>[];
    for (var index = 0; index < grandparents.length; index++) {
      final ancestor = grandparents[index];
      nodes.add(_nodeFor(ancestor?.motherId, labels[index * 2]));
      nodes.add(_nodeFor(ancestor?.fatherId, labels[(index * 2) + 1]));
    }
    return nodes;
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
          width: 138,
          height: 82,
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

  Widget _generationLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      );

  Widget _tree() {
    const width = 1240.0;
    const height = 610.0;
    const cardWidth = 138.0;
    const cardHeight = 82.0;

    final positions = <Offset>[];

    List<Offset> rowPositions(int count, double y) {
      final gap = width / count;
      return List.generate(
        count,
        (index) => Offset((gap * index) + (gap / 2) - (cardWidth / 2), y),
      );
    }

    final gen3Positions = rowPositions(8, 34);
    final gen2Positions = rowPositions(4, 180);
    final gen1Positions = rowPositions(2, 326);
    final selectedPosition = Offset((width - cardWidth) / 2, 472);
    positions
      ..addAll(gen3Positions)
      ..addAll(gen2Positions)
      ..addAll(gen1Positions)
      ..add(selectedPosition);

    final connections = <_TreeConnection>[];
    for (var parentIndex = 0; parentIndex < 4; parentIndex++) {
      connections.add(_TreeConnection(from: parentIndex * 2, to: 8 + parentIndex));
      connections.add(_TreeConnection(from: (parentIndex * 2) + 1, to: 8 + parentIndex));
    }
    connections.addAll([
      const _TreeConnection(from: 8, to: 12),
      const _TreeConnection(from: 9, to: 12),
      const _TreeConnection(from: 10, to: 13),
      const _TreeConnection(from: 11, to: 13),
      const _TreeConnection(from: 12, to: 14),
      const _TreeConnection(from: 13, to: 14),
    ]);

    final nodes = <_TreeNode>[
      ..._generation3,
      ..._generation2,
      ..._generation1,
      _TreeNode(animal: widget.animal, unknownLabel: ''),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.account_tree),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Arbre généalogique — 3 générations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.swipe, size: 20),
                const SizedBox(width: 4),
                const Text('Faire défiler'),
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
                  Positioned(top: 4, left: 0, right: 0, child: _generationLabel('Arrière-grands-parents')),
                  Positioned(top: 150, left: 0, right: 0, child: _generationLabel('Grands-parents')),
                  Positioned(top: 296, left: 0, right: 0, child: _generationLabel('Parents')),
                  Positioned(top: 442, left: 0, right: 0, child: _generationLabel('Animal')),
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

  Widget _childrenSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.child_friendly),
                const SizedBox(width: 8),
                Text(
                  'Descendants directs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(label: Text('${_children.length}')),
              ],
            ),
            const SizedBox(height: 8),
            if (_children.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucun descendant direct enregistré.'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _children
                    .map(
                      (animal) => ActionChip(
                        avatar: Icon(
                          animal.normalizedSex == AnimalSex.male ? Icons.male : Icons.female,
                          size: 18,
                        ),
                        label: Text(animal.identification),
                        onPressed: () => _open(animal),
                      ),
                    )
                    .toList(),
              ),
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
                  _tree(),
                  const SizedBox(height: 12),
                  _childrenSection(),
                  const SizedBox(height: 12),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.touch_app_outlined),
                      title: Text('Navigation dans la famille'),
                      subtitle: Text('Touchez un animal de l’arbre ou un descendant pour ouvrir sa fiche complète.'),
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
