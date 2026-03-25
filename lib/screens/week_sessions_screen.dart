import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cycle_model.dart';
import '../models/session_model.dart';
import '../models/lift_type.dart';
import '../providers/app_provider.dart';
import '../services/wendler_calculator.dart';
import '../theme/app_theme.dart';
import 'session_screen.dart';
import 'workout_screen.dart';

class WeekSessionsScreen extends StatefulWidget {
  final CycleModel cycle;
  final int weekNumber;
  final SessionModel? sessionToOpen;

  const WeekSessionsScreen({
    super.key,
    required this.cycle,
    required this.weekNumber,
    this.sessionToOpen,
  });

  @override
  State<WeekSessionsScreen> createState() => _WeekSessionsScreenState();
}

class _WeekSessionsScreenState extends State<WeekSessionsScreen> {
  late int _currentWeek;

  @override
  void initState() {
    super.initState();
    _currentWeek = widget.weekNumber;

    // If we have a session to open immediately, do it after build
    if (widget.sessionToOpen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionScreen(session: widget.sessionToOpen!),
            ),
          );
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Sessions for this week in this cycle
    final allSessions = provider.currentCycle?.id == widget.cycle.id
        ? provider.getSessionsForWeek(_currentWeek)
        : <SessionModel>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        title: Text(
          'Week $_currentWeek',
          style: const TextStyle(
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
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Top navigation row: Previous / Next week
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentWeek > 1
                        ? () => setState(() => _currentWeek--)
                        : null,
                    icon: const Icon(Icons.keyboard_double_arrow_left, size: 18),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _currentWeek > 1
                          ? AppTheme.textSecondary
                          : AppTheme.textSecondary.withValues(alpha: 0.3),
                      side: BorderSide(
                        color: _currentWeek > 1
                            ? AppTheme.textSecondary
                            : AppTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _currentWeek < 4
                        ? () => setState(() => _currentWeek++)
                        : null,
                    icon: const Icon(Icons.keyboard_double_arrow_right, size: 18),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentWeek < 4 ? AppTheme.accent : AppTheme.surface,
                      foregroundColor: _currentWeek < 4 ? Colors.black : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Workouts card + Cardio card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Workouts card
                  Expanded(
                    flex: 3,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                            child: Text(
                              'Workouts',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.only(bottom: 8),
                              children: [
                                for (final lift in _liftDisplayOrder)
                                  _LiftWorkoutRow(
                                    lift: lift,
                                    weekNumber: _currentWeek,
                                    sessions: allSessions,
                                    cycle: widget.cycle,
                                    onTap: () {
                                      final isDone = allSessions.any((s) =>
                                          s.week == _currentWeek &&
                                          s.liftKeys.contains(lift.dbKey) &&
                                          s.isComplete);
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => WorkoutScreen(
                                            liftType: lift,
                                            week: _currentWeek,
                                            cycleId: widget.cycle.id ?? 0,
                                            isAlreadyComplete: isDone,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          // Bottom bar: Log Bodyweight + Help
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _showBodyweightDialog(context, provider),
                                  icon: const Icon(Icons.monitor_weight, size: 18),
                                  label: const Text('Log Bodyweight'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _showHelpDialog(context),
                                  icon: const Icon(Icons.help_outline, size: 16),
                                  label: const Text('Help'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Cardio card
                  _CardioCard(
                    cycleId: widget.cycle.id ?? 0,
                    weekNumber: _currentWeek,
                    provider: provider,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _liftDisplayOrder = [
    LiftType.militaryPress,
    LiftType.backSquat,
    LiftType.benchPress,
    LiftType.deadlift,
  ];

  void _showBodyweightDialog(BuildContext context, AppProvider provider) {
    // Pre-fill with last logged value so user knows it was saved
    final entries = provider.bodyweightEntries;
    final lastValue = entries.isNotEmpty ? entries.last['weight_kg'] as double? : null;
    final controller = TextEditingController(
      text: lastValue != null ? lastValue.toStringAsFixed(1) : '',
    );
    if (lastValue != null) {
      controller.selection =
          TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Bodyweight',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            hintText: 'e.g. 58.5',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null) {
                final today = DateTime.now().toIso8601String().substring(0, 10);
                await provider.logBodyweight(today, val);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Bodyweight saved: ${val.toStringAsFixed(1)} kg'),
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
          'Tap a lift row to open the workout screen for that lift.\n\n'
          'Use the Previous / Next buttons to navigate between weeks.\n\n'
          'Tap "Log Bodyweight" to record your weight today.',
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

class _LiftWorkoutRow extends StatelessWidget {
  final LiftType lift;
  final int weekNumber;
  final List<SessionModel> sessions;
  final CycleModel cycle;
  final VoidCallback onTap;

  const _LiftWorkoutRow({
    required this.lift,
    required this.weekNumber,
    required this.sessions,
    required this.cycle,
    required this.onTap,
  });

  // Find the most recent completed session for this lift in this week
  ({String? date, String? score}) _getLiftStatus() {
    // Look through sessions for this week that contain this lift
    final matchingSessions = sessions
        .where((s) => s.liftKeys.contains(lift.dbKey) && s.isComplete)
        .toList();
    if (matchingSessions.isEmpty) return (date: null, score: null);
    // Most recent
    matchingSessions.sort((a, b) => b.date.compareTo(a.date));
    final s = matchingSessions.first;
    String dateLabel;
    try {
      final dt = DateTime.parse(s.date);
      dateLabel = DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      dateLabel = s.date;
    }
    return (date: dateLabel, score: 'Done');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final tm = provider.getTrainingMax(lift);
    final status = _getLiftStatus();
    final sets = WendlerCalculator.getSetsForWeek(weekNumber, tm);
    final topSet = sets.isNotEmpty ? sets.last : null;
    final topSetLabel = topSet != null
        ? '${WendlerCalculator.formatWeight(topSet.weight)} × ${topSet.isAmrap ? '${topSet.reps}+' : '${topSet.reps}'}'
        : null;

    final isDone = status.date != null;

    return Ink(
      color: isDone ? AppTheme.success.withValues(alpha: 0.15) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.bar_chart,
                color: isDone ? AppTheme.success : AppTheme.accent,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lift.displayName,
                      style: TextStyle(
                        color: isDone ? AppTheme.textSecondary : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Date: ${status.date ?? 'TBD'}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Score: ${status.score ?? 'TBD'}  •  TM: ${WendlerCalculator.formatWeight(tm)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (topSetLabel != null)
                      Text(
                        'Top set: $topSetLabel',
                        style: TextStyle(
                          color: isDone
                              ? AppTheme.textSecondary.withValues(alpha: 0.6)
                              : AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDone ? AppTheme.surface : AppTheme.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardioCard extends StatelessWidget {
  final int cycleId;
  final int weekNumber;
  final AppProvider provider;

  const _CardioCard({
    required this.cycleId,
    required this.weekNumber,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final totalMins = provider.getZone2MinutesForWeek(cycleId, weekNumber);
    const target = 100;
    final isDone = totalMins >= target;

    return Card(
      margin: EdgeInsets.zero,
      child: Ink(
        decoration: BoxDecoration(
          color: isDone ? AppTheme.success.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                'Cardio',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Divider(height: 1),
            InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              onTap: () => _showZone2Dialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.directions_run,
                      color: isDone ? AppTheme.success : AppTheme.teal,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zone 2',
                            style: TextStyle(
                              color: isDone ? AppTheme.textSecondary : AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isDone
                                ? '$totalMins / $target min — complete'
                                : '$totalMins / $target min this week',
                            style: TextStyle(
                              color: isDone ? AppTheme.success : AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.add_circle_outline,
                      color: isDone ? AppTheme.success.withValues(alpha: 0.5) : AppTheme.teal,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showZone2Dialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Zone 2',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How many minutes?',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
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
                hintText: '50',
                suffix: Text('min', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
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
              final mins = int.tryParse(controller.text);
              if (mins != null && mins > 0) {
                await provider.logZone2(cycleId, weekNumber, mins);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Zone 2 logged: $mins min'),
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
}
