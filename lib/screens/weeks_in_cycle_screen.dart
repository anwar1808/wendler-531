import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cycle_model.dart';
import '../providers/app_provider.dart';
import '../models/lift_type.dart';
import '../services/wendler_calculator.dart';
import '../theme/app_theme.dart';
import 'cycle_options_screen.dart';
import 'week_sessions_screen.dart';

class WeeksInCycleScreen extends StatelessWidget {
  final CycleModel cycle;

  const WeeksInCycleScreen({super.key, required this.cycle});

  String _weekDateRange(String cycleStartDate, int weekIndex) {
    try {
      final start = DateTime.parse(cycleStartDate);
      final weekStart = start.add(Duration(days: weekIndex * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final fmt = DateFormat('MMM d');
      return '${fmt.format(weekStart)} - ${fmt.format(weekEnd)}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    final weeks = [
      _WeekInfo(
        weekNumber: 1,
        label: 'Week 1',
        dateRange: _weekDateRange(cycle.startDate, 0),
        percentComplete: _weekPct(provider, 1),
      ),
      _WeekInfo(
        weekNumber: 2,
        label: 'Week 2',
        dateRange: _weekDateRange(cycle.startDate, 1),
        percentComplete: _weekPct(provider, 2),
      ),
      _WeekInfo(
        weekNumber: 3,
        label: 'Week 3',
        dateRange: _weekDateRange(cycle.startDate, 2),
        percentComplete: _weekPct(provider, 3),
      ),
      _WeekInfo(
        weekNumber: 4,
        label: 'Week 4 (Deload)',
        dateRange: _weekDateRange(cycle.startDate, 3),
        percentComplete: _weekPct(provider, 4),
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Weeks In Cycle'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: weeks.length,
              itemBuilder: (context, index) {
                final week = weeks[index];
                return _WeekTile(
                  weekInfo: week,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WeekSessionsScreen(
                          cycle: cycle,
                          weekNumber: week.weekNumber,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Cycle Options button at bottom left
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CycleOptionsScreen(cycle: cycle),
                  ),
                );
              },
              icon: const Icon(Icons.grid_view, color: AppTheme.accent),
              label: const Text(
                'Cycle Options',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _weekPct(AppProvider provider, int weekNumber) {
    if (provider.currentCycle?.id != cycle.id) return 0;
    return provider.getWeekPercentComplete(weekNumber);
  }
}

class _WeekInfo {
  final int weekNumber;
  final String label;
  final String dateRange;
  final int percentComplete;

  _WeekInfo({
    required this.weekNumber,
    required this.label,
    required this.dateRange,
    required this.percentComplete,
  });
}

class _WeekTile extends StatelessWidget {
  final _WeekInfo weekInfo;
  final VoidCallback onTap;

  const _WeekTile({required this.weekInfo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDone = weekInfo.percentComplete >= 100;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: 2,
      child: Ink(
        decoration: BoxDecoration(
          color: isDone ? AppTheme.success.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : Icons.calendar_today,
                  color: isDone ? AppTheme.success : AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekInfo.label,
                        style: TextStyle(
                          color: isDone ? AppTheme.textSecondary : AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (weekInfo.dateRange.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          weekInfo.dateRange,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        isDone ? 'Complete' : '${weekInfo.percentComplete}% Complete',
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
                  Icons.chevron_right,
                  color: isDone ? AppTheme.success.withValues(alpha: 0.5) : AppTheme.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper for the week sessions start session sheet — lifted here to avoid circular import
void showStartSessionSheet(BuildContext context, AppProvider provider, int weekNumber) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (_) => _StartSessionSheet(provider: provider, weekNumber: weekNumber),
  );
}

class _StartSessionSheet extends StatefulWidget {
  final AppProvider provider;
  final int weekNumber;

  const _StartSessionSheet({required this.provider, required this.weekNumber});

  @override
  State<_StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends State<_StartSessionSheet> {
  final Set<LiftType> _selected = {};
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Start Session',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose which lifts to include today:',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          for (final lift in LiftType.values) ...[
            _LiftCheckRow(
              lift: lift,
              provider: widget.provider,
              isSelected: _selected.contains(lift),
              weekNumber: widget.weekNumber,
              onChanged: (val) {
                setState(() {
                  if (val) {
                    _selected.add(lift);
                  } else {
                    _selected.remove(lift);
                  }
                });
              },
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selected.isEmpty || _loading) ? null : () => _startSession(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Start Session (${_selected.length} lift${_selected.length == 1 ? '' : 's'})',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSession(BuildContext context) async {
    setState(() => _loading = true);
    try {
      final lifts = LiftType.values.where((l) => _selected.contains(l)).toList();
      final session = await widget.provider.createAndStartSession(lifts);
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WeekSessionsScreen(
              cycle: widget.provider.currentCycle!,
              weekNumber: widget.weekNumber,
              sessionToOpen: session,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _LiftCheckRow extends StatelessWidget {
  final LiftType lift;
  final AppProvider provider;
  final bool isSelected;
  final int weekNumber;
  final ValueChanged<bool> onChanged;

  const _LiftCheckRow({
    required this.lift,
    required this.provider,
    required this.isSelected,
    required this.weekNumber,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final week = provider.getLiftWeek(lift);
    final weekLabel = week == 4 ? 'Deload' : 'Week $week';
    final tm = provider.getTrainingMax(lift);
    final sets = WendlerCalculator.getSetsForWeek(week, tm);
    final topSet = sets.isNotEmpty ? sets.last : null;

    return InkWell(
      onTap: () => onChanged(!isSelected),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accent.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (val) => onChanged(val ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lift.displayName,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (topSet != null)
                    Text(
                      '$weekLabel · ${WendlerCalculator.formatWeight(topSet.weight)} × ${topSet.isAmrap ? '${topSet.reps}+' : '${topSet.reps}'} (top)',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
