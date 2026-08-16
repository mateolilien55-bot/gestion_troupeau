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
  List<Animal> _ancestors = const [];
  List<Animal> _children = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.animal.id;
    if (id == null) return;
    final ancestors = await _database.getAncestors(id, maxGenerations: 3);
    final children = await _database.getChildren(id);
    if (!mounted) return;
    setState(() {
      _ancestors = ancestors;
      _children = children;
      _loading = false;
    });
  }

  Future<void> _open(Animal animal) async {
    if (animal.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnimalScreen(animalId: animal.id!)),
    );
    if (mounted) await _load();
  }

  Widget _animalTile(Animal animal, IconData icon) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(animal.identification),
        subtitle: Text('${animal.sexe ?? 'Inconnu'} • ${animal.race} • ${animal.status}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(animal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Filiation ${widget.animal.identification}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.pets)),
                    title: Text(widget.animal.identification),
                    subtitle: const Text('Animal sélectionné'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Ancêtres (3 générations)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_ancestors.isEmpty)
                  const Text('Aucun ancêtre renseigné.')
                else
                  ..._ancestors.map((animal) => _animalTile(animal, animal.normalizedSex == AnimalSex.male ? Icons.male : Icons.female)),
                const SizedBox(height: 20),
                Text('Descendants directs', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_children.isEmpty)
                  const Text('Aucun descendant direct enregistré.')
                else
                  ..._children.map((animal) => _animalTile(animal, Icons.child_friendly)),
              ],
            ),
    );
  }
}
