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
      version: 1,
      onCreate: _onCreate,
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
        session_type TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        is_complete INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (cycle_id) REFERENCES cycles (id)
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
      orderBy: 'week ASC, session_type ASC',
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
}
