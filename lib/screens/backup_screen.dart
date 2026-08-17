import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _database = DatabaseHelper.instance;
  List<FileSystemEntity> _files = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final files = await _database.listBackups();
    if (!mounted) return;
    setState(() => _files = files);
  }

  Future<void> _run(Future<File> Function() action, String label) async {
    setState(() => _busy = true);
    try {
      final file = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label : ${file.path}')),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text('Les données actuelles seront remplacées par celles du fichier JSON.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurer')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _database.restoreJson(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sauvegarde restaurée.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restauration impossible : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde et export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(_database.createDatabaseBackup, 'Sauvegarde SQLite créée'),
            icon: const Icon(Icons.backup),
            label: const Text('Sauvegarder la base'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(_database.exportJson, 'Export JSON créé'),
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Exporter toutes les données en JSON'),
          ),
          const SizedBox(height: 24),
          Text('Fichiers disponibles', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_files.isEmpty)
            const Text('Aucune sauvegarde locale.')
          else
            ..._files.map((entity) {
              final file = File(entity.path);
              final name = entity.uri.pathSegments.isEmpty ? entity.path : entity.uri.pathSegments.last;
              final isJson = name.toLowerCase().endsWith('.json');
              return Card(
                child: ListTile(
                  leading: Icon(isJson ? Icons.data_object : Icons.storage),
                  title: Text(name),
                  subtitle: Text(entity.path),
                  trailing: isJson
                      ? IconButton(
                          tooltip: 'Restaurer',
                          onPressed: _busy ? null : () => _restore(file),
                          icon: const Icon(Icons.restore),
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }
}
