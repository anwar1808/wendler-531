import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/training_max.dart';
import '../models/cycle_model.dart';
import '../models/session_model.dart';
import '../models/set_log_model.dart';
import '../models/history_entry.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wendler_531.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE training_maxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lift TEXT NOT NULL UNIQUE,
        value_kg REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cycles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        is_complete INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id INTEGER NOT NULL,
        week INTEGER NOT NULL,
        lifts TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        is_complete INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (cycle_id) REFERENCES cycles (id)
      )
    ''');

    // Per-lift week tracking: which week each lift is on
    await db.execute('''
      CREATE TABLE lift_week (
        lift TEXT PRIMARY KEY,
        week INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE set_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        lift TEXT NOT NULL,
        set_number INTEGER NOT NULL,
        prescribed_weight REAL NOT NULL,
        prescribed_reps INTEGER NOT NULL,
        actual_reps INTEGER,
        is_complete INTEGER NOT NULL DEFAULT 0,
        is_amrap INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE history_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        lift TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        reps INTEGER NOT NULL,
        one_rm REAL NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        is_imported INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE bodyweight_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight_kg REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE zone2_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id INTEGER NOT NULL,
        week_number INTEGER NOT NULL,
        minutes INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE joint_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id INTEGER NOT NULL,
        week_num INTEGER NOT NULL,
        lift TEXT NOT NULL,
        severity INTEGER NOT NULL,
        is_immediate INTEGER NOT NULL DEFAULT 1,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE week_transition_decisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_id INTEGER NOT NULL,
        from_week INTEGER NOT NULL,
        lift TEXT NOT NULL,
        decision TEXT NOT NULL,
        severity INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await _seedHistoricalData(db);
  }

  Future<void> _seedHistoricalData(Database db) async {
    // Check if history_entries is empty (first launch guard)
    final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM history_entries');
    final count = countResult.first['cnt'] as int;
    if (count > 0) return;

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // All historical entries. Fields: date (yyyy-MM-dd), lift, weightKg, reps, oneRm, notes
    final entries = <Map<String, dynamic>>[
      {'date': '2024-09-25', 'lift': 'benchPress', 'weight_kg': 57.5, 'reps': 15, 'one_rm': 86.0, 'notes': ''},
      {'date': '2024-09-22', 'lift': 'deadlift', 'weight_kg': 85.0, 'reps': 5, 'one_rm': 99.0, 'notes': 'Reduce by 10kg next cycle'},
      {'date': '2024-09-18', 'lift': 'militaryPress', 'weight_kg': 35.0, 'reps': 11, 'one_rm': 48.0, 'notes': 'Lower max weight probably by 5'},
      {'date': '2024-09-17', 'lift': 'benchPress', 'weight_kg': 55.0, 'reps': 12, 'one_rm': 77.0, 'notes': ''},
      {'date': '2024-07-14', 'lift': 'deadlift', 'weight_kg': 100.0, 'reps': 6, 'one_rm': 120.0, 'notes': ''},
      {'date': '2024-07-10', 'lift': 'militaryPress', 'weight_kg': 40.0, 'reps': 10, 'one_rm': 53.0, 'notes': ''},
      {'date': '2024-06-29', 'lift': 'benchPress', 'weight_kg': 65.0, 'reps': 4, 'one_rm': 74.0, 'notes': 'Fly machine (50) x 6 reps x 3 sets'},
      {'date': '2024-06-06', 'lift': 'benchPress', 'weight_kg': 70.0, 'reps': 2, 'one_rm': 75.0, 'notes': ''},
      {'date': '2024-05-21', 'lift': 'deadlift', 'weight_kg': 100.0, 'reps': 4, 'one_rm': 113.0, 'notes': ''},
      {'date': '2024-05-20', 'lift': 'benchPress', 'weight_kg': 65.0, 'reps': 5, 'one_rm': 76.0, 'notes': 'Fly machine (50) x 6 reps x 3 sets'},
      {'date': '2024-04-30', 'lift': 'deadlift', 'weight_kg': 90.0, 'reps': 8, 'one_rm': 114.0, 'notes': ''},
      {'date': '2024-04-25', 'lift': 'benchPress', 'weight_kg': 62.5, 'reps': 8, 'one_rm': 79.0, 'notes': 'Fly machine (50) x 6 reps x 3 sets'},
      {'date': '2024-04-23', 'lift': 'militaryPress', 'weight_kg': 37.5, 'reps': 5, 'one_rm': 44.0, 'notes': ''},
      {'date': '2024-04-22', 'lift': 'deadlift', 'weight_kg': 85.0, 'reps': 10, 'one_rm': 113.0, 'notes': ''},
      {'date': '2024-04-17', 'lift': 'benchPress', 'weight_kg': 60.0, 'reps': 7, 'one_rm': 74.0, 'notes': ''},
      {'date': '2024-02-18', 'lift': 'militaryPress', 'weight_kg': 50.0, 'reps': 1, 'one_rm': 50.0, 'notes': ''},
      {'date': '2024-02-16', 'lift': 'deadlift', 'weight_kg': 100.0, 'reps': 3, 'one_rm': 110.0, 'notes': ''},
      {'date': '2024-02-12', 'lift': 'benchPress', 'weight_kg': 72.5, 'reps': 1, 'one_rm': 73.0, 'notes': 'Fly machine (50) x 6 reps x 3 sets'},
      {'date': '2024-02-05', 'lift': 'militaryPress', 'weight_kg': 47.5, 'reps': 2, 'one_rm': 51.0, 'notes': ''},
      {'date': '2024-02-04', 'lift': 'deadlift', 'weight_kg': 92.5, 'reps': 3, 'one_rm': 102.0, 'notes': ''},
      {'date': '2024-02-03', 'lift': 'benchPress', 'weight_kg': 70.0, 'reps': 3, 'one_rm': 77.0, 'notes': 'Fly machine (50) x 6 reps x 3 sets'},
      {'date': '2024-01-16', 'lift': 'deadlift', 'weight_kg': 90.0, 'reps': 6, 'one_rm': 108.0, 'notes': ''},
      {'date': '2024-01-12', 'lift': 'benchPress', 'weight_kg': 67.5, 'reps': 5, 'one_rm': 79.0, 'notes': ''},
      {'date': '2023-12-13', 'lift': 'militaryPress', 'weight_kg': 50.0, 'reps': 2, 'one_rm': 53.0, 'notes': ''},
      {'date': '2023-12-11', 'lift': 'deadlift', 'weight_kg': 95.0, 'reps': 4, 'one_rm': 108.0, 'notes': ''},
      {'date': '2023-12-08', 'lift': 'benchPress', 'weight_kg': 75.0, 'reps': 1, 'one_rm': 75.0, 'notes': ''},
      {'date': '2023-12-07', 'lift': 'deadlift', 'weight_kg': 90.0, 'reps': 5, 'one_rm': 105.0, 'notes': ''},
      {'date': '2023-12-03', 'lift': 'deadlift', 'weight_kg': 72.5, 'reps': 7, 'one_rm': 89.0, 'notes': ''},
      {'date': '2023-11-27', 'lift': 'benchPress', 'weight_kg': 70.0, 'reps': 3, 'one_rm': 77.0, 'notes': 'Pectoral Flys machine (50) x 6 reps x 3 sets'},
      {'date': '2023-11-23', 'lift': 'militaryPress', 'weight_kg': 45.0, 'reps': 4, 'one_rm': 51.0, 'notes': ''},
      {'date': '2023-11-19', 'lift': 'militaryPress', 'weight_kg': 42.5, 'reps': 4, 'one_rm': 48.0, 'notes': ''},
      {'date': '2023-11-18', 'lift': 'benchPress', 'weight_kg': 65.0, 'reps': 4, 'one_rm': 74.0, 'notes': ''},
      {'date': '2023-11-17', 'lift': 'deadlift', 'weight_kg': 77.5, 'reps': 10, 'one_rm': 103.0, 'notes': ''},
      {'date': '2023-11-15', 'lift': 'militaryPress', 'weight_kg': 45.0, 'reps': 2, 'one_rm': 48.0, 'notes': ''},
      {'date': '2023-11-14', 'lift': 'benchPress', 'weight_kg': 67.5, 'reps': 4, 'one_rm': 77.0, 'notes': ''},
      {'date': '2023-10-18', 'lift': 'militaryPress', 'weight_kg': 45.0, 'reps': 2, 'one_rm': 48.0, 'notes': ''},
      {'date': '2023-10-18', 'lift': 'deadlift', 'weight_kg': 72.5, 'reps': 6, 'one_rm': 87.0, 'notes': ''},
      {'date': '2023-10-17', 'lift': 'backSquat', 'weight_kg': 65.0, 'reps': 5, 'one_rm': 76.0, 'notes': ''},
      {'date': '2023-10-17', 'lift': 'benchPress', 'weight_kg': 65.0, 'reps': 5, 'one_rm': 76.0, 'notes': ''},
      {'date': '2023-10-09', 'lift': 'militaryPress', 'weight_kg': 40.0, 'reps': 7, 'one_rm': 49.0, 'notes': ''},
      {'date': '2023-10-08', 'lift': 'deadlift', 'weight_kg': 70.0, 'reps': 5, 'one_rm': 82.0, 'notes': ''},
      {'date': '2023-10-05', 'lift': 'militaryPress', 'weight_kg': 45.0, 'reps': 2, 'one_rm': 48.0, 'notes': ''},
      {'date': '2023-10-03', 'lift': 'benchPress', 'weight_kg': 60.0, 'reps': 5, 'one_rm': 70.0, 'notes': ''},
      {'date': '2023-10-02', 'lift': 'militaryPress', 'weight_kg': 42.5, 'reps': 2, 'one_rm': 45.0, 'notes': ''},
      {'date': '2023-09-16', 'lift': 'benchPress', 'weight_kg': 55.0, 'reps': 9, 'one_rm': 72.0, 'notes': 'Next one increase max load to 60kg'},
      {'date': '2023-09-11', 'lift': 'militaryPress', 'weight_kg': 40.0, 'reps': 1, 'one_rm': 40.0, 'notes': ''},
      {'date': '2023-09-08', 'lift': 'benchPress', 'weight_kg': 52.5, 'reps': 11, 'one_rm': 72.0, 'notes': ''},
      {'date': '2023-09-07', 'lift': 'militaryPress', 'weight_kg': 42.5, 'reps': 1, 'one_rm': 43.0, 'notes': ''},
      {'date': '2023-08-21', 'lift': 'benchPress', 'weight_kg': 50.0, 'reps': 12, 'one_rm': 70.0, 'notes': ''},
      {'date': '2023-08-10', 'lift': 'benchPress', 'weight_kg': 50.0, 'reps': 10, 'one_rm': 67.0, 'notes': ''},
      {'date': '2023-08-09', 'lift': 'militaryPress', 'weight_kg': 40.0, 'reps': 2, 'one_rm': 43.0, 'notes': ''},
      {'date': '2023-08-04', 'lift': 'benchPress', 'weight_kg': 45.0, 'reps': 12, 'one_rm': 63.0, 'notes': ''},
      {'date': '2023-08-02', 'lift': 'militaryPress', 'weight_kg': 35.0, 'reps': 5, 'one_rm': 41.0, 'notes': ''},
      {'date': '2023-07-31', 'lift': 'benchPress', 'weight_kg': 40.0, 'reps': 14, 'one_rm': 59.0, 'notes': ''},
      {'date': '2023-07-28', 'lift': 'benchPress', 'weight_kg': 42.5, 'reps': 13, 'one_rm': 61.0, 'notes': ''},
      {'date': '2023-07-22', 'lift': 'benchPress', 'weight_kg': 40.0, 'reps': 12, 'one_rm': 56.0, 'notes': ''},
      {'date': '2023-07-21', 'lift': 'militaryPress', 'weight_kg': 32.5, 'reps': 4, 'one_rm': 37.0, 'notes': ''},
      {'date': '2023-07-17', 'lift': 'militaryPress', 'weight_kg': 30.0, 'reps': 6, 'one_rm': 36.0, 'notes': ''},
      {'date': '2023-07-12', 'lift': 'militaryPress', 'weight_kg': 22.5, 'reps': 10, 'one_rm': 30.0, 'notes': ''},
      {'date': '2023-07-12', 'lift': 'benchPress', 'weight_kg': 37.5, 'reps': 10, 'one_rm': 50.0, 'notes': ''},
      {'date': '2023-03-03', 'lift': 'benchPress', 'weight_kg': 50.0, 'reps': 4, 'one_rm': 57.0, 'notes': ''},
      {'date': '2022-12-20', 'lift': 'militaryPress', 'weight_kg': 35.0, 'reps': 5, 'one_rm': 41.0, 'notes': ''},
      {'date': '2022-11-13', 'lift': 'militaryPress', 'weight_kg': 32.5, 'reps': 4, 'one_rm': 37.0, 'notes': ''},
      {'date': '2022-10-08', 'lift': 'deadlift', 'weight_kg': 70.0, 'reps': 5, 'one_rm': 82.0, 'notes': ''},
      {'date': '2022-10-08', 'lift': 'benchPress', 'weight_kg': 52.5, 'reps': 5, 'one_rm': 61.0, 'notes': ''},
      {'date': '2022-10-06', 'lift': 'backSquat', 'weight_kg': 70.0, 'reps': 3, 'one_rm': 77.0, 'notes': ''},
      {'date': '2022-10-02', 'lift': 'benchPress', 'weight_kg': 50.0, 'reps': 5, 'one_rm': 58.0, 'notes': ''},
      {'date': '2022-09-30', 'lift': 'militaryPress', 'weight_kg': 30.0, 'reps': 16, 'one_rm': 46.0, 'notes': ''},
      {'date': '2022-05-09', 'lift': 'benchPress', 'weight_kg': 60.0, 'reps': 5, 'one_rm': 70.0, 'notes': ''},
      {'date': '2022-05-09', 'lift': 'deadlift', 'weight_kg': 80.0, 'reps': 8, 'one_rm': 101.0, 'notes': ''},
      {'date': '2022-04-28', 'lift': 'backSquat', 'weight_kg': 77.5, 'reps': 6, 'one_rm': 93.0, 'notes': ''},
      {'date': '2022-04-16', 'lift': 'militaryPress', 'weight_kg': 40.0, 'reps': 4, 'one_rm': 45.0, 'notes': ''},
      {'date': '2022-04-12', 'lift': 'deadlift', 'weight_kg': 90.0, 'reps': 1, 'one_rm': 90.0, 'notes': ''},
      {'date': '2022-03-31', 'lift': 'backSquat', 'weight_kg': 70.0, 'reps': 9, 'one_rm': 91.0, 'notes': ''},
      {'date': '2022-03-31', 'lift': 'benchPress', 'weight_kg': 57.5, 'reps': 4, 'one_rm': 65.0, 'notes': ''},
      {'date': '2022-03-22', 'lift': 'militaryPress', 'weight_kg': 40.0, 'reps': 3, 'one_rm': 44.0, 'notes': ''},
      {'date': '2022-03-16', 'lift': 'benchPress', 'weight_kg': 55.0, 'reps': 5, 'one_rm': 64.0, 'notes': ''},
      {'date': '2022-03-16', 'lift': 'deadlift', 'weight_kg': 77.5, 'reps': 6, 'one_rm': 93.0, 'notes': ''},
      {'date': '2022-03-13', 'lift': 'militaryPress', 'weight_kg': 35.0, 'reps': 5, 'one_rm': 41.0, 'notes': ''},
      {'date': '2022-03-13', 'lift': 'backSquat', 'weight_kg': 65.0, 'reps': 11, 'one_rm': 89.0, 'notes': ''},
      {'date': '2022-02-23', 'lift': 'benchPress', 'weight_kg': 55.0, 'reps': 8, 'one_rm': 70.0, 'notes': ''},
      {'date': '2022-02-23', 'lift': 'deadlift', 'weight_kg': 65.0, 'reps': 10, 'one_rm': 87.0, 'notes': ''},
      {'date': '2022-02-17', 'lift': 'militaryPress', 'weight_kg': 35.0, 'reps': 7, 'one_rm': 43.0, 'notes': ''},
      {'date': '2022-02-17', 'lift': 'backSquat', 'weight_kg': 65.0, 'reps': 10, 'one_rm': 87.0, 'notes': ''},
      {'date': '2022-02-15', 'lift': 'benchPress', 'weight_kg': 50.0, 'reps': 6, 'one_rm': 60.0, 'notes': ''},
      {'date': '2022-02-15', 'lift': 'deadlift', 'weight_kg': 60.0, 'reps': 8, 'one_rm': 76.0, 'notes': ''},
      {'date': '2022-02-09', 'lift': 'militaryPress', 'weight_kg': 32.5, 'reps': 9, 'one_rm': 42.0, 'notes': ''},
      {'date': '2022-02-09', 'lift': 'backSquat', 'weight_kg': 52.5, 'reps': 10, 'one_rm': 70.0, 'notes': ''},
      {'date': '2022-02-03', 'lift': 'militaryPress', 'weight_kg': 27.5, 'reps': 7, 'one_rm': 34.0, 'notes': ''},
      {'date': '2022-02-03', 'lift': 'deadlift', 'weight_kg': 42.5, 'reps': 12, 'one_rm': 59.0, 'notes': ''},
      {'date': '2022-02-02', 'lift': 'backSquat', 'weight_kg': 37.5, 'reps': 20, 'one_rm': 62.0, 'notes': ''},
      {'date': '2022-02-02', 'lift': 'benchPress', 'weight_kg': 45.0, 'reps': 10, 'one_rm': 60.0, 'notes': ''},
      {'date': '2019-02-23', 'lift': 'backSquat', 'weight_kg': 80.0, 'reps': 2, 'one_rm': 85.0, 'notes': ''},
      {'date': '2019-02-23', 'lift': 'deadlift', 'weight_kg': 90.0, 'reps': 3, 'one_rm': 99.0, 'notes': ''},
      {'date': '2019-01-24', 'lift': 'benchPress', 'weight_kg': 60.0, 'reps': 3, 'one_rm': 66.0, 'notes': ''},
      {'date': '2019-01-03', 'lift': 'militaryPress', 'weight_kg': 37.5, 'reps': 2, 'one_rm': 40.0, 'notes': ''},
      {'date': '2018-12-27', 'lift': 'benchPress', 'weight_kg': 57.5, 'reps': 4, 'one_rm': 65.0, 'notes': ''},
      {'date': '2018-12-23', 'lift': 'militaryPress', 'weight_kg': 35.0, 'reps': 3, 'one_rm': 39.0, 'notes': ''},
      {'date': '2018-12-15', 'lift': 'backSquat', 'weight_kg': 77.5, 'reps': 3, 'one_rm': 85.0, 'notes': ''},
      {'date': '2018-12-15', 'lift': 'deadlift', 'weight_kg': 85.0, 'reps': 5, 'one_rm': 99.0, 'notes': ''},
      {'date': '2018-12-14', 'lift': 'benchPress', 'weight_kg': 50.0, 'reps': 8, 'one_rm': 63.0, 'notes': ''},
      {'date': '2018-12-11', 'lift': 'militaryPress', 'weight_kg': 35.0, 'reps': 3, 'one_rm': 39.0, 'notes': ''},
      {'date': '2018-11-06', 'lift': 'backSquat', 'weight_kg': 77.5, 'reps': 3, 'one_rm': 85.0, 'notes': ''},
      {'date': '2018-11-06', 'lift': 'benchPress', 'weight_kg': 55.0, 'reps': 3, 'one_rm': 61.0, 'notes': ''},
      {'date': '2018-10-26', 'lift': 'militaryPress', 'weight_kg': 37.5, 'reps': 1, 'one_rm': 38.0, 'notes': ''},
      {'date': '2018-10-26', 'lift': 'deadlift', 'weight_kg': 85.0, 'reps': 5, 'one_rm': 99.0, 'notes': ''},
      {'date': '2018-09-26', 'lift': 'benchPress', 'weight_kg': 50.0, 'reps': 6, 'one_rm': 60.0, 'notes': ''},
      {'date': '2018-09-26', 'lift': 'deadlift', 'weight_kg': 80.0, 'reps': 6, 'one_rm': 96.0, 'notes': ''},
      {'date': '2018-09-19', 'lift': 'militaryPress', 'weight_kg': 35.0, 'reps': 4, 'one_rm': 40.0, 'notes': ''},
      {'date': '2018-09-19', 'lift': 'backSquat', 'weight_kg': 72.5, 'reps': 5, 'one_rm': 85.0, 'notes': ''},
      {'date': '2018-09-14', 'lift': 'benchPress', 'weight_kg': 45.0, 'reps': 8, 'one_rm': 57.0, 'notes': ''},
      {'date': '2018-09-14', 'lift': 'deadlift', 'weight_kg': 75.0, 'reps': 6, 'one_rm': 90.0, 'notes': ''},
      {'date': '2018-08-31', 'lift': 'militaryPress', 'weight_kg': 30.0, 'reps': 8, 'one_rm': 38.0, 'notes': ''},
      {'date': '2018-08-31', 'lift': 'backSquat', 'weight_kg': 67.5, 'reps': 7, 'one_rm': 83.0, 'notes': ''},
      {'date': '2018-08-10', 'lift': 'deadlift', 'weight_kg': 75.0, 'reps': 5, 'one_rm': 88.0, 'notes': ''},
      {'date': '2018-08-10', 'lift': 'benchPress', 'weight_kg': 45.0, 'reps': 4, 'one_rm': 51.0, 'notes': ''},
      {'date': '2018-08-03', 'lift': 'militaryPress', 'weight_kg': 32.5, 'reps': 4, 'one_rm': 37.0, 'notes': ''},
      {'date': '2018-08-03', 'lift': 'backSquat', 'weight_kg': 70.0, 'reps': 5, 'one_rm': 82.0, 'notes': ''},
      {'date': '2018-08-01', 'lift': 'deadlift', 'weight_kg': 70.0, 'reps': 7, 'one_rm': 86.0, 'notes': ''},
      {'date': '2018-08-01', 'lift': 'benchPress', 'weight_kg': 40.0, 'reps': 7, 'one_rm': 49.0, 'notes': ''},
      {'date': '2018-07-28', 'lift': 'militaryPress', 'weight_kg': 30.0, 'reps': 5, 'one_rm': 35.0, 'notes': ''},
      {'date': '2018-07-28', 'lift': 'backSquat', 'weight_kg': 62.5, 'reps': 8, 'one_rm': 79.0, 'notes': ''},
      {'date': '2018-07-27', 'lift': 'deadlift', 'weight_kg': 57.5, 'reps': 14, 'one_rm': 84.0, 'notes': ''},
      {'date': '2018-07-27', 'lift': 'benchPress', 'weight_kg': 32.5, 'reps': 14, 'one_rm': 48.0, 'notes': ''},
      {'date': '2018-07-20', 'lift': 'militaryPress', 'weight_kg': 25.0, 'reps': 11, 'one_rm': 34.0, 'notes': ''},
      {'date': '2018-07-20', 'lift': 'backSquat', 'weight_kg': 57.5, 'reps': 10, 'one_rm': 77.0, 'notes': ''},
      {'date': '2018-07-11', 'lift': 'deadlift', 'weight_kg': 60.0, 'reps': 10, 'one_rm': 80.0, 'notes': ''},
      {'date': '2018-07-11', 'lift': 'backSquat', 'weight_kg': 60.0, 'reps': 6, 'one_rm': 72.0, 'notes': ''},
      {'date': '2018-07-08', 'lift': 'benchPress', 'weight_kg': 34.0, 'reps': 11, 'one_rm': 46.0, 'notes': ''},
      {'date': '2018-07-06', 'lift': 'backSquat', 'weight_kg': 57.0, 'reps': 5, 'one_rm': 67.0, 'notes': ''},
      {'date': '2018-07-06', 'lift': 'militaryPress', 'weight_kg': 26.0, 'reps': 8, 'one_rm': 33.0, 'notes': ''},
      {'date': '2018-07-03', 'lift': 'deadlift', 'weight_kg': 57.0, 'reps': 10, 'one_rm': 76.0, 'notes': ''},
      {'date': '2018-07-03', 'lift': 'benchPress', 'weight_kg': 32.0, 'reps': 12, 'one_rm': 45.0, 'notes': ''},
      {'date': '2018-06-27', 'lift': 'deadlift', 'weight_kg': 54.0, 'reps': 10, 'one_rm': 72.0, 'notes': ''},
      {'date': '2018-06-27', 'lift': 'militaryPress', 'weight_kg': 24.0, 'reps': 9, 'one_rm': 31.0, 'notes': ''},
      {'date': '2018-06-24', 'lift': 'militaryPress', 'weight_kg': 23.0, 'reps': 10, 'one_rm': 31.0, 'notes': ''},
      {'date': '2018-06-24', 'lift': 'backSquat', 'weight_kg': 54.0, 'reps': 5, 'one_rm': 63.0, 'notes': ''},
      {'date': '2018-06-19', 'lift': 'benchPress', 'weight_kg': 31.0, 'reps': 8, 'one_rm': 39.0, 'notes': ''},
    ];

    final batch = db.batch();
    for (final e in entries) {
      batch.insert('history_entries', {
        'date': e['date'],
        'lift': e['lift'],
        'weight_kg': e['weight_kg'],
        'reps': e['reps'],
        'one_rm': e['one_rm'],
        'notes': e['notes'],
        'is_imported': 1,
      });
    }
    await batch.commit(noResult: true);

    // Set training maxes: joint-safe 1RM × 85%, rounded to nearest 2.5kg
    // benchPress: joint-safe ~60kg × 0.85 = 51kg
    // deadlift: joint-safe ~75kg × 0.85 = 63.75 → 65.0kg
    // militaryPress: joint-safe ~37.5kg × 0.85 = 31.875 → 32.5kg
    // backSquat: joint-safe ~60kg × 0.85 = 51kg
    final trainingMaxes = [
      {'lift': 'benchPress', 'value_kg': 52.5, 'updated_at': todayStr},
      {'lift': 'deadlift', 'value_kg': 65.0, 'updated_at': todayStr},
      {'lift': 'militaryPress', 'value_kg': 32.5, 'updated_at': todayStr},
      {'lift': 'backSquat', 'value_kg': 52.5, 'updated_at': todayStr},
    ];
    for (final tm in trainingMaxes) {
      await db.insert('training_maxes', tm, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Insert initial cycle (number=1, start_date=today, is_complete=0)
    await db.insert('cycles', {
      'number': 1,
      'start_date': todayStr,
      'is_complete': 0,
    });

    // Set all lifts to week 1
    for (final lift in ['benchPress', 'deadlift', 'militaryPress', 'backSquat']) {
      await db.insert(
        'lift_week',
        {'lift': lift, 'week': 1},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Seed bodyweight entries (deduplicate by date — average if multiple same day)
    final bwRaw = [
      {'date': '2018-06-24', 'weight_kg': 53.0},
      {'date': '2018-06-27', 'weight_kg': 54.5},
      {'date': '2018-07-03', 'weight_kg': 54.5},
      {'date': '2018-07-06', 'weight_kg': 54.55},
      {'date': '2018-07-08', 'weight_kg': 54.6},
      {'date': '2018-07-11', 'weight_kg': 54.6},
      {'date': '2018-07-16', 'weight_kg': 55.1},
      {'date': '2018-07-19', 'weight_kg': 55.1},
      {'date': '2018-07-20', 'weight_kg': 55.6},
      {'date': '2018-07-27', 'weight_kg': 55.6},
      {'date': '2018-07-28', 'weight_kg': 55.7},
      {'date': '2018-07-31', 'weight_kg': 56.5},
      {'date': '2018-08-01', 'weight_kg': 55.7},
      {'date': '2018-08-02', 'weight_kg': 56.5},
      {'date': '2018-08-03', 'weight_kg': 55.5},
      {'date': '2018-08-09', 'weight_kg': 56.9},
      {'date': '2018-08-10', 'weight_kg': 55.5},
      {'date': '2018-08-21', 'weight_kg': 58.4},
      {'date': '2018-08-31', 'weight_kg': 55.6},
      {'date': '2018-09-07', 'weight_kg': 56.9},
      {'date': '2018-09-08', 'weight_kg': 57.7},
      {'date': '2018-09-11', 'weight_kg': 58.4},
      {'date': '2018-09-14', 'weight_kg': 55.6},
      {'date': '2018-09-16', 'weight_kg': 58.0},
      {'date': '2018-09-19', 'weight_kg': 56.0},
      {'date': '2018-09-26', 'weight_kg': 56.0},
      {'date': '2018-10-26', 'weight_kg': 57.1},
      {'date': '2018-11-06', 'weight_kg': 57.1},
      {'date': '2018-12-11', 'weight_kg': 57.5},
      {'date': '2018-12-14', 'weight_kg': 57.5},
      {'date': '2018-12-15', 'weight_kg': 57.85},
      {'date': '2018-12-23', 'weight_kg': 58.2},
      {'date': '2018-12-27', 'weight_kg': 58.2},
      {'date': '2019-01-03', 'weight_kg': 57.5},
      {'date': '2019-01-24', 'weight_kg': 57.5},
      {'date': '2019-02-23', 'weight_kg': 57.5},
      {'date': '2022-02-02', 'weight_kg': 59.8},
      {'date': '2022-02-03', 'weight_kg': 59.8},
      {'date': '2022-02-09', 'weight_kg': 59.7},
      {'date': '2022-02-15', 'weight_kg': 59.7},
      {'date': '2022-02-17', 'weight_kg': 59.4},
      {'date': '2022-02-23', 'weight_kg': 59.4},
      {'date': '2022-03-13', 'weight_kg': 58.7},
      {'date': '2022-03-16', 'weight_kg': 58.7},
      {'date': '2022-03-22', 'weight_kg': 58.0},
      {'date': '2022-03-31', 'weight_kg': 58.0},
      {'date': '2022-04-12', 'weight_kg': 58.0},
      {'date': '2022-04-16', 'weight_kg': 55.4},
      {'date': '2022-04-28', 'weight_kg': 55.4},
      {'date': '2022-05-09', 'weight_kg': 55.4},
      {'date': '2022-09-30', 'weight_kg': 58.0},
      {'date': '2022-10-06', 'weight_kg': 58.0},
      {'date': '2022-10-08', 'weight_kg': 57.85},
      {'date': '2022-11-13', 'weight_kg': 57.7},
      {'date': '2023-07-12', 'weight_kg': 55.2},
      {'date': '2023-07-17', 'weight_kg': 57.0},
      {'date': '2023-07-21', 'weight_kg': 56.5},
      {'date': '2023-07-22', 'weight_kg': 57.0},
      {'date': '2023-07-28', 'weight_kg': 56.5},
      {'date': '2023-07-31', 'weight_kg': 56.5},
      {'date': '2023-08-02', 'weight_kg': 56.5},
      {'date': '2023-08-04', 'weight_kg': 56.9},
      {'date': '2023-08-09', 'weight_kg': 56.9},
      {'date': '2023-08-10', 'weight_kg': 56.9},
      {'date': '2023-08-21', 'weight_kg': 58.4},
      {'date': '2023-09-07', 'weight_kg': 56.9},
      {'date': '2023-09-08', 'weight_kg': 57.7},
      {'date': '2023-09-11', 'weight_kg': 58.4},
      {'date': '2023-09-16', 'weight_kg': 58.0},
      {'date': '2023-10-02', 'weight_kg': 57.7},
      {'date': '2023-10-03', 'weight_kg': 58.2},
      {'date': '2023-10-05', 'weight_kg': 58.0},
      {'date': '2023-10-08', 'weight_kg': 58.2},
      {'date': '2023-10-09', 'weight_kg': 58.2},
      {'date': '2023-10-17', 'weight_kg': 58.25},
      {'date': '2023-10-18', 'weight_kg': 58.3},
      {'date': '2023-11-14', 'weight_kg': 58.3},
      {'date': '2023-11-15', 'weight_kg': 58.3},
      {'date': '2023-11-17', 'weight_kg': 58.3},
      {'date': '2023-11-18', 'weight_kg': 58.3},
      {'date': '2023-11-19', 'weight_kg': 58.3},
      {'date': '2023-11-23', 'weight_kg': 58.6},
      {'date': '2023-11-27', 'weight_kg': 58.6},
      {'date': '2023-12-03', 'weight_kg': 58.3},
      {'date': '2023-12-07', 'weight_kg': 58.6},
      {'date': '2023-12-08', 'weight_kg': 59.3},
      {'date': '2023-12-11', 'weight_kg': 59.3},
      {'date': '2023-12-13', 'weight_kg': 59.3},
    ];

    // Deduplicate by date — average if multiple same day
    final bwByDate = <String, List<double>>{};
    for (final e in bwRaw) {
      final d = e['date'] as String;
      final w = e['weight_kg'] as double;
      bwByDate.putIfAbsent(d, () => []).add(w);
    }
    final bwBatch = db.batch();
    for (final entry in bwByDate.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      bwBatch.insert('bodyweight_entries', {
        'date': entry.key,
        'weight_kg': avg,
      });
    }
    await bwBatch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate: add lifts column to sessions (if not exists)
      try {
        await db.execute('ALTER TABLE sessions ADD COLUMN lifts TEXT NOT NULL DEFAULT ""');
      } catch (_) {}

      // Populate lifts from session_type for any existing rows
      try {
        await db.execute(
          'UPDATE sessions SET lifts = CASE session_type WHEN "mon" THEN "backSquat,benchPress" WHEN "thu" THEN "deadlift,militaryPress" ELSE "" END WHERE lifts = ""',
        );
      } catch (_) {}

      // Create lift_week table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS lift_week (
            lift TEXT PRIMARY KEY,
            week INTEGER NOT NULL DEFAULT 1
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bodyweight_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            weight_kg REAL NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS zone2_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cycle_id INTEGER NOT NULL,
            week_number INTEGER NOT NULL,
            minutes INTEGER NOT NULL,
            date TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS joint_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cycle_id INTEGER NOT NULL,
            week_num INTEGER NOT NULL,
            lift TEXT NOT NULL,
            severity INTEGER NOT NULL,
            is_immediate INTEGER NOT NULL DEFAULT 1,
            date TEXT NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS week_transition_decisions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cycle_id INTEGER NOT NULL,
            from_week INTEGER NOT NULL,
            lift TEXT NOT NULL,
            decision TEXT NOT NULL,
            severity INTEGER NOT NULL,
            date TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
  }

  // Training Maxes
  Future<void> upsertTrainingMax(TrainingMax tm) async {
    final db = await database;
    await db.insert(
      'training_maxes',
      tm.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TrainingMax>> getAllTrainingMaxes() async {
    final db = await database;
    final maps = await db.query('training_maxes');
    return maps.map((m) => TrainingMax.fromMap(m)).toList();
  }

  Future<TrainingMax?> getTrainingMax(String lift) async {
    final db = await database;
    final maps = await db.query('training_maxes', where: 'lift = ?', whereArgs: [lift]);
    if (maps.isEmpty) return null;
    return TrainingMax.fromMap(maps.first);
  }

  // Cycles
  Future<int> insertCycle(CycleModel cycle) async {
    final db = await database;
    return await db.insert('cycles', cycle.toMap());
  }

  Future<CycleModel?> getCurrentCycle() async {
    final db = await database;
    final maps = await db.query(
      'cycles',
      where: 'is_complete = 0',
      orderBy: 'number DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CycleModel.fromMap(maps.first);
  }

  Future<List<CycleModel>> getAllCycles() async {
    final db = await database;
    final maps = await db.query('cycles', orderBy: 'number ASC');
    return maps.map((m) => CycleModel.fromMap(m)).toList();
  }

  Future<void> completeCycle(int cycleId) async {
    final db = await database;
    await db.update(
      'cycles',
      {'is_complete': 1},
      where: 'id = ?',
      whereArgs: [cycleId],
    );
  }

  Future<void> deleteCycle(int cycleId) async {
    final db = await database;
    // Delete set logs for sessions in this cycle
    final sessions = await getSessionsForCycle(cycleId);
    for (final s in sessions) {
      if (s.id != null) {
        await deleteSetLogsForSession(s.id!);
      }
    }
    // Delete sessions
    await db.delete('sessions', where: 'cycle_id = ?', whereArgs: [cycleId]);
    // Delete cycle
    await db.delete('cycles', where: 'id = ?', whereArgs: [cycleId]);
  }

  Future<void> updateCycleStartDate(int cycleId, String startDate) async {
    final db = await database;
    await db.update(
      'cycles',
      {'start_date': startDate},
      where: 'id = ?',
      whereArgs: [cycleId],
    );
  }

  // Sessions
  Future<int> insertSession(SessionModel session) async {
    final db = await database;
    return await db.insert('sessions', session.toMap());
  }

  Future<List<SessionModel>> getSessionsForCycle(int cycleId) async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
      orderBy: 'week ASC, id ASC',
    );
    return maps.map((m) => SessionModel.fromMap(m)).toList();
  }

  Future<List<SessionModel>> getAllCompletedSessions() async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'is_complete = 1',
      orderBy: 'date DESC',
    );
    return maps.map((m) => SessionModel.fromMap(m)).toList();
  }

  Future<void> updateSession(SessionModel session) async {
    final db = await database;
    await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  // Set Logs
  Future<int> insertSetLog(SetLogModel setLog) async {
    final db = await database;
    return await db.insert('set_logs', setLog.toMap());
  }

  Future<List<SetLogModel>> getSetLogsForSession(int sessionId) async {
    final db = await database;
    final maps = await db.query(
      'set_logs',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'lift ASC, set_number ASC',
    );
    return maps.map((m) => SetLogModel.fromMap(m)).toList();
  }

  Future<void> updateSetLog(SetLogModel setLog) async {
    final db = await database;
    await db.update(
      'set_logs',
      setLog.toMap(),
      where: 'id = ?',
      whereArgs: [setLog.id],
    );
  }

  Future<void> deleteSetLogsForSession(int sessionId) async {
    final db = await database;
    await db.delete('set_logs', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  Future<void> deleteSessionById(int sessionId, String date, List<String> liftKeys) async {
    final db = await database;
    await db.delete('set_logs', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
    // Also remove corresponding history entries so graph is updated
    for (final lift in liftKeys) {
      await db.delete('history_entries',
          where: 'date = ? AND lift = ? AND is_imported = 0',
          whereArgs: [date, lift]);
    }
  }

  // Per-lift week tracking
  Future<int> getLiftWeek(String lift) async {
    final db = await database;
    final maps = await db.query('lift_week', where: 'lift = ?', whereArgs: [lift]);
    if (maps.isEmpty) return 1;
    return maps.first['week'] as int;
  }

  Future<void> setLiftWeek(String lift, int week) async {
    final db = await database;
    await db.insert(
      'lift_week',
      {'lift': lift, 'week': week},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, int>> getAllLiftWeeks() async {
    final db = await database;
    final maps = await db.query('lift_week');
    return {for (final m in maps) m['lift'] as String: m['week'] as int};
  }

  // History Entries
  Future<int> insertHistoryEntry(HistoryEntry entry) async {
    final db = await database;
    return await db.insert('history_entries', entry.toMap());
  }

  Future<List<HistoryEntry>> getAllHistoryEntries() async {
    final db = await database;
    final maps = await db.query('history_entries', orderBy: 'date DESC');
    return maps.map((m) => HistoryEntry.fromMap(m)).toList();
  }

  Future<List<HistoryEntry>> getHistoryForLift(String lift) async {
    final db = await database;
    final maps = await db.query(
      'history_entries',
      where: 'lift = ?',
      whereArgs: [lift],
      orderBy: 'date ASC',
    );
    return maps.map((m) => HistoryEntry.fromMap(m)).toList();
  }

  Future<HistoryEntry?> getLatestHistoryForLift(String lift) async {
    final db = await database;
    final maps = await db.query(
      'history_entries',
      where: 'lift = ?',
      whereArgs: [lift],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return HistoryEntry.fromMap(maps.first);
  }

  Future<void> clearImportedHistory() async {
    final db = await database;
    await db.delete('history_entries', where: 'is_imported = 1');
  }

  Future<bool> hasAnyData() async {
    final db = await database;
    final result = await db.query('training_maxes', limit: 1);
    return result.isNotEmpty;
  }

  // Bodyweight entries
  Future<void> insertBodyweight(String date, double weightKg) async {
    final db = await database;
    await db.insert(
      'bodyweight_entries',
      {'date': date, 'weight_kg': weightKg},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getBodyweightEntries() async {
    final db = await database;
    return await db.query('bodyweight_entries', orderBy: 'date ASC');
  }

  Future<void> insertZone2Log(int cycleId, int weekNumber, int minutes, String date) async {
    final db = await database;
    await db.insert('zone2_logs', {
      'cycle_id': cycleId,
      'week_number': weekNumber,
      'minutes': minutes,
      'date': date,
    });
  }

  Future<int> getZone2MinutesForWeek(int cycleId, int weekNumber) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(minutes), 0) as total FROM zone2_logs WHERE cycle_id = ? AND week_number = ?',
      [cycleId, weekNumber],
    );
    return (result.first['total'] as num).toInt();
  }

  Future<List<Map<String, dynamic>>> getImportedHistoryEntries() async {
    final db = await database;
    return await db.query(
      'history_entries',
      where: 'is_imported = 1',
      orderBy: 'date DESC',
    );
  }

  // Joint logs
  Future<void> insertJointLog(
      int cycleId, int weekNum, String lift, int severity, bool isImmediate, String date) async {
    final db = await database;
    await db.insert('joint_logs', {
      'cycle_id': cycleId,
      'week_num': weekNum,
      'lift': lift,
      'severity': severity,
      'is_immediate': isImmediate ? 1 : 0,
      'date': date,
    });
  }

  Future<int?> getImmediateJointSeverity(int cycleId, int weekNum, String lift) async {
    final db = await database;
    final rows = await db.query(
      'joint_logs',
      where: 'cycle_id = ? AND week_num = ? AND lift = ? AND is_immediate = 1',
      whereArgs: [cycleId, weekNum, lift],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['severity'] as int;
  }

  // Week transition decisions
  Future<void> insertWeekTransitionDecision(
      int cycleId, int fromWeek, String lift, String decision, int severity, String date) async {
    final db = await database;
    await db.insert('week_transition_decisions', {
      'cycle_id': cycleId,
      'from_week': fromWeek,
      'lift': lift,
      'decision': decision,
      'severity': severity,
      'date': date,
    });
  }

  Future<String?> getWeekTransitionDecision(int cycleId, int fromWeek, String lift) async {
    final db = await database;
    final rows = await db.query(
      'week_transition_decisions',
      where: 'cycle_id = ? AND from_week = ? AND lift = ?',
      whereArgs: [cycleId, fromWeek, lift],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['decision'] as String;
  }

  Future<Map<String, String>> getAllTransitionDecisionsForCycle(int cycleId) async {
    final db = await database;
    final rows = await db.query(
      'week_transition_decisions',
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
    );
    final result = <String, String>{};
    for (final row in rows) {
      final key = '${row['from_week']}_${row['lift']}';
      result[key] = row['decision'] as String;
    }
    return result;
  }

  Future<Map<String, int>> getAllImmediateJointLogsForCycle(int cycleId) async {
    final db = await database;
    final rows = await db.query(
      'joint_logs',
      where: 'cycle_id = ? AND is_immediate = 1',
      whereArgs: [cycleId],
    );
    final result = <String, int>{};
    for (final row in rows) {
      final key = '${row['week_num']}_${row['lift']}';
      result[key] = row['severity'] as int;
    }
    return result;
  }
}
