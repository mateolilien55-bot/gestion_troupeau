import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal_event.dart';

class AnimalEventFormScreen extends StatefulWidget {
  final int animalId;

  const AnimalEventFormScreen({
    super.key,
    required this.animalId,
  });

  @override
  State<AnimalEventFormScreen> createState() =>
      _AnimalEventFormScreenState();
}

class _AnimalEventFormScreenState
    extends State<AnimalEventFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _descriptionController =
      TextEditingController();

  final DatabaseHelper _database =
      DatabaseHelper.instance;

  DateTime _date = DateTime.now();

  String _type = 'Observation';

  bool _saving = false;

  final List<String> _types = [
    'Vêlage',
    'IA / Saillie',
    'Traitement',
    'Poids',
    'Observation',
    'Autre',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Date de l’événement',
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _date = selected;
    });
  }

  String _formatDate(DateTime date) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final event = AnimalEvent(
        animalId: widget.animalId,
        type: _type,
        date: _date,
        description:
            _descriptionController.text
                    .trim()
                    .isEmpty
                ? null
                : _descriptionController.text
                    .trim(),
      );

      await _database.insertEvent(event);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’enregistrer : $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ajouter un événement',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type d’événement',
                prefixIcon:
                    Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: _types.map(
                (type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _type = value;
                });
              },
            ),

            const SizedBox(height: 20),

            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration:
                    const InputDecoration(
                  labelText: 'Date',
                  prefixIcon:
                      Icon(Icons.calendar_month),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _formatDate(_date),
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextFormField(
              controller:
                  _descriptionController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText:
                    'Détails de l’événement...',
                prefixIcon:
                    Icon(Icons.notes),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _saving
                      ? 'Enregistrement...'
                      : 'Enregistrer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}