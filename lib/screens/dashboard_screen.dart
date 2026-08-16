import 'package:flutter/material.dart';

import '../database/database.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _database = DatabaseHelper.instance;
  Map<String, int>? _stats;
  List<String> _alerts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await _database.getDashboardStats();
    final alerts = await _database.getAlerts();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _alerts = alerts;
      _loading = false;
    });
  }

  Widget _stat(String label, int value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: _loading || stats == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _stat('Animaux actifs', stats['active'] ?? 0, Icons.pets),
                  _stat('Femelles actives', stats['females'] ?? 0, Icons.female),
                  _stat('Mâles actifs', stats['males'] ?? 0, Icons.male),
                  _stat('Naissances cette année', stats['birthsThisYear'] ?? 0, Icons.child_friendly),
                  _stat('Filiations incomplètes', stats['missingParents'] ?? 0, Icons.account_tree_outlined),
                  _stat('Événements de reproduction', stats['reproductionEvents'] ?? 0, Icons.favorite_outline),
                  const SizedBox(height: 16),
                  Text('Alertes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_alerts.isEmpty)
                    const Card(child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('Aucune alerte.')))
                  else
                    ..._alerts.map(
                      (alert) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded),
                          title: Text(alert),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
