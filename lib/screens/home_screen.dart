import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import '../services/favorite_store.dart';
import 'animal_form_screen.dart';
import 'animal_screen.dart';
import 'backup_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _database = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<Animal> _animals = const [];
  Set<int> _favorites = const {};
  bool _loading = true;
  bool _favoritesOnly = false;
  String? _sex;
  String? _status = 'Actif';
  String? _reproductiveRole;
  String? _race;
  int? _birthYear;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final animals = await _database.searchAnimals(
        _searchController.text,
        sex: _sex,
        race: _race,
        status: _status,
        reproductiveRole: _reproductiveRole,
        birthYear: _birthYear,
      );
      final favorites = await FavoriteStore.load();
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _animals = _favoritesOnly
            ? animals.where((animal) => animal.id != null && favorites.contains(animal.id)).toList()
            : animals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de recherche : $e')),
      );
    }
  }

  Future<void> _toggleFavorite(Animal animal) async {
    final id = animal.id;
    if (id == null) return;
    await FavoriteStore.toggle(id);
    await _search();
  }

  Future<void> _openAnimal(Animal animal) async {
    if (animal.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnimalScreen(animalId: animal.id!)),
    );
    await _search();
  }

  Future<void> _addAnimal() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnimalFormScreen()),
    );
    if (result == true) await _search();
  }

  Future<void> _showFilters() async {
    String? sex = _sex;
    String? status = _status;
    String? reproductiveRole = _reproductiveRole;
    final raceController = TextEditingController(text: _race ?? '');
    final yearController = TextEditingController(text: _birthYear?.toString() ?? '');
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: sex,
                  decoration: const InputDecoration(labelText: 'Sexe'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(value: 'Femelle', child: Text('Femelle')),
                    DropdownMenuItem(value: 'Mâle', child: Text('Mâle')),
                    DropdownMenuItem(value: 'Inconnu', child: Text('Inconnu')),
                  ],
                  onChanged: (value) => setSheetState(() => sex = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: reproductiveRole,
                  decoration: const InputDecoration(labelText: 'Rôle reproducteur'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(value: 'Reproducteur', child: Text('Reproducteur')),
                    DropdownMenuItem(value: 'Non reproducteur', child: Text('Non reproducteur')),
                    DropdownMenuItem(value: 'Inconnu', child: Text('Inconnu')),
                  ],
                  onChanged: (value) => setSheetState(() => reproductiveRole = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(value: 'Actif', child: Text('Actif')),
                    DropdownMenuItem(value: 'Vendu', child: Text('Vendu')),
                    DropdownMenuItem(value: 'Mort', child: Text('Mort')),
                    DropdownMenuItem(value: 'Sorti', child: Text('Sorti')),
                  ],
                  onChanged: (value) => setSheetState(() => status = value),
                ),
                const SizedBox(height: 12),
                TextField(controller: raceController, decoration: const InputDecoration(labelText: 'Race')),
                const SizedBox(height: 12),
                TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Année de naissance'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('Annuler'),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply == true) {
      _sex = sex;
      _status = status;
      _reproductiveRole = reproductiveRole;
      _race = raceController.text.trim().isEmpty ? null : raceController.text.trim();
      _birthYear = int.tryParse(yearController.text.trim());
      await _search();
    }
    raceController.dispose();
    yearController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion du troupeau'),
        actions: [
          IconButton(
            tooltip: _favoritesOnly ? 'Afficher tous les animaux' : 'Animaux à surveiller',
            icon: Icon(_favoritesOnly ? Icons.star : Icons.star_border),
            onPressed: () {
              setState(() => _favoritesOnly = !_favoritesOnly);
              _search();
            },
          ),
          IconButton(
            tooltip: 'Tableau de bord',
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Sauvegarde',
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAnimal,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: _favoritesOnly ? 'Rechercher dans les animaux à surveiller' : 'Rechercher',
                      hintText: 'Numéro, race, mère, père, notes…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Filtres',
                  onPressed: _showFilters,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
          ),
          if (_favoritesOnly)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(avatar: Icon(Icons.star, size: 18), label: Text('Animaux à surveiller')),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.pets),
                const SizedBox(width: 8),
                Text('${_animals.length} résultat(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _animals.isEmpty
                    ? const Center(child: Text('Aucun animal trouvé.'))
                    : RefreshIndicator(
                        onRefresh: _search,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: _animals.length,
                          itemBuilder: (context, index) {
                            final animal = _animals[index];
                            final date = animal.dateNaissance;
                            final favorite = animal.id != null && _favorites.contains(animal.id);
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.pets)),
                                title: Text(animal.identification, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  '${animal.sexe ?? 'Inconnu'} • ${animal.normalizedReproductiveRole.label} • Race ${animal.race} • ${animal.status}\n'
                                  'Né(e) le ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                                      onPressed: () => _toggleFavorite(animal),
                                      icon: Icon(favorite ? Icons.star : Icons.star_border),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () => _openAnimal(animal),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
