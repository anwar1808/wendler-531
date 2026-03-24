import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/lift_type.dart';
import '../models/history_entry.dart';
import '../providers/app_provider.dart';
import '../services/wendler_calculator.dart';
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
  bool _restTimerVisible = false;
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
    final restSeconds = provider.restTimerSeconds;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Card(
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
                            ),
                            const SizedBox(height: 8),

                            // Rest 1
                            _CheckRow(
                              index: _idxRest1,
                              checked: _checkedItems.contains(_idxRest1),
                              onToggle: () => _toggleRest(_idxRest1, restSeconds),
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
                            ),
                            const SizedBox(height: 8),

                            // Rest 2
                            _CheckRow(
                              index: _idxRest2,
                              checked: _checkedItems.contains(_idxRest2),
                              onToggle: () => _toggleRest(_idxRest2, restSeconds),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Rest timer overlay
          if (_restTimerVisible)
            Positioned(
              bottom: 72,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: RestTimerWidget(
                  durationSeconds: restSeconds,
                  liftName: widget.liftType.displayName,
                  nextSetInfo: null,
                  onDone: () => setState(() => _restTimerVisible = false),
                  onSkip: () => setState(() => _restTimerVisible = false),
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

  void _toggleRest(int idx, int restSeconds) {
    setState(() {
      if (_checkedItems.contains(idx)) {
        _checkedItems.remove(idx);
        _restTimerVisible = false;
      } else {
        _checkedItems.add(idx);
        _restTimerVisible = true;
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
    final controller = TextEditingController();
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
              controller: controller,
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reps = int.tryParse(controller.text);
              if (reps != null && reps > 0) {
                await provider.logScoreAndComplete(
                  widget.liftType,
                  widget.week,
                  widget.cycleId,
                  amrapWeight,
                  reps,
                );
                final oneRm = WendlerCalculator.calcEpley1RM(amrapWeight, reps);
                if (ctx.mounted) {
                  Navigator.pop(ctx); // close dialog
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

class _CheckRow extends StatelessWidget {
  final int index;
  final bool checked;
  final VoidCallback onToggle;
  final String title;
  final String subtitle;
  final String? prHint;
  final String? beatLastHint;
  final bool isRest;

  const _CheckRow({
    required this.index,
    required this.checked,
    required this.onToggle,
    required this.title,
    required this.subtitle,
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
