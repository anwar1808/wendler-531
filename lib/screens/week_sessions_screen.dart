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

class WeekSessionsScreen extends StatelessWidget {
  final CycleModel cycle;
  final int weekNumber;
  final SessionModel? sessionToOpen;

  const WeekSessionsScreen({
    super.key,
    required this.cycle,
    required this.weekNumber,
    this.sessionToOpen,
  });

  String get _weekLabel => weekNumber == 4 ? 'Week 4 — Deload' : 'Week $weekNumber';

  @override
  Widget build(BuildContext context) {
    // If we have a session to open immediately, do it after build
    if (sessionToOpen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionScreen(session: sessionToOpen!),
            ),
          );
        }
      });
    }

    final provider = context.watch<AppProvider>();
    final sessions = provider.currentCycle?.id == cycle.id
        ? provider.getSessionsForWeek(weekNumber)
        : <SessionModel>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_weekLabel),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center, color: AppTheme.textSecondary, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'No sessions yet for $_weekLabel.',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap "Start Session" to begin.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  return _SessionTile(
                    session: sessions[index],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SessionScreen(session: sessions[index]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

          // Start Session button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showStartSessionSheet(context, provider),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Session'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStartSessionSheet(BuildContext context, AppProvider provider) {
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
}

class _SessionTile extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const _SessionTile({required this.session, required this.onTap});

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEE d MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final liftNames = session.liftKeys.map((k) {
      final lt = LiftTypeExtension.fromDbKey(k);
      return lt?.displayName ?? k;
    }).join(', ');

    final dateLabel = _formatDate(session.date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                session.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                color: session.isComplete ? AppTheme.success : AppTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (liftNames.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        liftNames,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// Start session bottom sheet
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
            builder: (_) => SessionScreen(session: session),
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
  final ValueChanged<bool> onChanged;

  const _LiftCheckRow({
    required this.lift,
    required this.provider,
    required this.isSelected,
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
