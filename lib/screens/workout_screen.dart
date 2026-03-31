import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/lift_type.dart';
import '../models/history_entry.dart';
import '../providers/app_provider.dart';
import '../services/wendler_calculator.dart';
import '../services/plate_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/rest_timer_widget.dart';

class WorkoutScreen extends StatefulWidget {
  final LiftType liftType;
  final int week;
  final int cycleId;
  final bool isAlreadyComplete;

  const WorkoutScreen({
    super.key,
    required this.liftType,
    required this.week,
    required this.cycleId,
    this.isAlreadyComplete = false,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  // Track which items are checked off
  final Set<int> _checkedItems = {};
  bool _initialized = false;

  // Step indices
  static const int _idxWarmup = 0;
  static const int _idxSet1 = 1;
  static const int _idxRest1 = 2;
  static const int _idxSet2 = 3;
  static const int _idxRest2 = 4;
  static const int _idxAmrap = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (widget.isAlreadyComplete) {
        _checkedItems.addAll(
            {_idxWarmup, _idxSet1, _idxRest1, _idxSet2, _idxRest2, _idxAmrap});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final tm = provider.getTrainingMax(widget.liftType);
    final allTimeRecord = _getAllTimePR(provider);
    final lastSessionEntry = _getLastSessionEntry(provider);

    // Calculate weights
    final warmupSets = _getWarmupSets(tm);
    final workSets = _getWorkSets(tm, widget.week);
    final amrapWeight = workSets.isNotEmpty ? workSets.last.weight : 0.0;
    final prHint = _calcPrHint(amrapWeight, allTimeRecord);
    final beatLastHint = _calcBeatLastHint(amrapWeight, lastSessionEntry);

    final dateLabel = DateFormat('d MMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        title: const Text(
          'Workout',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    children: [
                      // Joint transition banner (weeks 2–4)
                      if (widget.week > 1 &&
                          provider.isLiftCompleteForWeek(widget.liftType, widget.week - 1))
                        _JointTransitionBanner(
                          liftType: widget.liftType,
                          cycleId: widget.cycleId,
                          fromWeek: widget.week - 1,
                          provider: provider,
                        ),
                      Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Lift name + TM
                          Text(
                            widget.liftType.displayName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${WendlerCalculator.formatWeight(tm)} working weight',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Warmup row
                          _CheckRow(
                            index: _idxWarmup,
                            checked: _checkedItems.contains(_idxWarmup),
                            onToggle: () => _toggle(_idxWarmup),
                            title: 'Warmup',
                            subtitle: warmupSets
                                .map((s) =>
                                    '${WendlerCalculator.formatWeight(s.weight)} × ${s.reps}')
                                .join(', '),
                          ),
                          const Divider(height: 20),

                          // Set 1
                          if (workSets.isNotEmpty) ...[
                            _CheckRow(
                              index: _idxSet1,
                              checked: _checkedItems.contains(_idxSet1),
                              onToggle: () => _toggle(_idxSet1),
                              title:
                                  '${workSets[0].reps} reps at ${WendlerCalculator.formatWeight(workSets[0].weight)}',
                              subtitle: _setSubtitle(widget.week, 1),
                              plateInfo: PlateCalculator.formatPlates(workSets[0].weight),
                            ),
                            const SizedBox(height: 8),

                            // Rest 1
                            _CheckRow(
                              index: _idxRest1,
                              checked: _checkedItems.contains(_idxRest1),
                              onToggle: () => _toggleRest(_idxRest1),
                              title: 'Rest',
                              subtitle: 'Press to start rest timer',
                              isRest: true,
                            ),
                            const Divider(height: 20),
                          ],

                          // Set 2
                          if (workSets.length >= 2) ...[
                            _CheckRow(
                              index: _idxSet2,
                              checked: _checkedItems.contains(_idxSet2),
                              onToggle: () => _toggle(_idxSet2),
                              title:
                                  '${workSets[1].reps} reps at ${WendlerCalculator.formatWeight(workSets[1].weight)}',
                              subtitle: _setSubtitle(widget.week, 2),
                              plateInfo: PlateCalculator.formatPlates(workSets[1].weight),
                            ),
                            const SizedBox(height: 8),

                            // Rest 2
                            _CheckRow(
                              index: _idxRest2,
                              checked: _checkedItems.contains(_idxRest2),
                              onToggle: () => _toggleRest(_idxRest2),
                              title: 'Rest',
                              subtitle: 'Press to start rest timer',
                              isRest: true,
                            ),
                            const Divider(height: 20),
                          ],

                          // AMRAP set
                          if (workSets.length >= 3) ...[
                            _CheckRow(
                              index: _idxAmrap,
                              checked: _checkedItems.contains(_idxAmrap),
                              onToggle: () => _toggle(_idxAmrap),
                              title:
                                  'AMRAP at ${WendlerCalculator.formatWeight(amrapWeight)}',
                              subtitle: _amrapSubtitle(widget.week),
                              plateInfo: PlateCalculator.formatPlates(amrapWeight),
                              prHint: prHint,
                              beatLastHint: beatLastHint,
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Date + help row
                          Row(
                            children: [
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _showHelpDialog(context),
                                icon: const Icon(Icons.help_outline, size: 15),
                                label: const Text('Help'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.textSecondary,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),

                          // Session notes (shown when this workout has been logged)
                          if (widget.isAlreadyComplete && lastSessionEntry != null && lastSessionEntry.notes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'NOTES',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    lastSessionEntry.notes,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Rest timer overlay (driven by provider — persists across navigation)
          if (provider.timerActive)
            Positioned(
              bottom: 72,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: RestTimerWidget(
                  durationSeconds: provider.timerDuration,
                  remaining: provider.timerRemaining,
                  liftName: provider.timerLiftName,
                  nextSetInfo: provider.timerNextSet,
                  onDone: provider.stopRestTimer,
                  onSkip: provider.stopRestTimer,
                ),
              ),
            ),

          // Log Score button — pinned bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showLogScoreDialog(
                        context, provider, amrapWeight),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    child: const Text('Log Score'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(int idx) {
    setState(() {
      if (_checkedItems.contains(idx)) {
        _checkedItems.remove(idx);
      } else {
        _checkedItems.add(idx);
      }
    });
  }

  void _toggleRest(int idx) {
    final provider = context.read<AppProvider>();
    setState(() {
      if (_checkedItems.contains(idx)) {
        _checkedItems.remove(idx);
        provider.stopRestTimer();
      } else {
        _checkedItems.add(idx);
        provider.startRestTimer(widget.liftType.displayName, null);
      }
    });
  }

  List<WendlerSet> _getWarmupSets(double tm) {
    return [
      WendlerSet(
          weight: WendlerCalculator.roundToNearest2_5(tm * 0.40), reps: 5),
      WendlerSet(
          weight: WendlerCalculator.roundToNearest2_5(tm * 0.50), reps: 5),
      WendlerSet(
          weight: WendlerCalculator.roundToNearest2_5(tm * 0.60), reps: 5),
    ];
  }

  List<WendlerSet> _getWorkSets(double tm, int week) {
    return WendlerCalculator.getSetsForWeek(week, tm);
  }

  String _setSubtitle(int week, int setNum) {
    switch (week) {
      case 1:
        return setNum == 1 ? '65% of working weight' : '75% of working weight';
      case 2:
        return setNum == 1 ? '70% of working weight' : '80% of working weight';
      case 3:
        return setNum == 1 ? '75% of working weight' : '85% of working weight';
      case 4:
        return setNum == 1 ? '40% of working weight' : '50% of working weight';
      default:
        return '';
    }
  }

  String _amrapSubtitle(int week) {
    switch (week) {
      case 1:
        return '85% of working weight';
      case 2:
        return '90% of working weight';
      case 3:
        return '95% of working weight';
      case 4:
        return '60% of working weight';
      default:
        return '';
    }
  }

  double? _getAllTimePR(AppProvider provider) {
    final history = provider.getHistoryForLift(widget.liftType);
    if (history.isEmpty) return null;
    return history.map((e) => e.oneRm).reduce(max);
  }

  HistoryEntry? _getLastSessionEntry(AppProvider provider) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final history = provider.getHistoryForLift(widget.liftType);
    // Only entries logged through the app (not seeded historical data), before today
    final past = history
        .where((e) => !e.isImported && e.date.compareTo(today) <= 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return past.isEmpty ? null : past.first;
  }

  String? _calcBeatLastHint(double amrapWeight, HistoryEntry? last) {
    if (last == null || amrapWeight <= 0) return null;
    final lastOneRm = last.oneRm;
    // How many reps at amrapWeight needed to beat lastOneRm?
    if (amrapWeight * (1 + 1 / 30.0) <= lastOneRm) {
      final repsNeeded = ((lastOneRm / amrapWeight - 1) * 30).ceil() + 1;
      if (repsNeeded < 1) return null;
      return '$repsNeeded reps beats last session (${lastOneRm.toStringAsFixed(1)} kg 1RM)';
    }
    return '1 rep beats last session (${lastOneRm.toStringAsFixed(1)} kg 1RM)';
  }

  String? _calcPrHint(double amrapWeight, double? allTimePR) {
    if (allTimePR == null || amrapWeight <= 0) return null;
    if (amrapWeight * (1 + 1 / 30.0) <= allTimePR) {
      // Calculate how many reps at amrapWeight beats allTimePR
      final repsNeeded = ((allTimePR / amrapWeight - 1) * 30).ceil() + 1;
      if (repsNeeded < 1) return null;
      final newPR = amrapWeight * (1 + repsNeeded / 30.0);
      return '$repsNeeded reps is a 1RM PR of ${newPR.toStringAsFixed(1)} kg';
    }
    // Even 1 rep is a PR
    final newPR = amrapWeight * (1 + 1 / 30.0);
    return '1 rep is a 1RM PR of ${newPR.toStringAsFixed(1)} kg';
  }

  void _showLogScoreDialog(
      BuildContext context, AppProvider provider, double amrapWeight) {
    final repsController = TextEditingController();
    final notesController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Score — ${widget.liftType.displayName}',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How many reps did you complete on the AMRAP set?',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              keyboardType: TextInputType.multiline,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Notes (optional) — how did it feel?',
                hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reps = int.tryParse(repsController.text);
              if (reps != null && reps > 0) {
                await provider.logScoreAndComplete(
                  widget.liftType,
                  widget.week,
                  widget.cycleId,
                  amrapWeight,
                  reps,
                  notes: notesController.text.trim(),
                );
                final oneRm = WendlerCalculator.calcEpley1RM(amrapWeight, reps);
                if (ctx.mounted) {
                  Navigator.pop(ctx); // close score dialog
                }
                if (context.mounted) {
                  await _showJointCheckInDialog(context, provider);
                }
                if (context.mounted) {
                  Navigator.of(context).pop(); // return to week screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Logged! Est. 1RM: ${oneRm.round()} kg',
                      ),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJointCheckInDialog(
      BuildContext context, AppProvider provider) async {
    int selectedSeverity = 1;
    const labels = ['None', 'Slight', 'Mild', 'Moderate', 'Painful'];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Joint Check-In',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How do your joints feel after ${widget.liftType.displayName}?',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...List.generate(5, (i) {
                final severity = i + 1;
                final selected = selectedSeverity == severity;
                return InkWell(
                  onTap: () => setDialogState(() => selectedSeverity = severity),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: severity,
                          groupValue: selectedSeverity,
                          onChanged: (v) =>
                              setDialogState(() => selectedSeverity = v!),
                          activeColor: AppTheme.accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$severity — ${labels[i]}',
                          style: TextStyle(
                            color: selected
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 15,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () async {
                await provider.logImmediateJointFeedback(
                    widget.cycleId, widget.week, widget.liftType, selectedSeverity);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'How to use',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Tick each step as you complete it.\n\n'
          'Tapping "Rest" starts the rest timer.\n\n'
          'The AMRAP set is your max reps set — push as hard as safely possible.\n\n'
          'Tap "Log Score" when done to record your reps and calculate your estimated 1RM.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Joint transition banner — persistent until user commits a decision
// ---------------------------------------------------------------------------

class _JointTransitionBanner extends StatefulWidget {
  final LiftType liftType;
  final int cycleId;
  final int fromWeek;
  final AppProvider provider;

  const _JointTransitionBanner({
    required this.liftType,
    required this.cycleId,
    required this.fromWeek,
    required this.provider,
  });

  @override
  State<_JointTransitionBanner> createState() => _JointTransitionBannerState();
}

class _JointTransitionBannerState extends State<_JointTransitionBanner> {
  late int _severity;
  bool _committing = false;
  bool _editing = false;

  static const _labels = ['None', 'Slight', 'Mild', 'Moderate', 'Painful'];

  @override
  void initState() {
    super.initState();
    _severity =
        widget.provider.getImmediateJointSeverity(
            widget.cycleId, widget.fromWeek, widget.liftType) ??
        1;
  }

  String get _suggestion {
    if (_severity <= 2) return 'progress';
    if (_severity == 3) return 'hold';
    return 'reduce';
  }

  double _progressedTm(double tm) =>
      WendlerCalculator.roundToNearest2_5(tm + widget.liftType.tmIncrement);
  double _reducedTm(double tm) =>
      WendlerCalculator.roundToNearest2_5(tm * 0.95);

  Future<void> _commit(String decision) async {
    setState(() => _committing = true);
    await widget.provider.commitWeekTransition(
        widget.cycleId, widget.fromWeek, widget.liftType, decision, _severity);
    setState(() {
      _committing = false;
      _editing = false;
    });
  }

  static String _decisionLabel(String d) =>
      d[0].toUpperCase() + d.substring(1);

  static Color _decisionColor(String d) {
    if (d == 'progress') return AppTheme.success;
    if (d == 'reduce') return Colors.redAccent;
    return AppTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    final existingDecision = widget.provider
        .getWeekTransitionDecision(widget.cycleId, widget.fromWeek, widget.liftType);
    final isCommitted = existingDecision != null && !_editing;

    // Committed (non-editing) state — compact row
    if (isCommitted) {
      final tm = widget.provider.getTrainingMax(widget.liftType);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _decisionColor(existingDecision).withValues(alpha: 0.4),
              width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.monitor_heart_outlined,
                size: 15, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13),
                  children: [
                    TextSpan(
                      text: _decisionLabel(existingDecision),
                      style: TextStyle(
                        color: _decisionColor(existingDecision),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' — TM ${WendlerCalculator.formatWeight(tm)} kg',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _editing = true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accent,
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 32),
              ),
              child: const Text('Edit', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    // Full banner — first time or editing
    final tm = widget.provider.getTrainingMax(widget.liftType);
    // When editing, base the shown values off the stored tm_before so user
    // sees what the options will actually produce.
    final baseTm = _editing
        ? (widget.provider.getTransitionTmBefore(widget.fromWeek, widget.liftType) ?? tm)
        : tm;
    final progressedTm = _progressedTm(baseTm);
    final reducedTm = _reducedTm(baseTm);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined,
                  size: 16, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                _editing
                    ? 'EDIT DECISION — WEEK ${widget.fromWeek + 1}'
                    : 'JOINT CHECK-IN — WEEK ${widget.fromWeek + 1}',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              if (_editing) ...[
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _editing = false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 24),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Current ${widget.liftType.displayName} TM: ${WendlerCalculator.formatWeight(tm)} kg',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'How did your joints feel after last week?',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: List.generate(5, (i) {
              final sev = i + 1;
              final selected = _severity == sev;
              return GestureDetector(
                onTap: () => setState(() => _severity = sev),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppTheme.accent : AppTheme.textSecondary,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$sev ${_labels[i]}',
                    style: TextStyle(
                      color: selected ? AppTheme.accent : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _DecisionButton(
                label: 'Progress',
                subLabel: '→ ${WendlerCalculator.formatWeight(progressedTm)} kg',
                isSuggested: _suggestion == 'progress',
                isDisabled: _committing,
                color: AppTheme.success,
                onTap: () => _commit('progress'),
              ),
              const SizedBox(width: 6),
              _DecisionButton(
                label: 'Hold',
                subLabel: '${WendlerCalculator.formatWeight(baseTm)} kg',
                isSuggested: _suggestion == 'hold',
                isDisabled: _committing,
                color: AppTheme.accent,
                onTap: () => _commit('hold'),
              ),
              const SizedBox(width: 6),
              _DecisionButton(
                label: 'Reduce',
                subLabel: '→ ${WendlerCalculator.formatWeight(reducedTm)} kg',
                isSuggested: _suggestion == 'reduce',
                isDisabled: _committing,
                color: Colors.redAccent,
                onTap: () => _commit('reduce'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Suggested: ${_decisionLabel(_suggestion)}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final String subLabel;
  final bool isSuggested;
  final bool isDisabled;
  final Color color;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.label,
    required this.subLabel,
    required this.isSuggested,
    required this.isDisabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSuggested ? color.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
              color: isSuggested ? color : AppTheme.textSecondary.withValues(alpha: 0.4),
              width: isSuggested ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSuggested ? color : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: isSuggested ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: TextStyle(
                  color: isSuggested
                      ? color.withValues(alpha: 0.8)
                      : AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final int index;
  final bool checked;
  final VoidCallback onToggle;
  final String title;
  final String subtitle;
  final String? plateInfo;
  final String? prHint;
  final String? beatLastHint;
  final bool isRest;

  const _CheckRow({
    required this.index,
    required this.checked,
    required this.onToggle,
    required this.title,
    required this.subtitle,
    this.plateInfo,
    this.prHint,
    this.beatLastHint,
    this.isRest = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checked,
              onChanged: (_) => onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: checked
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: checked
                          ? AppTheme.textSecondary.withValues(alpha: 0.5)
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (plateInfo != null && plateInfo!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      plateInfo!,
                      style: const TextStyle(
                        color: AppTheme.teal,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (prHint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      prHint!,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (beatLastHint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      beatLastHint!,
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
