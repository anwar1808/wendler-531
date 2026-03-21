import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/lift_type.dart';
import '../models/training_max.dart';
import '../models/cycle_model.dart';
import '../models/session_model.dart';
import '../models/set_log_model.dart';
import '../models/history_entry.dart';
import '../services/wendler_calculator.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Map<String, double> _trainingMaxes = {};
  CycleModel? _currentCycle;
  List<SessionModel> _currentSessions = [];
  List<SetLogModel> _currentSetLogs = [];
  List<SessionModel> _completedSessions = [];
  List<HistoryEntry> _historyEntries = [];
  int _restTimerSeconds = 180;
  bool _isLoading = true;

  Map<String, double> get trainingMaxes => _trainingMaxes;
  CycleModel? get currentCycle => _currentCycle;
  List<SessionModel> get currentSessions => _currentSessions;
  List<SetLogModel> get currentSetLogs => _currentSetLogs;
  List<SessionModel> get completedSessions => _completedSessions;
  List<HistoryEntry> get historyEntries => _historyEntries;
  int get restTimerSeconds => _restTimerSeconds;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _restTimerSeconds = prefs.getInt('rest_timer_seconds') ?? 180;

    await _loadTrainingMaxes();
    await _ensureDefaultTrainingMaxes();
    await _loadCurrentCycle();
    await _loadCompletedSessions();
    await _loadHistory();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadTrainingMaxes() async {
    final tms = await _db.getAllTrainingMaxes();
    _trainingMaxes = {for (final tm in tms) tm.lift: tm.valueKg};
  }

  Future<void> _ensureDefaultTrainingMaxes() async {
    for (final lift in LiftType.values) {
      if (!_trainingMaxes.containsKey(lift.dbKey)) {
        final defaultTm = lift.isLower ? 100.0 : 60.0;
        await _db.upsertTrainingMax(TrainingMax(
          lift: lift.dbKey,
          valueKg: defaultTm,
          updatedAt: DateTime.now().toIso8601String(),
        ));
        _trainingMaxes[lift.dbKey] = defaultTm;
      }
    }
  }

  Future<void> _loadCurrentCycle() async {
    _currentCycle = await _db.getCurrentCycle();
    if (_currentCycle == null) {
      await _createNewCycle(1);
    } else {
      await _loadSessionsForCycle(_currentCycle!.id!);
    }
  }

  Future<void> _createNewCycle(int number) async {
    final cycleId = await _db.insertCycle(CycleModel(
      number: number,
      startDate: DateTime.now().toIso8601String().substring(0, 10),
    ));
    _currentCycle = CycleModel(
      id: cycleId,
      number: number,
      startDate: DateTime.now().toIso8601String().substring(0, 10),
    );
    await _createSessionsForCycle(cycleId);
    await _loadSessionsForCycle(cycleId);
  }

  Future<void> _createSessionsForCycle(int cycleId) async {
    for (int week = 1; week <= 4; week++) {
      for (final type in ['mon', 'thu']) {
        await _db.insertSession(SessionModel(
          cycleId: cycleId,
          week: week,
          sessionType: type,
          date: '',
        ));
      }
    }
  }

  Future<void> _loadSessionsForCycle(int cycleId) async {
    _currentSessions = await _db.getSessionsForCycle(cycleId);
    _currentSetLogs = [];
    for (final session in _currentSessions) {
      if (session.id != null) {
        final logs = await _db.getSetLogsForSession(session.id!);
        _currentSetLogs.addAll(logs);
      }
    }
  }

  Future<void> _loadCompletedSessions() async {
    _completedSessions = await _db.getAllCompletedSessions();
  }

  Future<void> _loadHistory() async {
    _historyEntries = await _db.getAllHistoryEntries();
  }

  // Determine which week is current (first incomplete week)
  int get currentWeek {
    final incompleteSessions = _currentSessions.where((s) => !s.isComplete).toList();
    if (incompleteSessions.isEmpty) return 4;
    return incompleteSessions.first.week;
  }

  // Get sessions for a specific week
  List<SessionModel> getSessionsForWeek(int week) {
    return _currentSessions.where((s) => s.week == week).toList();
  }

  // Get set logs for a session
  List<SetLogModel> getSetLogsForSession(int sessionId) {
    return _currentSetLogs.where((s) => s.sessionId == sessionId).toList();
  }

  // Training max accessors
  double getTrainingMax(LiftType lift) {
    return _trainingMaxes[lift.dbKey] ?? (lift.isLower ? 100.0 : 60.0);
  }

  Future<void> updateTrainingMax(LiftType lift, double value) async {
    final tm = TrainingMax(
      lift: lift.dbKey,
      valueKg: value,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await _db.upsertTrainingMax(tm);
    _trainingMaxes[lift.dbKey] = value;
    notifyListeners();
  }

  // Session management
  Future<void> startSession(SessionModel session) async {
    final now = DateTime.now().toIso8601String().substring(0, 10);
    final updated = session.copyWith(date: now);
    await _db.updateSession(updated);

    // Create set logs if not yet created
    final existingLogs = await _db.getSetLogsForSession(session.id!);
    if (existingLogs.isEmpty) {
      await _generateSetLogs(session);
    }

    await _loadSessionsForCycle(_currentCycle!.id!);
    notifyListeners();
  }

  Future<void> _generateSetLogs(SessionModel session) async {
    final liftKeys = session.liftKeys;
    for (final liftKey in liftKeys) {
      final lift = LiftTypeExtension.fromDbKey(liftKey);
      if (lift == null) continue;
      final tm = getTrainingMax(lift);
      final sets = WendlerCalculator.getSetsForWeek(session.week, tm);
      for (int i = 0; i < sets.length; i++) {
        final s = sets[i];
        await _db.insertSetLog(SetLogModel(
          sessionId: session.id!,
          lift: liftKey,
          setNumber: i + 1,
          prescribedWeight: s.weight,
          prescribedReps: s.reps,
          isAmrap: s.isAmrap,
        ));
      }
    }
  }

  Future<void> completeSet(SetLogModel setLog, {int? actualReps}) async {
    final updated = setLog.copyWith(isComplete: true, actualReps: actualReps ?? setLog.actualReps);
    await _db.updateSetLog(updated);

    // Update in local list
    final idx = _currentSetLogs.indexWhere((s) => s.id == setLog.id);
    if (idx >= 0) _currentSetLogs[idx] = updated;

    // If AMRAP, log history entry
    if (setLog.isAmrap && actualReps != null && actualReps > 0) {
      final oneRm = WendlerCalculator.calcEpley1RM(setLog.prescribedWeight, actualReps);
      final session = _currentSessions.firstWhere((s) => s.id == setLog.sessionId);
      await _db.insertHistoryEntry(HistoryEntry(
        date: session.date.isNotEmpty
            ? session.date
            : DateTime.now().toIso8601String().substring(0, 10),
        lift: setLog.lift,
        weightKg: setLog.prescribedWeight,
        reps: actualReps,
        oneRm: oneRm,
        isImported: false,
      ));
      await _loadHistory();
    }

    notifyListeners();
  }

  Future<void> uncompleteSet(SetLogModel setLog) async {
    final updated = setLog.copyWith(isComplete: false);
    await _db.updateSetLog(updated);
    final idx = _currentSetLogs.indexWhere((s) => s.id == setLog.id);
    if (idx >= 0) _currentSetLogs[idx] = updated;
    notifyListeners();
  }

  Future<void> finishSession(SessionModel session, String notes) async {
    final updated = session.copyWith(notes: notes, isComplete: true);
    await _db.updateSession(updated);
    await _loadSessionsForCycle(_currentCycle!.id!);
    await _loadCompletedSessions();
    notifyListeners();
  }

  Future<void> updateSessionNotes(SessionModel session, String notes) async {
    final updated = session.copyWith(notes: notes);
    await _db.updateSession(updated);
    final idx = _currentSessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) _currentSessions[idx] = updated;
    notifyListeners();
  }

  // Complete cycle: mark complete, increment TMs, create next cycle
  Future<void> completeCycle() async {
    if (_currentCycle == null) return;

    // Increment TMs
    for (final lift in LiftType.values) {
      final current = getTrainingMax(lift);
      final newTm = WendlerCalculator.incrementTm(lift, current);
      await updateTrainingMax(lift, newTm);
    }

    await _db.completeCycle(_currentCycle!.id!);
    final nextNumber = _currentCycle!.number + 1;
    await _createNewCycle(nextNumber);

    notifyListeners();
  }

  bool get allSessionsComplete {
    return _currentSessions.isNotEmpty && _currentSessions.every((s) => s.isComplete);
  }

  // Settings
  Future<void> setRestTimerSeconds(int seconds) async {
    _restTimerSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rest_timer_seconds', seconds);
    notifyListeners();
  }

  // Import
  Future<void> importHistoryEntries(List<HistoryEntry> entries) async {
    await _db.clearImportedHistory();
    for (final entry in entries) {
      await _db.insertHistoryEntry(entry);
    }

    // Update TMs based on most recent 1RM per lift
    for (final lift in LiftType.values) {
      final latest = await _db.getLatestHistoryForLift(lift.dbKey);
      if (latest != null) {
        final newTm = WendlerCalculator.calcTrainingMax(latest.oneRm);
        await updateTrainingMax(lift, newTm);
      }
    }

    await _loadHistory();
    notifyListeners();
  }

  // Progress data
  List<HistoryEntry> getHistoryForLift(LiftType lift) {
    return _historyEntries
        .where((e) => e.lift == lift.dbKey)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // Reload everything
  Future<void> reload() async {
    await _loadTrainingMaxes();
    await _loadCurrentCycle();
    await _loadCompletedSessions();
    await _loadHistory();
    notifyListeners();
  }
}
