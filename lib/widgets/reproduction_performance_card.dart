import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';

class ReproductionPerformanceCard extends StatefulWidget {
  const ReproductionPerformanceCard({super.key, required this.animal});

  final Animal animal;

  @override
  State<ReproductionPerformanceCard> createState() => _ReproductionPerformanceCardState();
}

class _ReproductionPerformanceCardState extends State<ReproductionPerformanceCard> {
  final _database = DatabaseHelper.instance;
  _ReproductionPerformance? _performance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReproductionPerformanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animal.id != widget.animal.id) _load();
  }

  Future<void> _load() async {
    final animalId = widget.animal.id;
    if (animalId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final events = await _database.getReproductionEventsForAnimal(animalId);
    final children = await _database.getChildren(animalId);
    final db = await _database.database;

    final calvingEvents = events.where((event) => event.type == 'velage').toList();
    final calvingDates = calvingEvents.map((event) => _day(event.date)).toSet().toList()..sort();

    final maleCount = children.where((animal) => animal.normalizedSex == AnimalSex.male).length;
    final femaleCount = children.where((animal) => animal.normalizedSex == AnimalSex.female).length;
    final knownSexCount = maleCount + femaleCount;

    final birthsByDay = <DateTime, int>{};
    for (final child in children) {
      final day = _day(child.dateNaissance);
      birthsByDay[day] = (birthsByDay[day] ?? 0) + 1;
    }
    final twinCalvings = birthsByDay.values.where((count) => count >= 2).length;
    final calvingCount = calvingDates.isNotEmpty ? calvingDates.length : birthsByDay.length;

    final livingCount = children.where((animal) => animal.normalizedStatus != AnimalStatus.dead).length;

    final intervals = <int>[];
    for (var index = 1; index < calvingDates.length; index++) {
      intervals.add(calvingDates[index].difference(calvingDates[index - 1]).inDays);
    }

    final birthWeights = calvingEvents
        .map((event) => event.calfWeight)
        .whereType<double>()
        .where((weight) => weight > 0)
        .toList();

    final soldWeights = <double>[];
    for (final child in children.where((animal) => animal.normalizedStatus == AnimalStatus.sold)) {
      if (child.id == null) continue;
      final rows = await db.query(
        'weight_records',
        columns: ['weight'],
        where: 'animal_id = ?',
        whereArgs: [child.id],
        orderBy: 'date DESC',
        limit: 1,
      );
      if (rows.isNotEmpty && rows.first['weight'] is num) {
        soldWeights.add((rows.first['weight'] as num).toDouble());
      }
    }

    DateTime? expectedCalving;
    final breedings = events.where((event) => event.type == 'saillie').toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (breedings.isNotEmpty) {
      final latestBreeding = breedings.first;
      final laterOutcome = events.any(
        (event) =>
            event.date.isAfter(latestBreeding.date) &&
            (event.type == 'velage' || event.type == 'avortement'),
      );
      final laterNegativeDiagnosis = events.any(
        (event) =>
            event.date.isAfter(latestBreeding.date) &&
            event.type == 'diagnostic' &&
            event.pregnancyConfirmed == false,
      );
      if (!laterOutcome && !laterNegativeDiagnosis) {
        expectedCalving = latestBreeding.date.add(const Duration(days: 283));
      }
    }

    final performance = _ReproductionPerformance(
      calvingCount: calvingCount,
      malePercent: knownSexCount == 0 ? null : (maleCount / knownSexCount) * 100,
      femalePercent: knownSexCount == 0 ? null : (femaleCount / knownSexCount) * 100,
      twinPercent: calvingCount == 0 ? null : (twinCalvings / calvingCount) * 100,
      livingPercent: children.isEmpty ? null : (livingCount / children.length) * 100,
      lastInterval: intervals.isEmpty ? null : intervals.last,
      averageInterval: intervals.isEmpty ? null : intervals.reduce((a, b) => a + b) / intervals.length,
      expectedCalving: expectedCalving,
      averageBirthWeight: _average(birthWeights),
      averageSoldWeight: _average(soldWeights),
      calfCount: children.length,
      soldWeightCount: soldWeights.length,
    );

    if (!mounted) return;
    setState(() {
      _performance = performance;
      _loading = false;
    });
  }

  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  static double? _average(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _percent(double? value) => value == null ? '—' : '${value.toStringAsFixed(0)} %';
  String _days(num? value) => value == null ? '—' : '${value.round()} j';
  String _weight(double? value) => value == null ? '—' : '${value.toStringAsFixed(1)} kg';

  Widget _metric(BuildContext context, String label, String value, IconData icon, {String? hint}) {
    return Container(
      width: 154,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(hint, style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final performance = _performance;
    if (performance == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Performances de reproduction',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${performance.calvingCount} vêlage(s) • ${performance.calfCount} veau(x) enregistré(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(context, 'Vêlages', '${performance.calvingCount}', Icons.child_friendly),
                _metric(context, 'Veaux mâles', _percent(performance.malePercent), Icons.male),
                _metric(context, 'Veaux femelles', _percent(performance.femalePercent), Icons.female),
                _metric(context, 'Vêlages jumeaux', _percent(performance.twinPercent), Icons.group_outlined),
                _metric(
                  context,
                  'Veaux vivants',
                  _percent(performance.livingPercent),
                  Icons.favorite_outline,
                  hint: 'statut actuel ≠ Mort',
                ),
                _metric(context, 'Dernier IVV', _days(performance.lastInterval), Icons.swap_vert),
                _metric(context, 'IVV moyen', _days(performance.averageInterval), Icons.timeline),
                _metric(
                  context,
                  'Vêlage prévisionnel',
                  performance.expectedCalving == null ? '—' : _date(performance.expectedCalving!),
                  Icons.event_available_outlined,
                  hint: 'saillie + 283 jours',
                ),
                _metric(context, 'Poids naissance moyen', _weight(performance.averageBirthWeight), Icons.monitor_weight_outlined),
                _metric(
                  context,
                  'Poids moyen veaux vendus',
                  _weight(performance.averageSoldWeight),
                  Icons.sell_outlined,
                  hint: performance.soldWeightCount == 0 ? 'aucune pesée vendue' : '${performance.soldWeightCount} veau(x)',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReproductionPerformance {
  const _ReproductionPerformance({
    required this.calvingCount,
    required this.malePercent,
    required this.femalePercent,
    required this.twinPercent,
    required this.livingPercent,
    required this.lastInterval,
    required this.averageInterval,
    required this.expectedCalving,
    required this.averageBirthWeight,
    required this.averageSoldWeight,
    required this.calfCount,
    required this.soldWeightCount,
  });

  final int calvingCount;
  final double? malePercent;
  final double? femalePercent;
  final double? twinPercent;
  final double? livingPercent;
  final int? lastInterval;
  final double? averageInterval;
  final DateTime? expectedCalving;
  final double? averageBirthWeight;
  final double? averageSoldWeight;
  final int calfCount;
  final int soldWeightCount;
}
