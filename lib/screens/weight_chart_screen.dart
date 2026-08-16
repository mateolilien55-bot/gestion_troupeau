import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import '../models/weight_record.dart';

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

  double? get _gainPerDay {
    if (_records.length < 2) return null;
    final first = _records.first;
    final last = _records.last;
    final days = last.date.difference(first.date).inDays;
    if (days <= 0) return null;
    return (last.weight - first.weight) / days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Courbe de poids - ${widget.animal.identification}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_records.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Aucune pesée enregistrée pour cet animal.'),
                      ),
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Évolution du poids',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 260,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _WeightChartPainter(records: _records),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Dernier poids : ${_records.last.weight.toStringAsFixed(1)} kg'),
                            if (_gainPerDay != null)
                              Text('Gain moyen : ${(_gainPerDay! * 1000).toStringAsFixed(0)} g/jour'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Historique des pesées',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._records.reversed.map(
                      (record) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.monitor_weight_outlined)),
                          title: Text('${record.weight.toStringAsFixed(1)} kg'),
                          subtitle: Text(
                            '${_date(record.date)}${record.notes?.trim().isNotEmpty == true ? ' • ${record.notes}' : ''}',
                          ),
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

    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = Colors.green;

    canvas.drawLine(const Offset(left, top), Offset(left, top + chartHeight), axisPaint);
    canvas.drawLine(Offset(left, top + chartHeight), Offset(left + chartWidth, top + chartHeight), axisPaint);

    Offset pointFor(WeightRecord record) {
      final xFraction = record.date.difference(firstDate).inDays / totalDays;
      final yFraction = (record.weight - minWeight) / (maxWeight - minWeight);
      return Offset(
        left + (xFraction * chartWidth),
        top + chartHeight - (yFraction * chartHeight),
      );
    }

    final path = Path();
    for (var index = 0; index < records.length; index++) {
      final point = pointFor(records[index]);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 3.5, pointPaint);
    }
    canvas.drawPath(path, linePaint);

    const textStyle = TextStyle(fontSize: 11, color: Colors.black87);
    void drawText(String text, Offset offset) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, offset);
    }

    drawText('${maxWeight.toStringAsFixed(0)} kg', const Offset(0, top - 6));
    drawText('${minWeight.toStringAsFixed(0)} kg', Offset(0, top + chartHeight - 8));
    drawText(
      '${firstDate.day.toString().padLeft(2, '0')}/${firstDate.month.toString().padLeft(2, '0')}',
      Offset(left, top + chartHeight + 8),
    );
    final lastLabel = '${lastDate.day.toString().padLeft(2, '0')}/${lastDate.month.toString().padLeft(2, '0')}';
    final lastPainter = TextPainter(
      text: TextSpan(text: lastLabel, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    lastPainter.paint(
      canvas,
      Offset(left + chartWidth - lastPainter.width, top + chartHeight + 8),
    );
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) => oldDelegate.records != records;
}
