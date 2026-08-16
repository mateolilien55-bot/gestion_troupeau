import 'package:flutter/material.dart';

import '../services/sync_queue.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  List<Map<String, dynamic>> _pending = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pending = await SyncQueue.pending();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider la file locale ?'),
        content: const Text('À utiliser seulement si les changements ont déjà été synchronisés ailleurs ou doivent être abandonnés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Vider')),
        ],
      ),
    );
    if (confirmed != true) return;
    await SyncQueue.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation hors ligne'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(_pending.isEmpty ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
                    ),
                    title: Text(_pending.isEmpty ? 'Aucun changement en attente' : '${_pending.length} changement(s) en attente'),
                    subtitle: const Text(
                      'L’application continue de fonctionner avec SQLite hors ligne. Les changements sont conservés localement pour une future synchronisation distante.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_pending.isNotEmpty) ...[
                  ..._pending.reversed.map(
                    (item) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.sync_problem_outlined),
                        title: Text('${item['operation']} • ${item['entity']}'),
                        subtitle: Text(item['createdAt']?.toString() ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Vider la file locale'),
                  ),
                ],
              ],
            ),
    );
  }
}
