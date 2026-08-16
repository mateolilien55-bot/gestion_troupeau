import 'package:flutter/material.dart';

import '../database/database.dart';
import '../models/animal.dart';
import '../models/animal_event.dart';
import 'animal_event_form_screen.dart';
import 'animal_form_screen.dart';
import 'genealogy_screen.dart';
import 'reproduction_screen.dart';

class AnimalScreen extends StatefulWidget {
  const AnimalScreen({super.key, required this.animalId});
  final int animalId;

  @override
  State<AnimalScreen> createState() => _AnimalScreenState();
}

class _AnimalScreenState extends State<AnimalScreen> {
  final _database = DatabaseHelper.instance;
  Animal? _animal;
  List<AnimalEvent> _events = const [];
  List<Animal> _children = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final animal = await _database.getAnimalById(widget.animalId);
      final events = await _database.getEventsForAnimal(widget.animalId);
      final children = await _database.getChildren(widget.animalId);
      if (!mounted) return;
      setState(() {
        _animal = animal;
        _events = events;
        _children = children;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _openAnimal(int? id) async {
    if (id == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AnimalScreen(animalId: id)));
    if (mounted) await _load();
  }

  Future<void> _edit() async {
    final animal = _animal;
    if (animal == null) return;
    final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => AnimalFormScreen(animal: animal)));
    if (changed == true) await _load();
  }

  Future<void> _openReproduction() async {
    final animal = _animal;
    if (animal == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ReproductionScreen(animal: animal)));
    if (mounted) await _load();
  }

  Future<void> _changeStatus() async {
    final animal = _animal;
    if (animal?.id == null) return;
    final status = await showModalBottomSheet<AnimalStatus>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AnimalStatus.values
              .map((value) => ListTile(
                    leading: Icon(value == AnimalStatus.active ? Icons.check_circle_outline : Icons.logout),
                    title: Text(value.label),
                    trailing: animal!.normalizedStatus == value ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, value),
                  ))
              .toList(),
        ),
      ),
    );
    if (status == null) return;
    await _database.archiveAnimal(animal!.id!, status);
    await _load();
  }

  Future<void> _permanentDelete() async {
    final animal = _animal;
    if (animal?.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suppression définitive ?'),
        content: const Text('Utilisez normalement le statut Vendu, Mort ou Sorti. Cette action efface définitivement la fiche.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer définitivement')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _database.deleteAnimalPermanently(animal!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ]),
      );

  Widget _parent(String label, int? id, IconData icon) {
    if (id == null) return _info(label, 'Inconnu');
    return FutureBuilder<Animal?>(
      future: _database.getAnimalById(id),
      builder: (context, snapshot) {
        final parent = snapshot.data;
        if (parent == null) return _info(label, snapshot.connectionState == ConnectionState.waiting ? 'Chargement…' : 'Inconnu');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(label),
          subtitle: Text(parent.identification),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openAnimal(parent.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final animal = _animal;
    return Scaffold(
      appBar: AppBar(
        title: Text(animal?.identification ?? 'Animal'),
        actions: [
          if (animal != null) IconButton(tooltip: 'Modifier', onPressed: _edit, icon: const Icon(Icons.edit)),
          if (animal != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'status') _changeStatus();
                if (value == 'delete') _permanentDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'status', child: Text('Changer le statut')),
                PopupMenuItem(value: 'delete', child: Text('Suppression définitive')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : animal == null
              ? const Center(child: Text('Animal introuvable.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(radius: 28, child: Icon(Icons.pets)),
                          title: Text(animal.identification, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          subtitle: Text('Race ${animal.race} • ${animal.status} • ${animal.normalizedReproductiveRole.label}'),
                          trailing: Chip(label: Text(animal.sexe ?? 'Inconnu')),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _section('Identification', Icons.badge_outlined, [
                        _info('Sexe', animal.sexe ?? 'Inconnu'),
                        _info('Rôle reproducteur', animal.normalizedReproductiveRole.label),
                        _info('Race', animal.race),
                        _info('Cornes', animal.cornes),
                        _info('Naissance', _date(animal.dateNaissance)),
                        _info('Statut', animal.status),
                        if (animal.exitDate != null) _info('Date de sortie', _date(animal.exitDate!)),
                      ]),
                      const SizedBox(height: 12),
                      _section('Filiation', Icons.account_tree_outlined, [
                        _parent('Mère', animal.motherId, Icons.female),
                        _parent('Père', animal.fatherId, Icons.male),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.account_tree),
                            label: const Text('Voir l’arbre généalogique'),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GenealogyScreen(animal: animal))),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _section('Descendants', Icons.child_friendly, [
                        if (_children.isEmpty)
                          const Text('Aucun descendant enregistré.')
                        else
                          ..._children.map((child) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(child: Icon(Icons.pets)),
                                title: Text(child.identification),
                                subtitle: Text('${child.sexe ?? 'Inconnu'} • né(e) le ${_date(child.dateNaissance)}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openAnimal(child.id),
                              )),
                      ]),
                      const SizedBox(height: 12),
                      _section('Reproduction', Icons.favorite_outline, [
                        _info('Premier vêlage', animal.premierVelage ?? 'Non renseigné'),
                        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _openReproduction, icon: const Icon(Icons.favorite), label: const Text('Gérer la reproduction'))),
                      ]),
                      const SizedBox(height: 12),
                      _section('Historique', Icons.history, [
                        if (_events.isEmpty) const Text('Aucun événement.'),
                        ..._events.take(10).map((event) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event),
                              title: Text(event.type),
                              subtitle: Text('${_date(event.date)}${event.description?.isNotEmpty == true ? ' • ${event.description}' : ''}'),
                            )),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter un événement'),
                            onPressed: () async {
                              final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => AnimalEventFormScreen(animalId: animal.id!)));
                              if (changed == true) await _load();
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _section('Notes', Icons.notes, [Text(animal.notes?.trim().isNotEmpty == true ? animal.notes! : 'Aucune note.')]),
                    ],
                  ),
                ),
    );
  }
}
