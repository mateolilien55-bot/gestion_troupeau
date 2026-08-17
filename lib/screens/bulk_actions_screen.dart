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

  Future<void> _changeStatus() async {
    if (_selected.isEmpty) return;
    final status = await showModalBottomSheet<AnimalStatus>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AnimalStatus.values
              .map(
                (value) => ListTile(
                  title: Text(value.label),
                  onTap: () => Navigator.pop(context, value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (status == null) return;
    final db = await _database.database;
    final exitDate = status == AnimalStatus.active ? null : DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final id in _selected) {
        await txn.update(
          'animals',
          {'status': status.label, 'exit_date': exitDate},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
    await SyncQueue.enqueue(entity: 'animals', operation: 'bulk_status', payload: {
      'animalIds': _selected.toList(),
      'status': status.label,
      'exitDate': exitDate,
    });
    await _load();
  }

  Future<void> _changeRole() async {
    if (_selected.isEmpty) return;
    const roles = ['Reproducteur', 'Non reproducteur', 'Inconnu'];
    final role = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles
              .map((value) => ListTile(title: Text(value), onTap: () => Navigator.pop(context, value)))
              .toList(),
        ),
      ),
    );
    if (role == null) return;
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final id in _selected) {
        await txn.update('animals', {'reproductive_role': role}, where: 'id = ?', whereArgs: [id]);
      }
    });
    await SyncQueue.enqueue(entity: 'animals', operation: 'bulk_reproductive_role', payload: {
      'animalIds': _selected.toList(),
      'reproductiveRole': role,
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actions en masse'),
        actions: [
          IconButton(
            tooltip: 'Tout sélectionner',
            onPressed: _animals.isEmpty
                ? null
                : () => setState(() {
                      if (_selected.length == _animals.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(_animals.map((animal) => animal.id!));
                      }
                    }),
            icon: const Icon(Icons.select_all),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _addNote,
                icon: const Icon(Icons.note_add_outlined),
                label: Text('Note (${_selected.length})'),
              ),
              OutlinedButton.icon(
                onPressed: _selected.isEmpty ? null : _changeStatus,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Statut'),
              ),
              OutlinedButton.icon(
                onPressed: _selected.isEmpty ? null : _changeRole,
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Rôle reproducteur'),
              ),
            ],
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
                  subtitle: Text('${animal.sexe ?? 'Inconnu'} • ${animal.status} • ${animal.normalizedReproductiveRole.label}'),
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
