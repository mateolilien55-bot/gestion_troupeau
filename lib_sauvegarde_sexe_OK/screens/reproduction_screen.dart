import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import '../models/reproduction_event.dart';

class ReproductionScreen extends StatefulWidget {
  final Animal animal;

  const ReproductionScreen({
    super.key,
    required this.animal,
  });

  @override
  State<ReproductionScreen> createState() =>
      _ReproductionScreenState();
}

class _ReproductionScreenState extends State<ReproductionScreen> {
  final DatabaseHelper _database = DatabaseHelper.instance;

  List<ReproductionEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final animalId = widget.animal.id;

    if (animalId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final events =
          await _database.getReproductionEventsForAnimal(animalId);

      if (!mounted) return;

      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _eventTitle(ReproductionEvent event) {
    switch (event.type) {
      case 'velage':
        return 'Vêlage';
      case 'saillie':
        return 'Saillie';
      case 'diagnostic':
        return 'Diagnostic de gestation';
      default:
        return event.type;
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'velage':
        return Icons.child_friendly;
      case 'saillie':
        return Icons.pets;
      case 'diagnostic':
        return Icons.biotech;
      default:
        return Icons.event;
    }
  }

  Future<void> _addVelage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VelageFormScreen(
          animal: widget.animal,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadEvents();
    }
  }

  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.child_friendly),
                title: const Text('Vêlage'),
                onTap: () {
                  Navigator.pop(sheetContext, 'velage');
                },
              ),
              ListTile(
                leading: const Icon(Icons.pets),
                title: const Text('Saillie'),
                onTap: () {
                  Navigator.pop(sheetContext, 'saillie');
                },
              ),
              ListTile(
                leading: const Icon(Icons.biotech),
                title: const Text(
                  'Diagnostic de gestation',
                ),
                onTap: () {
                  Navigator.pop(sheetContext, 'diagnostic');
                },
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) {
      return;
    }

    switch (choice) {
      case 'velage':
        await _addVelage();
        break;

      case 'saillie':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le formulaire Saillie sera ajouté ensuite.',
            ),
          ),
        );
        break;

      case 'diagnostic':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le formulaire Diagnostic sera ajouté ensuite.',
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reproduction - ${widget.animal.identification}',
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _events.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun événement de reproduction.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              _eventIcon(event.type),
                            ),
                          ),
                          title: Text(
                            _eventTitle(event),
                          ),
                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(event.date),
                              ),
                              if (event.bull != null &&
                                  event.bull!.trim().isNotEmpty)
                                Text(
                                  'Père : ${event.bull}',
                                ),
                              if (event.calfId != null)
                                Text(
                                  'Veau enregistré',
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class VelageFormScreen extends StatefulWidget {
  final Animal animal;

  const VelageFormScreen({
    super.key,
    required this.animal,
  });

  @override
  State<VelageFormScreen> createState() =>
      _VelageFormScreenState();
}

class _VelageFormScreenState extends State<VelageFormScreen> {
  final DatabaseHelper _database = DatabaseHelper.instance;

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _veauController =
      TextEditingController();

  final TextEditingController _poidsController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  final TextEditingController _taureauController =
      TextEditingController();

  DateTime _date = DateTime.now();

  String? _sexeVeau;
  String? _faciliteVelage;

  bool _saving = false;

  int? _selectedFatherId;

  List<Animal> _bulls = [];
  Animal? _selectedBull;

  bool _loadingBulls = true;

  @override
  void initState() {
    super.initState();
    _loadBulls();
  }

  @override
  void dispose() {
    _veauController.dispose();
    _poidsController.dispose();
    _notesController.dispose();
    _taureauController.dispose();
    super.dispose();
  }

  Future<void> _loadBulls() async {
    try {
      final animals = await _database.getAnimals();

      if (!mounted) return;

      /*
       * Pour l'instant, on considère comme taureaux les animaux
       * dont l'identification est disponible dans la table.
       *
       * Si ton modèle possède ensuite un vrai champ "sexe",
       * on pourra filtrer précisément les mâles.
       */
      setState(() {
        _bulls = animals
            .where(
              (animal) =>
                  animal.id != null &&
                  animal.id != widget.animal.id,
            )
            .toList();

        _loadingBulls = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingBulls = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de charger les taureaux : $e',
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _date = selected;
    });
  }

  Future<void> _selectBull() async {
    if (_bulls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun animal disponible pour sélectionner le père.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Animal>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Sélectionner le père',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _bulls.length,
                    itemBuilder: (context, index) {
                      final bull = _bulls[index];

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.pets),
                        ),
                        title: Text(
                          bull.identification,
                        ),
                        subtitle: Text(
                          'Race ${bull.race}',
                        ),
                        trailing:
                            _selectedFatherId == bull.id
                                ? const Icon(
                                    Icons.check,
                                  )
                                : null,
                        onTap: () {
                          Navigator.pop(
                            sheetContext,
                            bull,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedBull = selected;
      _selectedFatherId = selected.id;
      _taureauController.text = selected.identification;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final motherId = widget.animal.id;

    if (motherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Impossible d'enregistrer le vêlage : "
            "la vache n'a pas d'identifiant.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final calfIdentification =
          _veauController.text.trim();

      final calfWeightText =
          _poidsController.text.trim().replaceAll(',', '.');

      final calfWeight = calfWeightText.isEmpty
          ? null
          : double.tryParse(calfWeightText);

      if (calfWeightText.isNotEmpty && calfWeight == null) {
        throw Exception('Poids du veau invalide.');
      }

      /*
       * Création du veau.
       *
       * motherId = mère actuelle
       * fatherId = taureau sélectionné
       */
      final calf = Animal(
        identification: calfIdentification,
        cornes: 'À définir',
        dateNaissance: _date,
        race: widget.animal.race,
        sexe: _sexeVeau,
        motherId: motherId,
        fatherId: _selectedFatherId,
      );

      final calfId = await _insertAnimal(calf);

      /*
       * Création de l'événement de vêlage.
       */
      final event = ReproductionEvent(
        animalId: motherId,
        type: 'velage',
        date: _date,
        bull: _taureauController.text.trim().isEmpty
            ? null
            : _taureauController.text.trim(),
        calfId: calfId,
        calfSex: _sexeVeau,
        calvingEase: _faciliteVelage,
        calfWeight: calfWeight,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await _database.insertReproductionEvent(event);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vêlage enregistré et veau créé.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Erreur lors de l'enregistrement : $e",
          ),
        ),
      );
    }
  }

  Future<int> _insertAnimal(Animal animal) async {
    final db = await _database.database;

    return db.insert(
      'animals',
      animal.toMap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau vêlage'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      child: Icon(Icons.pets),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mère',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.animal.identification,
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _veauController,
              decoration: const InputDecoration(
                labelText: 'Numéro du veau',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Indiquez le numéro du veau.';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date du vêlage',
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.calendar_today),
                ),
                child: Text(
                  _formatDate(_date),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /*
             * Sélection du père.
             */
            InkWell(
              onTap: _loadingBulls
                  ? null
                  : _selectBull,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Père / Taureau',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                  suffixIcon:
                      Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _selectedBull?.identification ??
                      'Sélectionner le père',
                  style: TextStyle(
                    color: _selectedBull == null
                        ? Colors.grey.shade600
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _sexeVeau,
              decoration: const InputDecoration(
                labelText: 'Sexe du veau',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pets),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Mâle',
                  child: Text('Mâle'),
                ),
                DropdownMenuItem(
                  value: 'Femelle',
                  child: Text('Femelle'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _sexeVeau = value;
                });
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _faciliteVelage,
              decoration: const InputDecoration(
                labelText: 'Facilité du vêlage',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.child_friendly),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Facile',
                  child: Text('Facile'),
                ),
                DropdownMenuItem(
                  value: 'Avec aide',
                  child: Text('Avec aide'),
                ),
                DropdownMenuItem(
                  value: 'Difficile',
                  child: Text('Difficile'),
                ),
                DropdownMenuItem(
                  value: 'Césarienne',
                  child: Text('Césarienne'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _faciliteVelage = value;
                });
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _poidsController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Poids du veau (kg)',
                border: OutlineInputBorder(),
                prefixIcon:
                    Icon(Icons.monitor_weight),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText:
                    'Observations concernant le vêlage...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _saving
                      ? 'Enregistrement...'
                      : 'Enregistrer le vêlage',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}