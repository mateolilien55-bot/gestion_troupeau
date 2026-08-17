import 'dart:io';

import 'package:flutter/material.dart';

import '../models/animal.dart';
import '../services/document_store.dart';
import '../services/sync_queue.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.animal});
  final Animal animal;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<AnimalDocument> _documents = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.animal.id;
    if (id == null) return;
    final documents = await DocumentStore.forAnimal(id);
    if (!mounted) return;
    setState(() {
      _documents = documents;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final pathController = TextEditingController();
    final categoryController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'Chemin du fichier',
                hintText: '/chemin/vers/document.pdf',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                hintText: 'Ordonnance, certificat, facture…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'path': pathController.text.trim(),
              'category': categoryController.text.trim(),
            }),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    pathController.dispose();
    categoryController.dispose();
    if (result == null || result['path']?.isEmpty != false || widget.animal.id == null) return;
    try {
      final document = await DocumentStore.importFromPath(
        animalId: widget.animal.id!,
        sourcePath: result['path']!,
        category: result['category']?.isEmpty == true ? null : result['category'],
      );
      await SyncQueue.enqueue(entity: 'animal_document', operation: 'insert', payload: document.toJson());
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import impossible : $e')));
    }
  }

  Future<void> _delete(AnimalDocument document) async {
    await DocumentStore.delete(document);
    await SyncQueue.enqueue(entity: 'animal_document', operation: 'delete', payload: {'id': document.id, 'animalId': document.animalId});
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Documents - ${widget.animal.identification}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.attach_file),
        label: const Text('Ajouter'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('Aucun document joint.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final document = _documents[index];
                    final exists = File(document.path).existsSync();
                    return Card(
                      child: ListTile(
                        leading: Icon(exists ? Icons.description_outlined : Icons.error_outline),
                        title: Text(document.name),
                        subtitle: Text(
                          '${document.category ?? 'Document'}\n${document.path}${exists ? '' : '\nFichier local manquant'}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Supprimer',
                          onPressed: () => _delete(document),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
