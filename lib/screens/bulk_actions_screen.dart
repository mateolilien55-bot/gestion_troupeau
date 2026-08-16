import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import '../services/sync_queue.dart';

class BulkActionsScreen extends StatefulWidget {
  const BulkActionsScreen({super.key});

  @override
  State<BulkActionsScreen> createState() => _BulkActionsScreenState();
}

class _BulkActionsScreenState extends State<BulkActionsScreen> {
  final _database = DatabaseHelper.instance;
  List<Animal> _animals = const [];
  final Set<int> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final animals = await _database.getAnimals();
    if (!mounted) return;
    setState(() {
      _animals = animals.where((animal) => animal.id != null).toList();
      _loading = false;
    });
  }

  Future<void> _addNote() async {
    if (_selected.isEmpty) return;
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note pour ${_selected.length} animal(aux)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Ajouter')),
        ],
      ),
    );
    controller.dispose();
    if (note == null || note.isEmpty) return;
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final id in _selected) {
        await txn.insert('animal_events', {
          'animal_id': id,
          'date': DateTime.now().toIso8601String(),
          'type': 'note',
          'description': note,
        });
      }
    });
    await SyncQueue.enqueue(entity: 'animal_events', operation: 'bulk_insert', payload: {
      'animalIds': _selected.toList(),
      'type': 'note',
      'description': note,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Note ajoutée à ${_selected.length} animal(aux).')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actions en masse')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty ? null : _addNote,
            icon: const Icon(Icons.note_add_outlined),
            label: Text('Ajouter une note (${_selected.length})'),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _animals.length,
              itemBuilder: (context, index) {
                final animal = _animals[index];
                final id = animal.id!;
                return CheckboxListTile(
                  value: _selected.contains(id),
                  title: Text(animal.identification),
                  subtitle: Text('${animal.sexe ?? 'Inconnu'} • ${animal.status}'),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selected.add(id);
                    } else {
                      _selected.remove(id);
                    }
                  }),
                );
              },
            ),
    );
  }
}
