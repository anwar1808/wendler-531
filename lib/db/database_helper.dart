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
      version: 8,
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
    // Check if cycles table is empty (first launch guard)
    final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM cycles');
    final count = countResult.first['cnt'] as int;
    if (count > 0) return;

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // TMs start at 0 — user must configure them in Settings before starting
    for (final lift in ['benchPress', 'deadlift', 'militaryPress', 'backSquat']) {
      await db.insert(
        'training_maxes',
        {'lift': lift, 'value_kg': 0.0, 'updated_at': todayStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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
    // No historical entries, no bodyweight data — user starts fresh
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
            tm_before REAL NOT NULL DEFAULT 0,
            date TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      // Add tm_before column to existing week_transition_decisions table
      try {
        await db.execute(
            'ALTER TABLE week_transition_decisions ADD COLUMN tm_before REAL NOT NULL DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      // Migrate notes from history_entries → sessions for app-logged entries.
      // For each non-imported history entry with non-empty notes, find the
      // matching session (same date, same lift) and copy the notes across if
      // the session notes are currently empty.
      try {
        final entries = await db.query(
          'history_entries',
          where: 'is_imported = 0 AND notes != ""',
        );
        for (final e in entries) {
          final date = e['date'] as String;
          final lift = e['lift'] as String;
          final notes = e['notes'] as String;
          // Find sessions on that date that include this lift and have empty notes
          final sessions = await db.query(
            'sessions',
            where: 'date = ? AND notes = "" AND lifts LIKE ?',
            whereArgs: [date, '%$lift%'],
          );
          for (final s in sessions) {
            await db.update(
              'sessions',
              {'notes': notes},
              where: 'id = ?',
              whereArgs: [s['id']],
            );
          }
        }
      } catch (_) {}
    }
    if (oldVersion < 8) {
      // Fix corrupted TMs caused by the tm_before=0 bug in commitWeekTransition.
      // When an old transition decision had tm_before=0 (legacy default from the
      // v6 ALTER TABLE migration), applying "progress" produced newTm = 0 + increment.
      // Strategy: for each lift whose TM is suspiciously low (≤ 10kg), back-calculate
      // the real TM from the AMRAP weight logged in the corresponding session, then
      // re-apply the transition decision.
      try {
        // AMRAP set percentage per week
        const amrapPctByWeek = {1: 0.85, 2: 0.90, 3: 0.95, 4: 0.60};
        // TM increment per lift
        const tmIncrements = {
          'backSquat': 5.0,
          'deadlift': 5.0,
          'benchPress': 2.5,
          'militaryPress': 2.5,
        };

        for (final liftEntry in tmIncrements.entries) {
          final lift = liftEntry.key;
          final increment = liftEntry.value;

          final tmRows = await db.query('training_maxes',
              where: 'lift = ?', whereArgs: [lift]);
          if (tmRows.isEmpty) continue;
          final currentTm = (tmRows.first['value_kg'] as num).toDouble();
          if (currentTm > 10.0) continue; // not corrupted

          // Find the latest transition decision with tm_before = 0 for this lift
          final decRows = await db.query('week_transition_decisions',
              where: 'lift = ? AND tm_before <= 0',
              whereArgs: [lift],
              orderBy: 'date DESC',
              limit: 1);
          if (decRows.isEmpty) continue;

          final fromWeek = decRows.first['from_week'] as int;
          final decision = decRows.first['decision'] as String;
          final decId = decRows.first['id'] as int;

          // Find the completed session for this week + lift
          final sessRows = await db.query('sessions',
              where: 'lifts LIKE ? AND week = ? AND is_complete = 1',
              whereArgs: ['%$lift%', fromWeek],
              orderBy: 'date DESC',
              limit: 1);
          if (sessRows.isEmpty) continue;

          final sessDate = sessRows.first['date'] as String;

          // Find the AMRAP history entry logged on that session date
          final histRows = await db.query('history_entries',
              where: 'lift = ? AND date = ? AND is_imported = 0',
              whereArgs: [lift, sessDate],
              limit: 1);
          if (histRows.isEmpty) continue;

          final amrapWeight = (histRows.first['weight_kg'] as num).toDouble();
          final pct = amrapPctByWeek[fromWeek] ?? 0.85;

          // Back-calculate the TM: find the 2.5kg-aligned value whose AMRAP
          // weight (ceil(TM*pct/2.5)*2.5) equals the logged weight.
          final approx = amrapWeight / pct;
          final minC = ((approx - 10.0) / 2.5).floor() * 2.5;
          final maxC = ((approx + 10.0) / 2.5).ceil() * 2.5;
          double tmBefore = approx; // fallback
          for (double c = minC; c <= maxC; c += 2.5) {
            if (c <= 0) continue;
            if (((c * pct / 2.5).ceil() * 2.5 - amrapWeight).abs() < 0.01) {
              tmBefore = c;
              break;
            }
          }

          // Re-apply the decision to get the correct new TM
          double newTm;
          if (decision == 'progress') {
            newTm = ((tmBefore + increment) / 2.5).ceil() * 2.5;
          } else if (decision == 'reduce') {
            newTm = ((tmBefore * 0.95) / 2.5).floor() * 2.5;
          } else {
            newTm = tmBefore; // hold
          }

          await db.update('training_maxes', {'value_kg': newTm},
              where: 'lift = ?', whereArgs: [lift]);
          // Also fix the stored tm_before so future edits use the correct baseline
          await db.update('week_transition_decisions', {'tm_before': tmBefore},
              where: 'id = ?', whereArgs: [decId]);
        }
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
  Future<void> upsertWeekTransitionDecision(int cycleId, int fromWeek, String lift,
      String decision, int severity, double tmBefore, String date) async {
    final db = await database;
    // Delete any existing decision for this cycle/week/lift first
    await db.delete(
      'week_transition_decisions',
      where: 'cycle_id = ? AND from_week = ? AND lift = ?',
      whereArgs: [cycleId, fromWeek, lift],
    );
    await db.insert('week_transition_decisions', {
      'cycle_id': cycleId,
      'from_week': fromWeek,
      'lift': lift,
      'decision': decision,
      'severity': severity,
      'tm_before': tmBefore,
      'date': date,
    });
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

  Future<Map<String, double>> getAllTransitionTmBeforeForCycle(int cycleId) async {
    final db = await database;
    final rows = await db.query(
      'week_transition_decisions',
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
    );
    final result = <String, double>{};
    for (final row in rows) {
      final key = '${row['from_week']}_${row['lift']}';
      result[key] = (row['tm_before'] as num).toDouble();
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
