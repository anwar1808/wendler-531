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
  List<CycleModel> _allCycles = [];
  // All sessions for the current cycle (completed ones for context)
  List<SessionModel> _currentSessions = [];
  List<SetLogModel> _currentSetLogs = [];
  List<SessionModel> _completedSessions = [];
  List<HistoryEntry> _historyEntries = [];
  int _restTimerSeconds = 180;
  bool _isLoading = true;

  // Per-lift week tracking: each lift tracks its own week (1-4)
  Map<String, int> _liftWeeks = {};

  Map<String, double> get trainingMaxes => _trainingMaxes;
  CycleModel? get currentCycle => _currentCycle;
  List<CycleModel> get allCycles => _allCycles;
  List<SessionModel> get currentSessions => _currentSessions;
  List<SetLogModel> get currentSetLogs => _currentSetLogs;
  List<SessionModel> get completedSessions => _completedSessions;
  List<HistoryEntry> get historyEntries => _historyEntries;
  int get restTimerSeconds => _restTimerSeconds;
  bool get isLoading => _isLoading;
  Map<String, int> get liftWeeks => _liftWeeks;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _restTimerSeconds = prefs.getInt('rest_timer_seconds') ?? 180;

    await _loadTrainingMaxes();
    await _ensureDefaultTrainingMaxes();
    await _loadCurrentCycle();
    await _loadAllCycles();
    await _loadCompletedSessions();
    await _loadHistory();
    await _loadLiftWeeks();

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
    // No pre-created sessions — sessions are created on demand
    await _loadSessionsForCycle(cycleId);
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

  Future<void> _loadLiftWeeks() async {
    _liftWeeks = await _db.getAllLiftWeeks();
    // Ensure all lifts have an entry
    for (final lift in LiftType.values) {
      _liftWeeks.putIfAbsent(lift.dbKey, () => 1);
    }
  }

  Future<void> _loadAllCycles() async {
    _allCycles = await _db.getAllCycles();
    // Sort newest first
    _allCycles = _allCycles.reversed.toList();
  }

  Future<void> _loadCompletedSessions() async {
    _completedSessions = await _db.getAllCompletedSessions();
  }

  Future<void> _loadHistory() async {
    _historyEntries = await _db.getAllHistoryEntries();
  }

  // Get current week for a specific lift
  int getLiftWeek(LiftType lift) {
    return _liftWeeks[lift.dbKey] ?? 1;
  }

  // Get next week for a lift (cycles 1->2->3->4->1)
  int _nextWeekFor(String liftKey) {
    final current = _liftWeeks[liftKey] ?? 1;
    return current == 4 ? 1 : current + 1;
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

  // Session management — create a new ad-hoc session with the chosen lifts
  Future<SessionModel> createAndStartSession(List<LiftType> lifts) async {
    if (_currentCycle == null) {
      await _createNewCycle(1);
    }

    // For the week, use the week of the FIRST lift in the selection
    // (each lift tracks its own week independently)
    final firstLiftWeek = getLiftWeek(lifts.first);

    final liftString = lifts.map((l) => l.dbKey).join(',');
    final now = DateTime.now().toIso8601String().substring(0, 10);

    final sessionId = await _db.insertSession(SessionModel(
      cycleId: _currentCycle!.id!,
      week: firstLiftWeek,
      lifts: liftString,
      date: now,
    ));

    final session = SessionModel(
      id: sessionId,
      cycleId: _currentCycle!.id!,
      week: firstLiftWeek,
      lifts: liftString,
      date: now,
    );

    // Generate set logs per lift using that lift's own week
    await _generateSetLogsForSession(session, lifts);

    await _loadSessionsForCycle(_currentCycle!.id!);
    notifyListeners();
    return session;
  }

  Future<void> _generateSetLogsForSession(
    SessionModel session,
    List<LiftType> lifts,
  ) async {
    for (final lift in lifts) {
      final week = getLiftWeek(lift);
      final tm = getTrainingMax(lift);
      final sets = WendlerCalculator.getSetsForWeek(week, tm);
      for (int i = 0; i < sets.length; i++) {
        final s = sets[i];
        await _db.insertSetLog(SetLogModel(
          sessionId: session.id!,
          lift: lift.dbKey,
          setNumber: i + 1,
          prescribedWeight: s.weight,
          prescribedReps: s.reps,
          isAmrap: s.isAmrap,
        ));
      }
    }
  }

  // Get set logs for a session from the in-memory cache, or load fresh
  List<SetLogModel> getSetLogsForSession(int sessionId) {
    return _currentSetLogs.where((s) => s.sessionId == sessionId).toList();
  }

  Future<void> refreshSetLogsForSession(int sessionId) async {
    final logs = await _db.getSetLogsForSession(sessionId);
    _currentSetLogs.removeWhere((s) => s.sessionId == sessionId);
    _currentSetLogs.addAll(logs);
    notifyListeners();
  }

  Future<void> completeSet(SetLogModel setLog, {int? actualReps}) async {
    final updated = setLog.copyWith(isComplete: true, actualReps: actualReps ?? setLog.actualReps);
    await _db.updateSetLog(updated);

    final idx = _currentSetLogs.indexWhere((s) => s.id == setLog.id);
    if (idx >= 0) _currentSetLogs[idx] = updated;

    // If AMRAP, log history entry
    if (setLog.isAmrap && actualReps != null && actualReps > 0) {
      final oneRm = WendlerCalculator.calcEpley1RM(setLog.prescribedWeight, actualReps);
      final session = _currentSessions.firstWhere((s) => s.id == setLog.sessionId,
          orElse: () => _currentSessions.first);
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

    // Advance the week for each lift in this session
    for (final liftKey in session.liftKeys) {
      final nextWeek = _nextWeekFor(liftKey);
      await _db.setLiftWeek(liftKey, nextWeek);
      _liftWeeks[liftKey] = nextWeek;
    }

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

  // 1RM summary data for a lift
  ({double? recentMin, double? recentMax, String? recentDateRange, double? allTimePeak, String? peakDate})
      get1RMSummary(LiftType lift) {
    final entries = getHistoryForLift(lift);
    if (entries.isEmpty) {
      return (recentMin: null, recentMax: null, recentDateRange: null, allTimePeak: null, peakDate: null);
    }

    // All-time peak
    double allTimePeak = 0;
    String peakDate = '';
    for (final e in entries) {
      if (e.oneRm > allTimePeak) {
        allTimePeak = e.oneRm;
        peakDate = e.date;
      }
    }

    // Recent = last 6 months or last 5 entries, whichever is more
    final now = DateTime.now();
    final sixMonthsAgo = now.subtract(const Duration(days: 180));
    final recent = entries.where((e) {
      final dt = DateTime.tryParse(e.date);
      if (dt == null) return false;
      return dt.isAfter(sixMonthsAgo);
    }).toList();

    final recentList = recent.isNotEmpty ? recent : entries.reversed.take(5).toList().reversed.toList();

    double recentMin = double.infinity;
    double recentMax = double.negativeInfinity;
    String firstDate = '';
    String lastDate = '';
    for (final e in recentList) {
      if (e.oneRm < recentMin) recentMin = e.oneRm;
      if (e.oneRm > recentMax) recentMax = e.oneRm;
      if (firstDate.isEmpty || e.date.compareTo(firstDate) < 0) firstDate = e.date;
      if (lastDate.isEmpty || e.date.compareTo(lastDate) > 0) lastDate = e.date;
    }

    String dateRange = _formatDateRange(firstDate, lastDate);

    return (
      recentMin: recentMin,
      recentMax: recentMax,
      recentDateRange: dateRange,
      allTimePeak: allTimePeak,
      peakDate: _formatMonthYear(peakDate),
    );
  }

  String _formatMonthYear(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateRange(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final sLabel = '${months[s.month - 1]} ${s.year}';
      final eLabel = '${months[e.month - 1]} ${e.year}';
      if (sLabel == eLabel) return sLabel;
      if (s.year == e.year) return '${months[s.month - 1]}–${months[e.month - 1]} ${e.year}';
      return '$sLabel–$eLabel';
    } catch (_) {
      return '';
    }
  }

  // Get sessions for any cycle
  Future<List<SessionModel>> getSessionsForCycle(int cycleId) async {
    return await _db.getSessionsForCycle(cycleId);
  }

  // Cycle % complete: sessions done / (4 sessions expected)
  int getCyclePercentComplete(CycleModel cycle) {
    if (cycle.id == null) return 0;
    final sessions = _currentCycle?.id == cycle.id
        ? _currentSessions
        : <SessionModel>[];
    final completed = sessions.where((s) => s.isComplete).length;
    // 4 weeks × 1 session each = 4 expected minimum
    const expected = 4;
    if (expected == 0) return 0;
    return ((completed / expected) * 100).clamp(0, 100).round();
  }

  // Create a brand new cycle (called from home FAB)
  Future<CycleModel> startNewCycle() async {
    // Mark old cycle complete if exists
    if (_currentCycle != null && !_currentCycle!.isComplete) {
      await _db.completeCycle(_currentCycle!.id!);
    }
    final nextNumber = (_allCycles.isEmpty ? 0 : _allCycles.map((c) => c.number).reduce((a, b) => a > b ? a : b)) + 1;
    await _createNewCycle(nextNumber);
    await _loadAllCycles();
    notifyListeners();
    return _currentCycle!;
  }

  // Delete a cycle
  Future<void> deleteCycleById(int cycleId) async {
    await _db.deleteCycle(cycleId);
    if (_currentCycle?.id == cycleId) {
      _currentCycle = null;
      _currentSessions = [];
      _currentSetLogs = [];
      await _loadCurrentCycle();
    }
    await _loadAllCycles();
    notifyListeners();
  }

  // Update cycle start date
  Future<void> updateCycleStartDate(int cycleId, String startDate) async {
    await _db.updateCycleStartDate(cycleId, startDate);
    await _loadAllCycles();
    if (_currentCycle?.id == cycleId) {
      _currentCycle = CycleModel(
        id: _currentCycle!.id,
        number: _currentCycle!.number,
        startDate: startDate,
        isComplete: _currentCycle!.isComplete,
      );
    }
    notifyListeners();
  }

  // Get sessions for a specific week in the current cycle
  List<SessionModel> getSessionsForWeek(int week) {
    return _currentSessions.where((s) => s.week == week).toList();
  }

  // Week % complete: sessions done in that week / lifts in cycle
  int getWeekPercentComplete(int week) {
    final sessions = getSessionsForWeek(week);
    if (sessions.isEmpty) return 0;
    final completed = sessions.where((s) => s.isComplete).length;
    return ((completed / sessions.length) * 100).clamp(0, 100).round();
  }

  // Reload everything
  Future<void> reload() async {
    await _loadTrainingMaxes();
    await _loadCurrentCycle();
    await _loadAllCycles();
    await _loadCompletedSessions();
    await _loadHistory();
    await _loadLiftWeeks();
    notifyListeners();
  }
}
