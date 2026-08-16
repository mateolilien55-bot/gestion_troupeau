import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';

class AnimalFormScreen extends StatefulWidget {
  final Animal? animal;

  const AnimalFormScreen({super.key, this.animal});

  bool get isEditing => animal != null;

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identificationController = TextEditingController();
  final _raceController = TextEditingController();
  final _premierVelageController = TextEditingController();
  final _notesController = TextEditingController();
  final DatabaseHelper _database = DatabaseHelper.instance;

  DateTime? _dateNaissance;
  String _cornes = 'Cornue';
  String? _sexe;
  bool _saving = false;

  final List<String> _cornesOptions = const [
    'Cornue',
    'Demi-cornue',
    'Demie cornue',
    'Sans corne H',
    'Sans corne F',
    'À définir',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    final animal = widget.animal;
    if (animal == null) return;

    _identificationController.text = animal.identification;
    _raceController.text = animal.race;
    _sexe = animal.sexe;
    _premierVelageController.text = animal.premierVelage ?? '';
    _notesController.text = animal.notes ?? '';
    _dateNaissance = animal.dateNaissance;
    _cornes = _cornesOptions.contains(animal.cornes)
        ? animal.cornes
        : 'Autre';
  }

  @override
  void dispose() {
    _identificationController.dispose();
    _raceController.dispose();
    _premierVelageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Date de naissance',
    );
    if (date != null && mounted) setState(() => _dateNaissance = date);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateNaissance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner la date de naissance.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final existing = widget.animal;
      final animal = Animal(
        id: existing?.id,
        identification: _identificationController.text.trim(),
        cornes: _cornes,
        dateNaissance: _dateNaissance!,
        race: _raceController.text.trim(),
        sexe: _sexe,
        premierVelage: _premierVelageController.text.trim().isEmpty
            ? null
            : _premierVelageController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        motherId: existing?.motherId,
        fatherId: existing?.fatherId,
      );

      if (widget.isEditing) {
        await _database.updateAnimal(animal);
      } else {
        await _database.insertAnimal(animal);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’enregistrer : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Modifier l’animal' : 'Ajouter un animal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _identificationController,
              decoration: const InputDecoration(
                labelText: 'Numéro d’identification',
                hintText: 'Ex. 2337',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Le numéro est obligatoire.'
                  : null,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _cornes,
              decoration: const InputDecoration(
                labelText: 'Cornes',
                prefixIcon: Icon(Icons.pets),
                border: OutlineInputBorder(),
              ),
              items: _cornesOptions
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _cornes = value);
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _sexe,
              decoration: const InputDecoration(
                labelText: 'Sexe',
                prefixIcon: Icon(Icons.wc),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Femelle', child: Text('Femelle')),
                DropdownMenuItem(value: 'Mâle', child: Text('Mâle')),
                DropdownMenuItem(value: 'Inconnu', child: Text('Inconnu')),
              ],
              onChanged: (value) => setState(() => _sexe = value),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _raceController,
              decoration: const InputDecoration(
                labelText: 'Race',
                hintText: 'Ex. 38',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'La race est obligatoire.'
                  : null,
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de naissance',
                  prefixIcon: Icon(Icons.calendar_month),
                  border: OutlineInputBorder(),
                ),
                child: Text(_dateNaissance == null
                    ? 'Sélectionner une date'
                    : _formatDate(_dateNaissance!)),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _premierVelageController,
              decoration: const InputDecoration(
                labelText: 'Premier vêlage',
                hintText: 'Ex. 3 ans et 2 mois',
                prefixIcon: Icon(Icons.favorite_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _notesController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Observations concernant l’animal...',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
