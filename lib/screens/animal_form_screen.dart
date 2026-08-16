import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';

class AnimalFormScreen extends StatefulWidget {
  const AnimalFormScreen({super.key, this.animal});
  final Animal? animal;
  bool get isEditing => animal != null;

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identification = TextEditingController();
  final _race = TextEditingController();
  final _premierVelage = TextEditingController();
  final _notes = TextEditingController();
  final _database = DatabaseHelper.instance;

  DateTime? _birthDate;
  String _horns = 'Cornue';
  String _sex = 'Inconnu';
  int? _motherId;
  int? _fatherId;
  List<Animal> _animals = const [];
  bool _loadingParents = true;
  bool _saving = false;

  static const _hornOptions = [
    'Cornue', 'Demi-cornue', 'Demie cornue', 'Sans corne H', 'Sans corne F', 'À définir', 'Autre',
  ];

  @override
  void initState() {
    super.initState();
    final animal = widget.animal;
    if (animal != null) {
      _identification.text = animal.identification;
      _race.text = animal.race;
      _premierVelage.text = animal.premierVelage ?? '';
      _notes.text = animal.notes ?? '';
      _birthDate = animal.dateNaissance;
      _sex = animal.normalizedSex.label;
      _motherId = animal.motherId;
      _fatherId = animal.fatherId;
      _horns = _hornOptions.contains(animal.cornes) ? animal.cornes : 'Autre';
    }
    _loadAnimals();
  }

  @override
  void dispose() {
    _identification.dispose();
    _race.dispose();
    _premierVelage.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadAnimals() async {
    try {
      final values = await _database.getAnimals();
      if (!mounted) return;
      setState(() {
        _animals = values;
        _loadingParents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingParents = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible de charger la filiation : $e')));
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _pickBirthDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Date de naissance',
    );
    if (value != null && mounted) setState(() => _birthDate = value);
  }

  Animal? _byId(int? id) {
    if (id == null) return null;
    for (final animal in _animals) {
      if (animal.id == id) return animal;
    }
    return null;
  }

  Set<int> _descendantIds(int rootId) {
    final result = <int>{};
    var changed = true;
    while (changed) {
      changed = false;
      for (final animal in _animals) {
        final id = animal.id;
        if (id == null || result.contains(id)) continue;
        final direct = animal.motherId == rootId || animal.fatherId == rootId;
        final indirect = (animal.motherId != null && result.contains(animal.motherId)) ||
            (animal.fatherId != null && result.contains(animal.fatherId));
        if (direct || indirect) {
          result.add(id);
          changed = true;
        }
      }
    }
    return result;
  }

  List<Animal> _candidates(bool mother) {
    final currentId = widget.animal?.id;
    final forbidden = currentId == null ? <int>{} : _descendantIds(currentId)..add(currentId);
    return _animals.where((animal) {
      if (animal.id == null || forbidden.contains(animal.id) || !animal.isActive) return false;
      if (_birthDate != null && !animal.dateNaissance.isBefore(_birthDate!)) return false;
      final sex = animal.normalizedSex;
      return mother
          ? sex == AnimalSex.female || sex == AnimalSex.unknown
          : sex == AnimalSex.male || sex == AnimalSex.unknown;
    }).toList();
  }

  Future<void> _selectParent(bool mother) async {
    final candidates = _candidates(mother);
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(mother ? 'Sélectionner la mère' : 'Sélectionner le père', style: Theme.of(context).textTheme.titleLarge),
              ),
              ListTile(leading: const Icon(Icons.clear), title: const Text('Inconnu / retirer le lien'), onTap: () => Navigator.pop(context, -1)),
              const Divider(height: 1),
              Expanded(
                child: candidates.isEmpty
                    ? const Center(child: Text('Aucun parent compatible.'))
                    : ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final animal = candidates[index];
                          return ListTile(
                            leading: Icon(mother ? Icons.female : Icons.male),
                            title: Text(animal.identification),
                            subtitle: Text('${animal.normalizedSex.label} • né(e) le ${_date(animal.dateNaissance)}'),
                            onTap: () => Navigator.pop(context, animal.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      final value = selected == -1 ? null : selected;
      if (mother) _motherId = value; else _fatherId = value;
    });
  }

  Widget _parentButton(bool mother) {
    final parent = _byId(mother ? _motherId : _fatherId);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loadingParents ? null : () => _selectParent(mother),
        icon: Icon(mother ? Icons.female : Icons.male),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text('${mother ? 'Mère' : 'Père'} : ${parent?.identification ?? 'Inconnu'}'),
        ),
      ),
    );
  }

  Future<bool> _confirmGenealogyChange() async {
    final existing = widget.animal;
    if (existing == null || (existing.motherId == _motherId && existing.fatherId == _fatherId)) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Modifier la filiation ?'),
            content: const Text('Cette modification change la branche généalogique de cet animal et peut modifier les arbres de ses descendants.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner la date de naissance.')));
      return;
    }
    if (_motherId != null && _motherId == _fatherId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La mère et le père doivent être différents.')));
      return;
    }
    if (!await _confirmGenealogyChange()) return;

    setState(() => _saving = true);
    try {
      final existing = widget.animal;
      final animal = Animal(
        id: existing?.id,
        identification: _identification.text.trim(),
        cornes: _horns,
        dateNaissance: _birthDate!,
        race: _race.text.trim(),
        sexe: _sex,
        premierVelage: _premierVelage.text.trim().isEmpty ? null : _premierVelage.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        motherId: _motherId,
        fatherId: _fatherId,
        status: existing?.status ?? AnimalStatus.active.label,
        exitDate: existing?.exitDate,
      );
      if (widget.isEditing) {
        await _database.updateAnimal(animal);
      } else {
        await _database.insertAnimal(animal);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d’enregistrer : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Modifier l’animal' : 'Ajouter un animal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _identification,
              decoration: const InputDecoration(labelText: 'Numéro d’identification', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
              validator: (value) => value == null || value.trim().isEmpty ? 'Le numéro est obligatoire.' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _sex,
              decoration: const InputDecoration(labelText: 'Sexe', prefixIcon: Icon(Icons.wc), border: OutlineInputBorder()),
              items: AnimalSex.values.map((sex) => DropdownMenuItem(value: sex.label, child: Text(sex.label))).toList(),
              onChanged: (value) => setState(() => _sex = value ?? AnimalSex.unknown.label),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _horns,
              decoration: const InputDecoration(labelText: 'Cornes', prefixIcon: Icon(Icons.pets), border: OutlineInputBorder()),
              items: _hornOptions.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => _horns = value ?? _horns),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _race,
              decoration: const InputDecoration(labelText: 'Race', border: OutlineInputBorder()),
              validator: (value) => value == null || value.trim().isEmpty ? 'La race est obligatoire.' : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(_birthDate == null ? 'Sélectionner la date de naissance' : 'Naissance : ${_date(_birthDate!)}'),
            ),
            const SizedBox(height: 22),
            Text('Filiation', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _parentButton(true),
            const SizedBox(height: 8),
            _parentButton(false),
            const SizedBox(height: 16),
            TextFormField(controller: _premierVelage, decoration: const InputDecoration(labelText: 'Premier vêlage', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextFormField(controller: _notes, maxLines: 5, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder(), alignLabelWithHint: true)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
