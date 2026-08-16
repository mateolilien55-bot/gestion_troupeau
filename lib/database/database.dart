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

  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    final factory = _getDatabaseFactory();
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'gestion_troupeau.db');

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
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
        premier_velage TEXT,
        notes TEXT,
        mother_id INTEGER,
        father_id INTEGER,
        FOREIGN KEY (mother_id) REFERENCES animals (id) ON DELETE SET NULL,
        FOREIGN KEY (father_id) REFERENCES animals (id) ON DELETE SET NULL
      )
    ''');
    await _createAnimalEventsTable(db);
    await _createV3Tables(db);
    await _insertInitialAnimals(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createAnimalEventsTable(db);

    if (oldVersion < 3) {
      final columns = await db.rawQuery('PRAGMA table_info(animals)');
      final names = columns.map((column) => column['name']).toSet();
      if (!names.contains('mother_id')) {
        await db.execute('ALTER TABLE animals ADD COLUMN mother_id INTEGER');
      }
      if (!names.contains('father_id')) {
        await db.execute('ALTER TABLE animals ADD COLUMN father_id INTEGER');
      }
      await _createV3Tables(db);
    }

    if (oldVersion < 4) {
      final columns = await db.rawQuery('PRAGMA table_info(animals)');
      if (!columns.any((column) => column['name'] == 'sexe')) {
        await db.execute('ALTER TABLE animals ADD COLUMN sexe TEXT');
      }
    }

    // Version 6 intentionally enables foreign keys through onConfigure.
  }

  Future<void> _createAnimalEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS animal_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');
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

  Future<List<Animal>> getAnimals() async {
    final db = await database;
    final result = await db.query('animals', orderBy: 'identification ASC');
    return result.map(Animal.fromMap).toList();
  }

  Future<List<Animal>> searchAnimals(String query) async {
    final db = await database;
    final result = await db.query('animals', where: 'identification LIKE ?', whereArgs: ['%$query%'], orderBy: 'identification ASC');
    return result.map(Animal.fromMap).toList();
  }

  Future<Animal?> getAnimalById(int id) async {
    final db = await database;
    final result = await db.query('animals', where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isEmpty ? null : Animal.fromMap(result.first);
  }

  Future<int> insertAnimal(Animal animal) async {
    final db = await database;
    return db.insert('animals', animal.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> updateAnimal(Animal animal) async {
    if (animal.id == null) throw ArgumentError('Un identifiant est requis pour modifier un animal.');
    final db = await database;
    return db.update('animals', animal.toMap(), where: 'id = ?', whereArgs: [animal.id]);
  }

  Future<int> deleteAnimal(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.update('animals', {'mother_id': null}, where: 'mother_id = ?', whereArgs: [id]);
      await txn.update('animals', {'father_id': null}, where: 'father_id = ?', whereArgs: [id]);
      return txn.delete('animals', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> countAnimals() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM animals')) ?? 0;
  }

  Future<List<AnimalEvent>> getEventsForAnimal(int animalId) async {
    final db = await database;
    final result = await db.query('animal_events', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return result.map(AnimalEvent.fromMap).toList();
  }
  Future<int> insertEvent(AnimalEvent event) async => (await database).insert('animal_events', event.toMap());
  Future<int> deleteEvent(int eventId) async => (await database).delete('animal_events', where: 'id = ?', whereArgs: [eventId]);

  Future<List<ReproductionEvent>> getReproductionEventsForAnimal(int animalId) async {
    final result = await (await database).query('reproduction_events', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return result.map(ReproductionEvent.fromMap).toList();
  }
  Future<int> insertReproductionEvent(ReproductionEvent event) async => (await database).insert('reproduction_events', event.toMap());

  Future<List<HealthEvent>> getHealthEventsForAnimal(int animalId) async {
    final result = await (await database).query('health_events', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return result.map(HealthEvent.fromMap).toList();
  }
  Future<int> insertHealthEvent(HealthEvent event) async => (await database).insert('health_events', event.toMap());

  Future<List<WeightRecord>> getWeightRecordsForAnimal(int animalId) async {
    final result = await (await database).query('weight_records', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return result.map(WeightRecord.fromMap).toList();
  }
  Future<int> insertWeightRecord(WeightRecord record) async => (await database).insert('weight_records', record.toMap());

  Future<List<FeedingRecord>> getFeedingRecordsForAnimal(int animalId) async {
    final result = await (await database).query('feeding_records', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return result.map(FeedingRecord.fromMap).toList();
  }
  Future<int> insertFeedingRecord(FeedingRecord record) async => (await database).insert('feeding_records', record.toMap());

  Future<List<AnimalMovement>> getMovementsForAnimal(int animalId) async {
    final result = await (await database).query('animal_movements', where: 'animal_id = ?', whereArgs: [animalId], orderBy: 'date DESC');
    return result.map(AnimalMovement.fromMap).toList();
  }
  Future<int> insertAnimalMovement(AnimalMovement movement) async => (await database).insert('animal_movements', movement.toMap());
}
