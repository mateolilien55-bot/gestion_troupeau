import 'package:flutter/material.dart';

import '../database/database.dart';

class BreedingCalendarScreen extends StatefulWidget {
  const BreedingCalendarScreen({super.key});

  @override
  State<BreedingCalendarScreen> createState() => _BreedingCalendarScreenState();
}

class _BreedingCalendarScreenState extends State<BreedingCalendarScreen> {
  final _database = DatabaseHelper.instance;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, Object?>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final start = _month;
    final end = DateTime(_month.year, _month.month + 1);
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT r.date, r.type, r.notes, a.identification
      FROM reproduction_events r JOIN animals a ON a.id = r.animal_id
      WHERE r.date >= ? AND r.date < ?
      UNION ALL
      SELECT e.date, e.type, e.description, a.identification
      FROM animal_events e JOIN animals a ON a.id = e.animal_id
      WHERE e.date >= ? AND e.date < ?
      ORDER BY date ASC
    ''', [start.toIso8601String(), end.toIso8601String(), start.toIso8601String(), end.toIso8601String()]);
    if (!mounted) return;
    setState(() => _items = rows);
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  String _label(DateTime value) {
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${months[value.month - 1]} ${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendrier d’élevage')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(child: Text(_label(_month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('Aucun événement ce mois-ci.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final row = _items[index];
                      final date = DateTime.tryParse(row['date']?.toString() ?? '');
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(date?.day.toString() ?? '?')),
                          title: Text('${row['identification']} • ${row['type']}'),
                          subtitle: row['notes'] == null ? null : Text(row['notes'].toString()),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
