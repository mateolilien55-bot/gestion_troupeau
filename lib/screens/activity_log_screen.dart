import 'package:flutter/material.dart';

import '../database/database.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final _database = DatabaseHelper.instance;
  List<Map<String, Object?>> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT e.date, e.type, e.description AS details, a.identification
      FROM animal_events e JOIN animals a ON a.id = e.animal_id
      UNION ALL
      SELECT r.date, 'Reproduction: ' || r.type, r.notes, a.identification
      FROM reproduction_events r JOIN animals a ON a.id = r.animal_id
      UNION ALL
      SELECT h.date, 'Santé: ' || h.type, COALESCE(h.reason, h.notes), a.identification
      FROM health_events h JOIN animals a ON a.id = h.animal_id
      UNION ALL
      SELECT w.date, 'Poids', CAST(w.weight AS TEXT) || ' kg', a.identification
      FROM weight_records w JOIN animals a ON a.id = w.animal_id
      UNION ALL
      SELECT m.date, 'Mouvement: ' || m.type, COALESCE(m.reason, m.destination, m.notes), a.identification
      FROM animal_movements m JOIN animals a ON a.id = m.animal_id
      ORDER BY date DESC
      LIMIT 300
    ''');
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  String _date(Object? raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '');
    if (value == null) return raw?.toString() ?? '';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal d’activité')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _rows.isEmpty
                  ? const ListView(children: [SizedBox(height: 180), Center(child: Text('Aucune activité.'))])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        final details = row['details']?.toString().trim();
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.history)),
                            title: Text('${row['identification']} • ${row['type']}'),
                            subtitle: Text('${_date(row['date'])}${details == null || details.isEmpty ? '' : '\n$details'}'),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
