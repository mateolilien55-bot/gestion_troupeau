import 'package:flutter/material.dart';

import '../database/database.dart';

class ConsistencyScreen extends StatefulWidget {
  const ConsistencyScreen({super.key});

  @override
  State<ConsistencyScreen> createState() => _ConsistencyScreenState();
}

class _ConsistencyScreenState extends State<ConsistencyScreen> {
  final _database = DatabaseHelper.instance;
  List<String> _issues = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final db = await _database.database;
    final animals = await _database.getAnimals();
    final issues = <String>[];
    final byId = {for (final animal in animals) if (animal.id != null) animal.id!: animal};

    for (final animal in animals) {
      final mother = animal.motherId == null ? null : byId[animal.motherId];
      final father = animal.fatherId == null ? null : byId[animal.fatherId];
      if (mother != null && !mother.dateNaissance.isBefore(animal.dateNaissance)) {
        issues.add('${animal.identification} : mère née après ou le même jour que l’animal.');
      }
      if (father != null && !father.dateNaissance.isBefore(animal.dateNaissance)) {
        issues.add('${animal.identification} : père né après ou le même jour que l’animal.');
      }
      if (animal.status != 'Actif' && animal.exitDate != null) {
        final laterEvents = await db.rawQuery('''
          SELECT COUNT(*) AS total FROM (
            SELECT date FROM animal_events WHERE animal_id = ?
            UNION ALL SELECT date FROM reproduction_events WHERE animal_id = ?
            UNION ALL SELECT date FROM health_events WHERE animal_id = ?
            UNION ALL SELECT date FROM weight_records WHERE animal_id = ?
          ) WHERE date > ?
        ''', [animal.id, animal.id, animal.id, animal.id, animal.exitDate!.toIso8601String()]);
        final count = laterEvents.first['total'] as int? ?? 0;
        if (count > 0) issues.add('${animal.identification} : $count événement(s) après la sortie du troupeau.');
      }
    }

    final earlyCalvings = await db.rawQuery('''
      SELECT a.identification, r.date, a.date_naissance
      FROM reproduction_events r JOIN animals a ON a.id = r.animal_id
      WHERE r.type = 'velage'
    ''');
    for (final row in earlyCalvings) {
      final birth = DateTime.tryParse(row['date_naissance']?.toString() ?? '');
      final calving = DateTime.tryParse(row['date']?.toString() ?? '');
      if (birth != null && calving != null && calving.difference(birth).inDays < 540) {
        issues.add('${row['identification']} : vêlage enregistré avant 18 mois.');
      }
    }

    if (!mounted) return;
    setState(() {
      _issues = issues;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contrôle de cohérence')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _run,
              child: _issues.isEmpty
                  ? const ListView(children: [SizedBox(height: 180), Center(child: Text('Aucune incohérence détectée.'))])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _issues.length,
                      itemBuilder: (context, index) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded),
                          title: Text(_issues[index]),
                        ),
                      ),
                    ),
            ),
    );
  }
}
