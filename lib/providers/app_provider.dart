import 'dart:async';
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
  List<Map<String, dynamic>> _bodyweightEntries = [];
  // zone2 minutes per week cache: key = "cycleId_weekNum"
  final Map<String, int> _zone2Cache = {};
  // Joint log cache: key = "weekNum_liftKey" → severity (1-5), immediate post-workout only
  final Map<String, int> _immediateJointLogs = {};
  // Transition decision cache: key = "fromWeek_liftKey" → decision string
  final Map<String, String> _transitionDecisions = {};
  // TM before each transition decision: key = "fromWeek_liftKey" → tm value
  final Map<String, double> _transitionTmBefore = {};
  int _restTimerSeconds = 180;
  bool _isLoading = true;

  // Persistent rest timer
  Timer? _restTimer;
  bool _timerActive = false;
  int _timerRemaining = 0;
  int _timerDuration = 0;
  String _timerLiftName = '';
  String? _timerNextSet;

  // Per-lift week tracking: each lift tracks its own week (1-4)
  Map<String, int> _liftWeeks = {};

  Map<String, double> get trainingMaxes => _trainingMaxes;
  CycleModel? get currentCycle => _currentCycle;
  List<CycleModel> get allCycles => _allCycles;
  List<SessionModel> get currentSessions => _currentSessions;
  List<SetLogModel> get currentSetLogs => _currentSetLogs;
  List<SessionModel> get completedSessions => _completedSessions;
  List<HistoryEntry> get historyEntries => _historyEntries;
  List<Map<String, dynamic>> get bodyweightEntries => _bodyweightEntries;
  int get restTimerSeconds => _restTimerSeconds;
  bool get isLoading => _isLoading;
  Map<String, int> get liftWeeks => _liftWeeks;

  bool get timerActive => _timerActive;
  int get timerRemaining => _timerRemaining;
  int get timerDuration => _timerDuration;
  String get timerLiftName => _timerLiftName;
  String? get timerNextSet => _timerNextSet;

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
    await _loadBodyweightEntries();
    await _loadZone2Cache();
    await _loadJointCaches();

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

  Future<void> _loadBodyweightEntries() async {
    _bodyweightEntries = await _db.getBodyweightEntries();
  }

  Future<void> logBodyweight(String date, double kg) async {
    await _db.insertBodyweight(date, kg);
    await _loadBodyweightEntries();
    notifyListeners();
  }

  Future<void> logZone2(int cycleId, int weekNumber, int minutes) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db.insertZone2Log(cycleId, weekNumber, minutes, today);
    final key = '${cycleId}_$weekNumber';
    _zone2Cache[key] = (_zone2Cache[key] ?? 0) + minutes;
    notifyListeners();
  }

  int getZone2MinutesForWeek(int cycleId, int weekNumber) {
    return _zone2Cache['${cycleId}_$weekNumber'] ?? 0;
  }

  Future<void> _loadZone2Cache() async {
    _zone2Cache.clear();
    if (_currentCycle == null) return;
    for (int w = 1; w <= 4; w++) {
      final mins = await _db.getZone2MinutesForWeek(_currentCycle!.id!, w);
      if (mins > 0) _zone2Cache['${_currentCycle!.id!}_$w'] = mins;
    }
  }

  Future<void> _loadJointCaches() async {
    _immediateJointLogs.clear();
    _transitionDecisions.clear();
    _transitionTmBefore.clear();
    if (_currentCycle == null) return;
    final cycleId = _currentCycle!.id!;
    final joints = await _db.getAllImmediateJointLogsForCycle(cycleId);
    _immediateJointLogs.addAll(joints);
    final decisions = await _db.getAllTransitionDecisionsForCycle(cycleId);
    _transitionDecisions.addAll(decisions);
    final tmBefores = await _db.getAllTransitionTmBeforeForCycle(cycleId);
    _transitionTmBefore.addAll(tmBefores);
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

  // Joint feedback & week transition decisions
  Future<void> logImmediateJointFeedback(
      int cycleId, int week, LiftType lift, int severity) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await _db.insertJointLog(cycleId, week, lift.dbKey, severity, true, date);
    _immediateJointLogs['${week}_${lift.dbKey}'] = severity;
    notifyListeners();
  }

  int? getImmediateJointSeverity(int cycleId, int week, LiftType lift) {
    return _immediateJointLogs['${week}_${lift.dbKey}'];
  }

  bool hasWeekTransitionDecision(int cycleId, int fromWeek, LiftType lift) {
    return _transitionDecisions.containsKey('${fromWeek}_${lift.dbKey}');
  }

  String? getWeekTransitionDecision(int cycleId, int fromWeek, LiftType lift) {
    return _transitionDecisions['${fromWeek}_${lift.dbKey}'];
  }

  double? getTransitionTmBefore(int fromWeek, LiftType lift) {
    return _transitionTmBefore['${fromWeek}_${lift.dbKey}'];
  }

  bool isLiftCompleteForWeek(LiftType lift, int week) {
    return _currentSessions.any(
        (s) => s.week == week && s.isComplete && s.liftKeys.contains(lift.dbKey));
  }

  Future<void> commitWeekTransition(
      int cycleId, int fromWeek, LiftType lift, String decision, int severity) async {
    final key = '${fromWeek}_${lift.dbKey}';
    final date = DateTime.now().toIso8601String().substring(0, 10);

    // Determine the TM to use as baseline.
    // On first commit: use current TM (and store it as tm_before).
    // On edit: revert to the original tm_before, then apply new decision.
    final isEdit = _transitionDecisions.containsKey(key);
    final tmBefore = isEdit
        ? (_transitionTmBefore[key] ?? getTrainingMax(lift))
        : getTrainingMax(lift);

    await _db.upsertWeekTransitionDecision(
        cycleId, fromWeek, lift.dbKey, decision, severity, tmBefore, date);
    _transitionDecisions[key] = decision;
    _transitionTmBefore[key] = tmBefore;

    // Revert old TM change if editing, then apply new decision from tmBefore
    double newTm;
    if (decision == 'progress') {
      newTm = WendlerCalculator.roundToNearest2_5(tmBefore + lift.tmIncrement);
    } else if (decision == 'reduce') {
      newTm = WendlerCalculator.roundToNearest2_5(tmBefore * 0.95);
    } else {
      newTm = tmBefore; // hold
    }

    await updateTrainingMax(lift, newTm);
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

  // Insert history entries directly (from workout screen log)
  Future<void> importHistoryEntriesDirect(List<HistoryEntry> entries) async {
    for (final entry in entries) {
      await _db.insertHistoryEntry(entry);
    }
    await _loadHistory();
    notifyListeners();
  }

  /// Called from WorkoutScreen Log Score. Saves history entry + marks session complete.
  Future<void> logScoreAndComplete(
      LiftType liftType, int week, int cycleId, double amrapWeight, int reps,
      {String notes = ''}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Find an existing incomplete session for this cycle+week+lift
    final allSessions = await _db.getSessionsForCycle(cycleId);
    SessionModel? session;
    try {
      session = allSessions.firstWhere(
        (s) => s.week == week && s.liftKeys.contains(liftType.dbKey) && !s.isComplete,
      );
    } catch (_) {
      session = null;
    }

    // If no session exists, create a minimal one for this lift
    if (session == null) {
      final sessionId = await _db.insertSession(SessionModel(
        cycleId: cycleId,
        week: week,
        lifts: liftType.dbKey,
        date: today,
      ));
      session = SessionModel(
        id: sessionId,
        cycleId: cycleId,
        week: week,
        lifts: liftType.dbKey,
        date: today,
      );
    }

    // Insert history entry (not imported — so beat-last hint picks it up)
    final oneRm = WendlerCalculator.calcEpley1RM(amrapWeight, reps);
    await _db.insertHistoryEntry(HistoryEntry(
      date: today,
      lift: liftType.dbKey,
      weightKg: amrapWeight,
      reps: reps,
      oneRm: oneRm,
      notes: notes,
      isImported: false,
    ));
    await _loadHistory();

    // Mark session complete
    final updated = session.copyWith(isComplete: true);
    await _db.updateSession(updated);

    // Advance week for this lift only
    final nextWeek = _nextWeekFor(liftType.dbKey);
    await _db.setLiftWeek(liftType.dbKey, nextWeek);
    _liftWeeks[liftType.dbKey] = nextWeek;

    if (_currentCycle != null) {
      await _loadSessionsForCycle(_currentCycle!.id!);
    }
    await _loadAllCycles();
    await _loadCompletedSessions();
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
    // 4 lifts × 4 weeks = 16 sessions per full cycle
    const expected = 16;
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

  // Delete a single completed session (and its history entries)
  Future<void> deleteSessionById(SessionModel session) async {
    await _db.deleteSessionById(session.id!, session.date, session.liftKeys);
    if (_currentCycle != null) {
      await _loadSessionsForCycle(_currentCycle!.id!);
    }
    await _loadCompletedSessions();
    await _loadHistory();
    notifyListeners();
  }

  // Delete a cycle
  Future<void> deleteCycleById(int cycleId) async {
    await _db.deleteCycle(cycleId);
    if (_currentCycle?.id == cycleId) {
      _currentCycle = null;
      _currentSessions = [];
      _currentSetLogs = [];
      // Do NOT call _loadCurrentCycle here — that auto-creates a new cycle.
      // Just reload the full list; home screen handles empty state.
    }
    await _loadAllCycles();
    // If there are remaining cycles, set the most recent as current
    if (_allCycles.isNotEmpty && _currentCycle == null) {
      _currentCycle = _allCycles.first;
      await _loadSessionsForCycle(_currentCycle!.id!);
    }
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

  // Week % complete: 4 lifts only (25% each). Zone 2 is tracked but not counted.
  int getWeekPercentComplete(int week) {
    final sessions = getSessionsForWeek(week);
    final liftsCompleted = sessions.where((s) => s.isComplete).length.clamp(0, 4);
    return ((liftsCompleted / 4) * 100).clamp(0, 100).round();
  }

  // Persistent rest timer
  void startRestTimer(String liftName, String? nextSet) {
    _restTimer?.cancel();
    _timerActive = true;
    _timerDuration = _restTimerSeconds;
    _timerRemaining = _restTimerSeconds;
    _timerLiftName = liftName;
    _timerNextSet = nextSet;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerRemaining <= 1) {
        timer.cancel();
        _timerActive = false;
        _timerRemaining = 0;
        notifyListeners();
      } else {
        _timerRemaining--;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void stopRestTimer() {
    _restTimer?.cancel();
    _timerActive = false;
    notifyListeners();
  }

  // Fetch set logs for any session (including completed ones from past cycles)
  Future<List<SetLogModel>> fetchSetLogsForCompletedSession(int sessionId) async {
    return await _db.getSetLogsForSession(sessionId);
  }

  // Reload everything
  Future<void> reload() async {
    await _loadTrainingMaxes();
    await _loadCurrentCycle();
    await _loadAllCycles();
    await _loadCompletedSessions();
    await _loadHistory();
    await _loadLiftWeeks();
    await _loadBodyweightEntries();
    await _loadJointCaches();
    notifyListeners();
  }
}
