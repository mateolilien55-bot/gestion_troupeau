import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import '../models/animal_event.dart';
import 'animal_event_form_screen.dart';
import 'animal_form_screen.dart';
import 'reproduction_screen.dart';

class AnimalScreen extends StatefulWidget {
  final int animalId;

  const AnimalScreen({
    super.key,
    required this.animalId,
  });

  @override
  State<AnimalScreen> createState() => _AnimalScreenState();
}

class _AnimalScreenState extends State<AnimalScreen> {
  final DatabaseHelper _database = DatabaseHelper.instance;

  Animal? _animal;
  List<AnimalEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final animal = await _database.getAnimalById(
        widget.animalId,
      );

      final events = await _database.getEventsForAnimal(
        widget.animalId,
      );

      if (!mounted) return;

      setState(() {
        _animal = animal;
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
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'vêlage':
      case 'velage':
        return Icons.child_friendly;

      case 'IA / Saillie':
      case 'saillie':
        return Icons.favorite;

      case 'Traitement':
        return Icons.medical_services;

      case 'Poids':
        return Icons.monitor_weight;

      case 'Observation':
        return Icons.notes;

      default:
        return Icons.event;
    }
  }

  Future<void> _editAnimal() async {
    if (_animal == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimalFormScreen(
          animal: _animal,
        ),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _openReproduction() async {
    if (_animal == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReproductionScreen(
          animal: _animal!,
        ),
      ),
    );

    await _loadData();
  }

  Future<void> _openAnimal(int? animalId) async {
    if (animalId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimalScreen(
          animalId: animalId,
        ),
      ),
    );

    if (mounted) {
      await _loadData();
    }
  }

  Widget _buildParentRow({
    required String label,
    required int? animalId,
    required IconData icon,
  }) {
    if (animalId == null) {
      return _buildInfoRow(
        label,
        'Inconnu',
      );
    }

    return FutureBuilder<Animal?>(
      future: _database.getAnimalById(animalId),
      builder: (context, snapshot) {
        final parent = snapshot.data;

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(label),
            subtitle: const Text('Chargement...'),
          );
        }

        if (parent == null) {
          return _buildInfoRow(
            label,
            'Inconnu',
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(icon),
            ),
            title: Text(label),
            subtitle: Text(
              parent.identification,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () {
              _openAnimal(parent.id);
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(Animal animal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(
                Icons.pets,
                size: 40,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    animal.identification,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    animal.race,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return _buildSection(
      title: 'Historique',
      icon: Icons.history,
      children: [
        if (_events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: Text(
              'Aucun événement.',
            ),
          )
        else
          ..._events.map(
            (event) {
              return Card(
                margin: const EdgeInsets.only(
                  bottom: 8,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      _eventIcon(event.type),
                    ),
                  ),
                  title: Text(event.type),
                  subtitle: Text(
                    _formatDate(event.date),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              if (_animal?.id == null) return;

              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimalEventFormScreen(
                    animalId: _animal!.id!,
                  ),
                ),
              );

              if (result == true) {
                await _loadData();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text(
              'Ajouter un événement',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimalPage() {
  final animal = _animal!;

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(animal),

        const SizedBox(height: 20),

        _buildSection(
          title: 'Identification',
          icon: Icons.badge_outlined,
          children: [
            _buildInfoRow(
              'Numéro',
              animal.identification,
            ),
            _buildInfoRow(
              'Sexe',
              animal.sexe ?? 'Inconnu',
            ),
            _buildInfoRow(
              'Race',
              animal.race,
            ),
            _buildInfoRow(
              'Cornes',
              animal.cornes,
            ),
            _buildInfoRow(
              'Date de naissance',
              _formatDate(
                animal.dateNaissance,
              ),
            ),

            // MÈRE CLIQUABLE
            _buildParentRow(
              label: 'Mère',
              animalId: animal.motherId,
              icon: Icons.female,
            ),

            // PÈRE CLIQUABLE
            _buildParentRow(
              label: 'Père',
              animalId: animal.fatherId,
              icon: Icons.male,
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildSection(
          title: 'Reproduction',
          icon: Icons.favorite_outline,
          children: [
            _buildInfoRow(
              'Premier vêlage',
              animal.premierVelage ??
                  'Non renseigné',
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openReproduction,
                icon: const Icon(
                  Icons.child_friendly,
                ),
                label: const Text(
                  'Gérer la reproduction',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildHistory(),

        const SizedBox(height: 16),

        _buildSection(
          title: 'Notes',
          icon: Icons.notes,
          children: [
            Text(
              animal.notes?.trim().isNotEmpty == true
                  ? animal.notes!
                  : 'Aucune note.',
              style: TextStyle(
                color:
                    animal.notes?.trim().isNotEmpty == true
                        ? null
                        : Colors.grey.shade600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _editAnimal,
            icon: const Icon(Icons.edit),
            label: const Text(
              'Modifier l’animal',
            ),
          ),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _animal?.identification ??
              'Animal',
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _animal == null
              ? const Center(
                  child: Text(
                    'Animal introuvable.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildAnimalPage(),
                ),
    );
  }
}


