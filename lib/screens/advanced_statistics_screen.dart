import 'package:flutter/material.dart';

import '../database/database.dart';

class AdvancedStatisticsScreen extends StatefulWidget {
  const AdvancedStatisticsScreen({super.key});

  @override
  State<AdvancedStatisticsScreen> createState() => _AdvancedStatisticsScreenState();
}

class _AdvancedStatisticsScreenState extends State<AdvancedStatisticsScreen> {
  final _database = DatabaseHelper.instance;
  Map<String, int> _repro = const {};
  List<Map<String, Object?>> _health = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await _database.database;
    final reproRows = await db.rawQuery('SELECT type, COUNT(*) AS total FROM reproduction_events GROUP BY type');
    final healthRows = await db.rawQuery('''
      SELECT COALESCE(NULLIF(disease, ''), NULLIF(reason, ''), type) AS label, COUNT(*) AS total
      FROM health_events
      GROUP BY label
      ORDER BY total DESC
      LIMIT 15
    ''');
    if (!mounted) return;
    setState(() {
      _repro = {for (final row in reproRows) row['type'].toString(): (row['total'] as int? ?? 0)};
      _health = healthRows;
      _loading = false;
    });
  }

  Widget _metric(String label, int value) => Card(
        child: ListTile(
          title: Text(label),
          trailing: Text('$value', style: Theme.of(context).textTheme.headlineSmall),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques avancées')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Reproduction', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _metric('Saillies / IA', _repro['saillie'] ?? 0),
                  _metric('Diagnostics', _repro['diagnostic'] ?? 0),
                  _metric('Vêlages', _repro['velage'] ?? 0),
                  _metric('Avortements', _repro['avortement'] ?? 0),
                  _metric('Retours en chaleur', _repro['chaleur'] ?? 0),
                  const SizedBox(height: 20),
                  Text('Santé', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_health.isEmpty)
                    const Card(child: ListTile(title: Text('Aucun événement sanitaire.')))
                  else
                    ..._health.map((row) => Card(
                          child: ListTile(
                            title: Text(row['label']?.toString() ?? 'Non renseigné'),
                            trailing: Text('${row['total'] ?? 0}'),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
