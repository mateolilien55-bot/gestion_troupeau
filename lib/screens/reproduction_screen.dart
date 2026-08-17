import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import '../models/reproduction_event.dart';
import '../widgets/reproduction_performance_card.dart';

class ReproductionScreen extends StatefulWidget {
  const ReproductionScreen({super.key, required this.animal});
  final Animal animal;

  @override
  State<ReproductionScreen> createState() => _ReproductionScreenState();
}

class _ReproductionScreenState extends State<ReproductionScreen> {
  final _database = DatabaseHelper.instance;
  List<ReproductionEvent> _events = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.animal.id == null) return;
    final events = await _database.getReproductionEventsForAnimal(widget.animal.id!);
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _title(String type) {
    switch (type) {
      case 'velage':
        return 'Vêlage';
      case 'saillie':
        return 'Saillie / IA';
      case 'diagnostic':
        return 'Diagnostic de gestation';
      case 'avortement':
        return 'Avortement';
      case 'chaleur':
        return 'Retour en chaleur';
      default:
        return type;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'velage':
        return Icons.child_friendly;
      case 'saillie':
        return Icons.favorite;
      case 'diagnostic':
        return Icons.biotech;
      case 'avortement':
        return Icons.heart_broken_outlined;
      case 'chaleur':
        return Icons.autorenew;
      default:
        return Icons.event;
    }
  }

  Future<void> _add() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.child_friendly), title: const Text('Vêlage'), onTap: () => Navigator.pop(context, 'velage')),
          ListTile(leading: const Icon(Icons.favorite), title: const Text('Saillie / IA'), onTap: () => Navigator.pop(context, 'saillie')),
          ListTile(leading: const Icon(Icons.biotech), title: const Text('Diagnostic de gestation'), onTap: () => Navigator.pop(context, 'diagnostic')),
          ListTile(leading: const Icon(Icons.heart_broken_outlined), title: const Text('Avortement'), onTap: () => Navigator.pop(context, 'avortement')),
          ListTile(leading: const Icon(Icons.autorenew), title: const Text('Retour en chaleur'), onTap: () => Navigator.pop(context, 'chaleur')),
        ]),
      ),
    );
    if (!mounted || type == null) return;
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => type == 'velage'
            ? CalvingFormScreen(animal: widget.animal)
            : ReproductionEventFormScreen(animal: widget.animal, type: type),
      ),
    );
    if (changed == true) await _load();
  }

  Widget _eventCard(ReproductionEvent event) {
    final details = <String>[_date(event.date)];
    if (event.bull?.trim().isNotEmpty == true) details.add('Père/semence : ${event.bull}');
    if (event.pregnancyConfirmed != null) details.add(event.pregnancyConfirmed! ? 'Gestation confirmée' : 'Gestation non confirmée');
    if (event.calfSex != null) details.add('Veau : ${event.calfSex}');
    if (event.calfWeight != null) details.add('${event.calfWeight} kg');
    if (event.notes?.trim().isNotEmpty == true) details.add(event.notes!);
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(_icon(event.type))),
        title: Text(_title(event.type)),
        subtitle: Text(details.join('\n')),
        isThreeLine: details.length > 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reproduction - ${widget.animal.identification}')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  ReproductionPerformanceCard(
                    key: ValueKey('${widget.animal.id}-${_events.length}-${_events.isEmpty ? '' : _events.first.date.toIso8601String()}'),
                    animal: widget.animal,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.history),
                      const SizedBox(width: 8),
                      Text(
                        'Historique de reproduction',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_events.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Aucun événement de reproduction.')),
                      ),
                    )
                  else
                    ..._events.map(_eventCard),
                ],
              ),
            ),
    );
  }
}

class ReproductionEventFormScreen extends StatefulWidget {
  const ReproductionEventFormScreen({super.key, required this.animal, required this.type});
  final Animal animal;
  final String type;

  @override
  State<ReproductionEventFormScreen> createState() => _ReproductionEventFormScreenState();
}

class _ReproductionEventFormScreenState extends State<ReproductionEventFormScreen> {
  final _database = DatabaseHelper.instance;
  final _notes = TextEditingController();
  final _bull = TextEditingController();
  DateTime _date = DateTime.now();
  bool? _pregnancyConfirmed;
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    _bull.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.type) {
      case 'saillie':
        return 'Saillie / IA';
      case 'diagnostic':
        return 'Diagnostic de gestation';
      case 'avortement':
        return 'Avortement';
      case 'chaleur':
        return 'Retour en chaleur';
      default:
        return widget.type;
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) {
      setState(() => _date = value);
    }
  }

  Future<void> _save() async {
    final id = widget.animal.id;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await _database.insertReproductionEvent(ReproductionEvent(
        animalId: id,
        type: widget.type,
        date: _date,
        bull: _bull.text.trim().isEmpty ? null : _bull.text.trim(),
        pregnancyConfirmed: widget.type == 'diagnostic' ? _pregnancyConfirmed : null,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ));
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(leading: const Icon(Icons.pets), title: Text(widget.animal.identification), subtitle: Text(_title)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
          ),
          if (widget.type == 'saillie') ...[
            const SizedBox(height: 12),
            TextField(controller: _bull, decoration: const InputDecoration(labelText: 'Taureau / semence', border: OutlineInputBorder())),
          ],
          if (widget.type == 'diagnostic') ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('Gestante')), ButtonSegment(value: false, label: Text('Non gestante'))],
              selected: _pregnancyConfirmed == null ? <bool>{} : {_pregnancyConfirmed!},
              emptySelectionAllowed: true,
              onSelectionChanged: (values) => setState(() => _pregnancyConfirmed = values.isEmpty ? null : values.first),
            ),
          ],
          const SizedBox(height: 12),
          TextField(controller: _notes, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
        ],
      ),
    );
  }
}

class CalvingFormScreen extends StatefulWidget {
  const CalvingFormScreen({super.key, required this.animal});
  final Animal animal;

  @override
  State<CalvingFormScreen> createState() => _CalvingFormScreenState();
}

class _CalvingFormScreenState extends State<CalvingFormScreen> {
  final _database = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();
  final _calfId = TextEditingController();
  final _weight = TextEditingController();
  final _notes = TextEditingController();
  final DateTime _date = DateTime.now();
  String _sex = 'Inconnu';
  String? _ease;
  int? _fatherId;
  Animal? _father;
  List<Animal> _bulls = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadBulls();
  }

  @override
  void dispose() {
    _calfId.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadBulls() async {
    final animals = await _database.getAnimals(includeInactive: false);
    if (!mounted) return;
    setState(() {
      _bulls = animals.where((a) => a.id != widget.animal.id && a.normalizedSex == AnimalSex.male).toList();
    });
  }

  Future<void> _pickFather() async {
    final selected = await showModalBottomSheet<Animal>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _bulls
              .map((bull) => ListTile(
                    leading: const Icon(Icons.male),
                    title: Text(bull.identification),
                    subtitle: Text('Race ${bull.race}'),
                    onTap: () => Navigator.pop(context, bull),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _father = selected;
        _fatherId = selected.id;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || widget.animal.id == null) return;
    final weightText = _weight.text.trim().replaceAll(',', '.');
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);
    if (weightText.isNotEmpty && weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poids invalide.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final calf = Animal(
        identification: _calfId.text.trim(),
        cornes: 'À définir',
        dateNaissance: _date,
        race: widget.animal.race,
        sexe: _sex,
        motherId: widget.animal.id,
        fatherId: _fatherId,
      );
      final event = ReproductionEvent(
        animalId: widget.animal.id!,
        type: 'velage',
        date: _date,
        bull: _father?.identification,
        calfSex: _sex,
        calvingEase: _ease,
        calfWeight: weight,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      await _database.recordCalving(calf: calf, event: event);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau vêlage')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(leading: const CircleAvatar(child: Icon(Icons.female)), title: const Text('Mère'), subtitle: Text(widget.animal.identification)),
            const SizedBox(height: 12),
            TextFormField(controller: _calfId, decoration: const InputDecoration(labelText: 'Numéro du veau', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Numéro obligatoire.' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: const InputDecoration(labelText: 'Sexe du veau', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Femelle', child: Text('Femelle')),
                DropdownMenuItem(value: 'Mâle', child: Text('Mâle')),
                DropdownMenuItem(value: 'Inconnu', child: Text('Inconnu')),
              ],
              onChanged: (value) => setState(() => _sex = value ?? 'Inconnu'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _pickFather, icon: const Icon(Icons.male), label: Text(_father == null ? 'Sélectionner le père' : 'Père : ${_father!.identification}')),
            const SizedBox(height: 12),
            TextField(controller: _weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Poids de naissance (kg)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _ease,
              decoration: const InputDecoration(labelText: 'Facilité de vêlage', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Facile', child: Text('Facile')),
                DropdownMenuItem(value: 'Assisté', child: Text('Assisté')),
                DropdownMenuItem(value: 'Difficile', child: Text('Difficile')),
              ],
              onChanged: (value) => setState(() => _ease = value),
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: Text(_saving ? 'Enregistrement…' : 'Enregistrer le vêlage')),
          ],
        ),
      ),
    );
  }
}
