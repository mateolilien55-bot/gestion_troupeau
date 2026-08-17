import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AnimalDocument {
  const AnimalDocument({
    required this.id,
    required this.animalId,
    required this.name,
    required this.path,
    required this.addedAt,
    this.category,
  });

  final String id;
  final int animalId;
  final String name;
  final String path;
  final DateTime addedAt;
  final String? category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'animalId': animalId,
        'name': name,
        'path': path,
        'addedAt': addedAt.toIso8601String(),
        'category': category,
      };

  factory AnimalDocument.fromJson(Map<String, dynamic> json) => AnimalDocument(
        id: json['id'] as String,
        animalId: json['animalId'] as int,
        name: json['name'] as String,
        path: json['path'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        category: json['category'] as String?,
      );
}

class DocumentStore {
  static Future<Directory> _root() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'gestion_troupeau_documents'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<File> _indexFile() async => File(p.join((await _root()).path, 'index.json'));

  static Future<List<AnimalDocument>> _readAll() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((row) => AnimalDocument.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeAll(List<AnimalDocument> documents) async {
    final file = await _indexFile();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(documents.map((document) => document.toJson()).toList()));
    await temp.rename(file.path);
  }

  static Future<List<AnimalDocument>> forAnimal(int animalId) async {
    final documents = await _readAll();
    documents.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return documents.where((document) => document.animalId == animalId).toList();
  }

  static Future<AnimalDocument> importFromPath({
    required int animalId,
    required String sourcePath,
    String? category,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw ArgumentError('Fichier introuvable : $sourcePath');
    final animalDirectory = Directory(p.join((await _root()).path, 'animal_$animalId'));
    if (!await animalDirectory.exists()) await animalDirectory.create(recursive: true);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final originalName = p.basename(source.path);
    final target = File(p.join(animalDirectory.path, '${id}_$originalName'));
    await source.copy(target.path);
    final document = AnimalDocument(
      id: id,
      animalId: animalId,
      name: originalName,
      path: target.path,
      addedAt: DateTime.now(),
      category: category,
    );
    final documents = await _readAll()..add(document);
    await _writeAll(documents);
    return document;
  }

  static Future<void> delete(AnimalDocument document) async {
    final file = File(document.path);
    if (await file.exists()) await file.delete();
    final documents = await _readAll()..removeWhere((item) => item.id == document.id);
    await _writeAll(documents);
  }
}
