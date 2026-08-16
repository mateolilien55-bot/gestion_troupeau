import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import '../models/weight_record.dart';
import '../services/sync_queue.dart';

class WeightChartScreen extends StatefulWidget {
  const WeightChartScreen({super.key, required this.animal});
  final Animal animal;

  @override
  State<WeightChartScreen> createState() => _WeightChartScreenState();
}

class _WeightChartScreenState extends State<WeightChartScreen> {
  final _database = DatabaseHelper.instance;
  List<WeightRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.animal.id;
    if (id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final records = await _database.getWeightRecordsForAnimal(id);
    records.sort((a, b) => a.date.compareTo(b.date));
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  double? get _gainPerDay {
    if (_records.length < 2) return null;
    final first = _records.first;
    final last = _records.last;
    final days = last.date.difference(first.date).inDays;
    if (days <= 0) return null;
    return (last.weight - first.weight) / days;
  }

  WeightRecord? _previousRecord(DateTime recordDate) {
    WeightRecord? previous;
    for (final record in _records) {
      if (!record.date.isAfter(recordDate)) previous = record;
    }
    return previous;
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer quand même')),
            ],
          ),
        ) ?? false;
  }

  Future<void> _addWeight() async {
    final animalId = widget.animal.id;
    if (animalId == null) return;

    final weightController = TextEditingController();
    final notesController = TextEditingController();
    var selectedDate = DateTime.now();

    final result = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nouvelle pesée', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Animal ${widget.animal.identification}'),
                if (_records.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Dernière pesée : ${_records.last.weight.toStringAsFixed(1)} kg le ${_date(_records.last.date)}'),
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: weightController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Poids',
                    suffixText: 'kg',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'La virgule et le point sont acceptés.',
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: widget.animal.dateNaissance,
                      lastDate: DateTime.now(),
                      helpText: 'Date de la pesée',
                    );
                    if (picked != null) setSheetState(() => selectedDate = picked);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Date : ${_date(selectedDate)}'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (facultatif)',
                    hintText: 'Ex. sortie d’hiver, sevrage, contrôle…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    final normalized = weightController.text.trim().replaceAll(',', '.');
                    final weight = double.tryParse(normalized);
                    if (weight == null || weight <= 0 || weight > 2000) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Saisissez un poids valide entre 0 et 2000 kg.')),
                      );
                      return;
                    }
                    Navigator.pop(sheetContext, {
                      'weight': weight,
                      'date': selectedDate,
                      'notes': notesController.text.trim(),
                    });
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer la pesée'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    weightController.dispose();
    notesController.dispose();
    if (result == null) return;

    final weight = result['weight']! as double;
    final recordDate = result['date']! as DateTime;
    final notes = result['notes'] as String?;
    final selectedDay = _day(recordDate);

    final duplicateDate = _records.any((record) => _day(record.date) == selectedDay);
    if (duplicateDate) {
      final proceed = await _confirm(
        'Pesée déjà présente',
        'Une pesée existe déjà le ${_date(recordDate)} pour cet animal. Voulez-vous enregistrer une deuxième pesée ce jour-là ?',
      );
      if (!proceed) return;
    }

    final previous = _previousRecord(recordDate);
    if (previous != null && previous.weight > 0) {
      final difference = weight - previous.weight;
      final percent = (difference.abs() / previous.weight) * 100;
      if (percent >= 25) {
        final sign = difference >= 0 ? '+' : '';
        final proceed = await _confirm(
          'Écart de poids important',
          'La précédente pesée était de ${previous.weight.toStringAsFixed(1)} kg. '
          'La nouvelle valeur représente $sign${difference.toStringAsFixed(1)} kg '
          '($sign${((difference / previous.weight) * 100).toStringAsFixed(0)} %). Vérifiez la saisie.',
        );
        if (!proceed) return;
      }
    }

    final record = WeightRecord(
      animalId: animalId,
      date: recordDate,
      weight: weight,
      notes: notes?.isEmpty == true ? null : notes,
    );

    try {
      await _database.insertWeightRecord(record);
      await SyncQueue.enqueue(entity: 'weight_record', operation: 'insert', payload: record.toMap());
      await _load();
      if (!mounted) return;
      final delta = previous == null ? null : weight - previous.weight;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delta == null
                ? 'Pesée enregistrée : ${weight.toStringAsFixed(1)} kg.'
                : 'Pesée enregistrée : ${weight.toStringAsFixed(1)} kg (${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d’enregistrer la pesée : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Poids - ${widget.animal.identification}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWeight,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle pesée'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (_records.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.monitor_weight_outlined, size: 44),
                            const SizedBox(height: 12),
                            const Text('Aucune pesée enregistrée pour cet animal.'),
                            const SizedBox(height: 12),
                            FilledButton.icon(onPressed: _addWeight, icon: const Icon(Icons.add), label: const Text('Enregistrer la première pesée')),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Évolution du poids', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            SizedBox(height: 260, width: double.infinity, child: CustomPaint(painter: _WeightChartPainter(records: _records))),
                            const SizedBox(height: 12),
                            Text('Dernier poids : ${_records.last.weight.toStringAsFixed(1)} kg'),
                            Text('Dernière pesée : ${_date(_records.last.date)}'),
                            if (_gainPerDay != null) Text('Gain moyen : ${(_gainPerDay! * 1000).toStringAsFixed(0)} g/jour'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Historique des pesées', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._records.reversed.map(
                      (record) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.monitor_weight_outlined)),
                          title: Text('${record.weight.toStringAsFixed(1)} kg'),
                          subtitle: Text('${_date(record.date)}${record.notes?.trim().isNotEmpty == true ? ' • ${record.notes}' : ''}'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  const _WeightChartPainter({required this.records});
  final List<WeightRecord> records;

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;
    const left = 46.0;
    const right = 12.0;
    const top = 16.0;
    const bottom = 30.0;
    final chartWidth = math.max(1.0, size.width - left - right).toDouble();
    final chartHeight = math.max(1.0, size.height - top - bottom).toDouble();
    final weights = records.map((record) => record.weight).toList();
    var minWeight = weights.reduce((a, b) => a < b ? a : b);
    var maxWeight = weights.reduce((a, b) => a > b ? a : b);
    if ((maxWeight - minWeight).abs() < 1) {
      minWeight -= 1;
      maxWeight += 1;
    }
    final firstDate = records.first.date;
    final lastDate = records.last.date;
    final totalDays = math.max(1, lastDate.difference(firstDate).inDays).toDouble();
    final axisPaint = Paint()..color = Colors.grey..strokeWidth = 1;
    final linePaint = Paint()..color = Colors.green..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = Colors.green;
    canvas.drawLine(const Offset(left, top), Offset(left, top + chartHeight), axisPaint);
    canvas.drawLine(Offset(left, top + chartHeight), Offset(left + chartWidth, top + chartHeight), axisPaint);
    Offset pointFor(WeightRecord record) {
      final xFraction = record.date.difference(firstDate).inDays / totalDays;
      final yFraction = (record.weight - minWeight) / (maxWeight - minWeight);
      return Offset(left + (xFraction * chartWidth), top + chartHeight - (yFraction * chartHeight));
    }
    final path = Path();
    for (var index = 0; index < records.length; index++) {
      final point = pointFor(records[index]);
      if (index == 0) { path.moveTo(point.dx, point.dy); } else { path.lineTo(point.dx, point.dy); }
      canvas.drawCircle(point, 3.5, pointPaint);
    }
    canvas.drawPath(path, linePaint);
    const textStyle = TextStyle(fontSize: 11, color: Colors.black87);
    void drawText(String text, Offset offset) {
      final painter = TextPainter(text: TextSpan(text: text, style: textStyle), textDirection: TextDirection.ltr)..layout();
      painter.paint(canvas, offset);
    }
    drawText('${maxWeight.toStringAsFixed(0)} kg', const Offset(0, top - 6));
    drawText('${minWeight.toStringAsFixed(0)} kg', Offset(0, top + chartHeight - 8));
    drawText('${firstDate.day.toString().padLeft(2, '0')}/${firstDate.month.toString().padLeft(2, '0')}', Offset(left, top + chartHeight + 8));
    final lastLabel = '${lastDate.day.toString().padLeft(2, '0')}/${lastDate.month.toString().padLeft(2, '0')}';
    final lastPainter = TextPainter(text: TextSpan(text: lastLabel, style: textStyle), textDirection: TextDirection.ltr)..layout();
    lastPainter.paint(canvas, Offset(left + chartWidth - lastPainter.width, top + chartHeight + 8));
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) => oldDelegate.records != records;
}
