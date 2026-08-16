import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import 'animal_screen.dart';
import 'animal_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _database = DatabaseHelper.instance;

  final TextEditingController _searchController =
      TextEditingController();

  List<Animal> _animals = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnimals() async {
    setState(() {
      _loading = true;
    });

    try {
      final animals = await _database.getAnimals();

      if (!mounted) return;

      setState(() {
        _animals = animals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors du chargement : $e',
          ),
        ),
      );
    }
  }

  Future<void> _searchAnimals(String value) async {
    final query = value.trim();

    if (query.isEmpty) {
      await _loadAnimals();
      return;
    }

    try {
      final animals = await _database.searchAnimals(query);

      if (!mounted) return;

      setState(() {
        _animals = animals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur de recherche : $e',
          ),
        ),
      );
    }
  }

  Future<void> _openAnimal(Animal animal) async {
    if (animal.id == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimalScreen(
          animalId: animal.id!,
        ),
      ),
    );

    await _loadAnimals();
  }

  Future<void> _addAnimal() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AnimalFormScreen(),
      ),
    );

    if (result == true) {
      await _loadAnimals();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _loadAnimals();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion du troupeau',
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAnimal,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),

      body: Column(
        children: [
          _buildSearch(),

          _buildAnimalCount(),

          const SizedBox(height: 8),

          Expanded(
            child: _buildAnimalList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: _searchAnimals,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          labelText: 'Numéro d’identification',
          hintText: 'Exemple : 2337',
          prefixIcon: const Icon(
            Icons.search,
          ),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(
                        Icons.clear,
                      ),
                    )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimalCount() {
    final count = _animals.length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: Row(
        children: [
          const Icon(Icons.pets),
          const SizedBox(width: 8),
          Text(
            '$count animal${count > 1 ? 'x' : ''}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_animals.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadAnimals,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          bottom: 100,
        ),
        itemCount: _animals.length,
        itemBuilder: (context, index) {
          final animal = _animals[index];

          return _buildAnimalCard(animal);
        },
      ),
    );
  }

  Widget _buildAnimalCard(Animal animal) {
    final date = animal.dateNaissance;

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      child: InkWell(
        onTap: () => _openAnimal(animal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: const Icon(
                  Icons.pets,
                  size: 28,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.identification,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${animal.cornes} • Race ${animal.race}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Née le $day/$month/${date.year}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 70,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            const Text(
              'Aucun animal trouvé',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Vérifie le numéro d’identification.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}