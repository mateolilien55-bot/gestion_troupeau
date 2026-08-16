import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/animal.dart';
import '../models/animal_event.dart';
import '../models/animal_movement.dart';
import '../models/feeding_record.dart';
import '../models/health_event.dart';
import '../models/reproduction_event.dart';
import '../models/weight_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  Database? _database;
  String? _databasePath;

  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    final factory = _getDatabaseFactory();
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'gestion_troupeau.db');
    _databasePath = path;
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  DatabaseFactory _getDatabaseFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE animals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        identification TEXT NOT NULL UNIQUE,
        cornes TEXT NOT NULL,
        date_naissance TEXT NOT NULL,
        race TEXT NOT NULL,
        sexe TEXT,
        reproductive_role TEXT NOT NULL DEFAULT 'Inconnu',
        premier_velage TEXT,
        notes TEXT,
        mother_id INTEGER,
        father_id INTEGER,
        status TEXT NOT NULL DEFAULT 'Actif',
        exit_date TEXT,
        FOREIGN KEY (mother_id) REFERENCES animals (id) ON DELETE SET NULL,
        FOREIGN KEY (father_id) REFERENCES animals (id) ON DELETE SET NULL
      )
    ''');
    await _createAnimalEventsTable(db);
    await _createV3Tables(db);
    await _insertInitialAnimals(db);
  }

  Future<Set<Object?>> _animalColumnNames(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(animals)');
    return columns.map((column) => column['name']).toSet();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createAnimalEventsTable(db);
    if (oldVersion < 3) {
      final names = await _animalColumnNames(db);
      if (!names.contains('mother_id')) await db.execute('ALTER TABLE animals ADD COLUMN mother_id INTEGER');
      if (!names.contains('father_id')) await db.execute('ALTER TABLE animals ADD COLUMN father_id INTEGER');
      await _createV3Tables(db);
    }
    if (oldVersion < 4) {
      final names = await _animalColumnNames(db);
      if (!names.contains('sexe')) await db.execute('ALTER TABLE animals ADD COLUMN sexe TEXT');
    }
    if (oldVersion < 7) {
      final names = await _animalColumnNames(db);
      if (!names.contains('status')) {
        await db.execute("ALTER TABLE animals ADD COLUMN status TEXT NOT NULL DEFAULT 'Actif'");
      }
      if (!names.contains('exit_date')) await db.execute('ALTER TABLE animals ADD COLUMN exit_date TEXT');
    }
    if (oldVersion < 8) {
      final names = await _animalColumnNames(db);
      if (!names.contains('reproductive_role')) {
        await db.execute("ALTER TABLE animals ADD COLUMN reproductive_role TEXT NOT NULL DEFAULT 'Inconnu'");
      }
    }
    await _createAnimalEventsTable(db);
    await _createV3Tables(db);
  }

  Future<void> _createAnimalEventsTable(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS animal_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      animal_id INTEGER NOT NULL,
      type TEXT NOT NULL,
      date TEXT NOT NULL,
      description TEXT,
      FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
    )''');
  }

  Future<void> _createV3Tables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS reproduction_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT, animal_id INTEGER NOT NULL,
      type TEXT NOT NULL, date TEXT NOT NULL, related_animal_id INTEGER,
      bull TEXT, pregnancy_confirmed INTEGER, calf_id INTEGER, calf_sex TEXT,
      calving_ease TEXT, calf_weight REAL, notes TEXT,
      FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS health_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT, animal_id INTEGER NOT NULL,
      type TEXT NOT NULL, date TEXT NOT NULL, product TEXT, reason TEXT,
      dosage TEXT, disease TEXT, recovery_date TEXT, notes TEXT,
      FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS weight_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT, animal_id INTEGER NOT NULL,
      date TEXT NOT NULL, weight REAL NOT NULL, notes TEXT,
      FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS feeding_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT, animal_id INTEGER NOT NULL,
      date TEXT NOT NULL, feed TEXT NOT NULL, quantity TEXT, notes TEXT,
      FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS animal_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT, animal_id INTEGER NOT NULL,
      type TEXT NOT NULL, date TEXT NOT NULL, reason TEXT, destination TEXT,
      price REAL, notes TEXT,
      FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
    )''');
  }

  Future<void> _insertInitialAnimals(Database db) async {
    final animals = [
      Animal(identification: '2337', cornes: 'Cornue', dateNaissance: DateTime(2018, 11, 4), race: '38', premierVelage: '3 ans et 2 mois'),
      Animal(identification: '6201', cornes: 'Demi-cornue', dateNaissance: DateTime(2019, 3, 15), race: '38', premierVelage: '3 ans'),
      Animal(identification: '2380', cornes: 'Cornue', dateNaissance: DateTime(2019, 10, 5), race: '38', premierVelage: '3 ans et 2 mois'),
      Animal(identification: '3638', cornes: 'Cornue', dateNaissance: DateTime(2020, 4, 5), race: '38', premierVelage: '3 ans et 9 mois'),
      Animal(identification: '3643', cornes: 'Cornue', dateNaissance: DateTime(2020, 4, 27), race: '38', premierVelage: '3 ans et 9 mois'),
      Animal(identification: '8527', cornes: 'Sans corne H', dateNaissance: DateTime(2022, 12, 5), race: '38', premierVelage: '2 ans et 11 mois'),
    ];
    for (final animal in animals) {
      await db.insert('animals', animal.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<Animal>> getAnimals({bool includeInactive = true}) async {
    final result = await (await database).query(
      'animals',
      where: includeInactive ? null : 'status = ?',
      whereArgs: includeInactive ? null : const ['Actif'],
      orderBy: 'identification ASC',
    );
    return result.map(Animal.fromMap).toList();
  }

  Future<List<Animal>> searchAnimals(
    String query, {
    String? sex,
    String? race,
    String? status,
    String? reproductiveRole,
    int? birthYear,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    final cleaned = query.trim();
    if (cleaned.isNotEmpty) {
      where.add('''(
        identification LIKE ? OR race LIKE ? OR notes LIKE ? OR
        mother_id IN (SELECT id FROM animals WHERE identification LIKE ?) OR
        father_id IN (SELECT id FROM animals WHERE identification LIKE ?)
      )''');
      args.addAll(['%$cleaned%', '%$cleaned%', '%$cleaned%', '%$cleaned%', '%$cleaned%']);
    }
    if (sex != null) { where.add('sexe = ?'); args.add(sex); }
    if (race != null && race.isNotEmpty) { where.add('race = ?'); args.add(race); }
    if (status != null) { where.add('status = ?'); args.add(status); }
    if (reproductiveRole != null) { where.add('reproductive_role = ?'); args.add(reproductiveRole); }
    if (birthYear != null) { where.add("substr(date_naissance, 1, 4) = ?"); args.add(birthYear.toString()); }
    final result = await db.query(
      'animals',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'identification ASC',
    );
    return result.map(Animal.fromMap).toList();
  }

  Future<Animal?> getAnimalById(int id) async {
    final rows = await (await database).query('animals', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Animal.fromMap(rows.first);
  }

  Future<List<Animal>> getChildren(int parentId) async {
    final rows = await (await database).query(
      'animals',
      where: 'mother_id = ? OR father_id = ?',
      whereArgs: [parentId, parentId],
      orderBy: 'date_naissance DESC',
    );
    return rows.map(Animal.fromMap).toList();
  }

  Future<List<Animal>> getAncestors(int animalId, {int maxGenerations = 3}) async {
    final result = <Animal>[];
    final seen = <int>{animalId};
    var ids = <int>[animalId];
    for (var generation = 0; generation < maxGenerations; generation++) {
      final next = <int>[];
      for (final id in ids) {
        final animal = await getAnimalById(id);
        for (final parentId in [animal?.motherId, animal?.fatherId]) {
          if (parentId != null && seen.add(parentId)) {
            final parent = await getAnimalById(parentId);
            if (parent != null) { result.add(parent); next.add(parentId); }
          }
        }
      }
      ids = next;
      if (ids.isEmpty) break;
    }
    return result;
  }

  Future<int> insertAnimal(Animal animal) async => (await database).insert(
        'animals', animal.toMap(), conflictAlgorithm: ConflictAlgorithm.abort,
      );

  Future<int> updateAnimal(Animal animal) async {
    if (animal.id == null) throw ArgumentError('Un identifiant est requis pour modifier un animal.');
    if (animal.motherId == animal.id || animal.fatherId == animal.id) throw ArgumentError('Un animal ne peut pas être son propre parent.');
    if (animal.motherId != null && animal.motherId == animal.fatherId) throw ArgumentError('La mère et le père doivent être différents.');
    return (await database).update('animals', animal.toMap(), where: 'id = ?', whereArgs: [animal.id]);
  }

  Future<void> archiveAnimal(int id, AnimalStatus status) async {
    await (await database).update(
      'animals',
      {'status': status.label, 'exit_date': status == AnimalStatus.active ? null : DateTime.now().toIso8601String()},
      where: 'id = ?', whereArgs: [id],
    );
  }

  Future<int> deleteAnimalPermanently(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.update('animals', {'mother_id': null}, where: 'mother_id = ?', whereArgs: [id]);
      await txn.update('animals', {'father_id': null}, where: 'father_id = ?', whereArgs: [id]);
      return txn.delete('animals', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> deleteAnimal(int id) => deleteAnimalPermanently(id);

  Future<int> countAnimals() async => Sqflite.firstIntValue(
        await (await database).rawQuery("SELECT COUNT(*) FROM animals WHERE status = 'Actif'"),
      ) ?? 0;

  Future<Map<String, int>> getDashboardStats() async {
    final db = await database;
    Future<int> count(String where, [List<Object?>? args]) async => Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM animals WHERE $where', args),
        ) ?? 0;
    return {
      'active': await count("status = 'Actif'"),
      'females': await count("status = 'Actif' AND sexe = 'Femelle'"),
      'males': await count("status = 'Actif' AND sexe = 'Mâle'"),
      'breeders': await count("status = 'Actif' AND reproductive_role = 'Reproducteur'"),
      'missingParents': await count("status = 'Actif' AND (mother_id IS NULL OR father_id IS NULL)"),
      'birthsThisYear': await count("substr(date_naissance, 1, 4) = ?", [DateTime.now().year.toString()]),
      'reproductionEvents': Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reproduction_events')) ?? 0,
    };
  }

  Future<List<String>> getAlerts() async {
    final db = await database;
    final alerts = <String>[];
    final active = await getAnimals(includeInactive: false);
    for (final animal in active) {
      if (animal.motherId == null || animal.fatherId == null) {
        alerts.add('${animal.identification} : filiation incomplète');
      }
    }

    final saillies = await db.rawQuery('''
      SELECT r.* FROM reproduction_events r
      WHERE r.type = 'saillie'
      AND NOT EXISTS (
        SELECT 1 FROM reproduction_events later
        WHERE later.animal_id = r.animal_id
        AND later.date > r.date
        AND later.type IN ('velage', 'avortement')
      )
      ORDER BY r.date DESC
    ''');
    final seenAnimals = <int>{};
    for (final row in saillies) {
      final animalId = row['animal_id'] as int;
      if (!seenAnimals.add(animalId)) continue;
      final animal = await getAnimalById(animalId);
      if (animal == null || !animal.isActive) continue;
      final breedingDate = DateTime.parse(row['date'] as String);
      final days = DateTime.now().difference(breedingDate).inDays;
      if (days >= 35 && days <= 70) {
        final diagnostic = await db.query(
          'reproduction_events',
          where: "animal_id = ? AND type = 'diagnostic' AND date > ?",
          whereArgs: [animalId, breedingDate.toIso8601String()],
          limit: 1,
        );
        if (diagnostic.isEmpty) alerts.add('${animal.identification} : diagnostic de gestation à prévoir');
      }
      if (days >= 270 && days <= 295) {
        alerts.add('${animal.identification} : vêlage probable prochainement (${days} j après saillie)');
      }
    }
    return alerts.take(40).toList();
  }

  Future<List<AnimalEvent>> getEventsForAnimal(int animalId) async {
    final rows = await (await database).query('animal_events', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return rows.map(AnimalEvent.fromMap).toList();
  }
  Future<int> insertEvent(AnimalEvent event) async => (await database).insert('animal_events', event.toMap());
  Future<int> deleteEvent(int eventId) async => (await database).delete('animal_events', where: 'id = ?', whereArgs: [eventId]);

  Future<List<ReproductionEvent>> getReproductionEventsForAnimal(int animalId) async {
    final rows = await (await database).query('reproduction_events', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return rows.map(ReproductionEvent.fromMap).toList();
  }
  Future<int> insertReproductionEvent(ReproductionEvent event) async => (await database).insert('reproduction_events', event.toMap());

  Future<int> recordCalving({required Animal calf, required ReproductionEvent event}) async {
    final db = await database;
    return db.transaction((txn) async {
      final calfId = await txn.insert('animals', calf.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
      final eventMap = event.toMap()..['calf_id'] = calfId;
      await txn.insert('reproduction_events', eventMap);
      if (event.calfWeight != null) {
        await txn.insert('weight_records', {
          'animal_id': calfId,
          'date': event.date.toIso8601String(),
          'weight': event.calfWeight,
          'notes': 'Poids de naissance',
        });
      }
      await txn.insert('animal_events', {
        'animal_id': event.animalId,
        'type': 'Vêlage',
        'date': event.date.toIso8601String(),
        'description': 'Naissance du veau ${calf.identification}',
      });
      return calfId;
    });
  }

  Future<List<HealthEvent>> getHealthEventsForAnimal(int animalId) async {
    final rows = await (await database).query('health_events', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return rows.map(HealthEvent.fromMap).toList();
  }
  Future<int> insertHealthEvent(HealthEvent event) async => (await database).insert('health_events', event.toMap());
  Future<List<WeightRecord>> getWeightRecordsForAnimal(int animalId) async {
    final rows = await (await database).query('weight_records', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return rows.map(WeightRecord.fromMap).toList();
  }
  Future<int> insertWeightRecord(WeightRecord record) async => (await database).insert('weight_records', record.toMap());
  Future<List<FeedingRecord>> getFeedingRecordsForAnimal(int animalId) async {
    final rows = await (await database).query('feeding_records', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return rows.map(FeedingRecord.fromMap).toList();
  }
  Future<int> insertFeedingRecord(FeedingRecord record) async => (await database).insert('feeding_records', record.toMap());
  Future<List<AnimalMovement>> getMovementsForAnimal(int animalId) async {
    final rows = await (await database).query('animal_movements', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return rows.map(AnimalMovement.fromMap).toList();
  }
  Future<int> insertAnimalMovement(AnimalMovement movement) async => (await database).insert('animal_movements', movement.toMap());

  Future<Directory> _backupDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(join(root.path, 'gestion_troupeau_backups'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<File> createDatabaseBackup() async {
    await database;
    final source = File(_databasePath!);
    final directory = await _backupDirectory();
    return source.copy(join(directory.path, 'troupeau_${_timestamp()}.db'));
  }

  Future<File> exportJson() async {
    final db = await database;
    const tables = ['animals', 'animal_events', 'reproduction_events', 'health_events', 'weight_records', 'feeding_records', 'animal_movements'];
    final data = <String, dynamic>{'schemaVersion': 8, 'exportedAt': DateTime.now().toIso8601String()};
    for (final table in tables) data[table] = await db.query(table);
    final directory = await _backupDirectory();
    final file = File(join(directory.path, 'troupeau_${_timestamp()}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file;
  }

  Future<List<FileSystemEntity>> listBackups() async {
    final directory = await _backupDirectory();
    final files = await directory.list().toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> restoreJson(File file) async {
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final db = await database;
    const order = ['animal_movements', 'feeding_records', 'weight_records', 'health_events', 'reproduction_events', 'animal_events', 'animals'];
    await db.transaction((txn) async {
      for (final table in order) await txn.delete(table);
      for (final table in order.reversed) {
        final rows = decoded[table];
        if (rows is! List) continue;
        for (final raw in rows) {
          final row = Map<String, Object?>.from(raw as Map);
          if (table == 'animals') row.putIfAbsent('reproductive_role', () => 'Inconnu');
          await txn.insert(table, row);
        }
      }
    });
  }
}
