import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import 'documents_screen.dart';

class DocumentsHubScreen extends StatefulWidget {
  const DocumentsHubScreen({super.key});

  @override
  State<DocumentsHubScreen> createState() => _DocumentsHubScreenState();
}

class _DocumentsHubScreenState extends State<DocumentsHubScreen> {
  final _database = DatabaseHelper.instance;
  List<Animal> _animals = const [];
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
      _animals = animals;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents joints')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _animals.length,
              itemBuilder: (context, index) {
                final animal = _animals[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.pets)),
                  title: Text(animal.identification),
                  subtitle: Text('${animal.sexe ?? 'Inconnu'} • ${animal.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: animal.id == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DocumentsScreen(animal: animal)),
                          ),
                );
              },
            ),
    );
  }
}
