import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/session_model.dart';
import '../models/lift_type.dart';
import '../services/wendler_calculator.dart';
import '../theme/app_theme.dart';
import 'session_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    final cycle = provider.currentCycle;
    final week = provider.currentWeek;
    final sessions = provider.getSessionsForWeek(week);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wendler 5/3/1'),
        actions: [
          if (provider.allSessionsComplete)
            TextButton.icon(
              onPressed: () => _confirmCompleteCycle(context, provider),
              icon: const Icon(Icons.check_circle_outline, color: AppTheme.accent),
              label: const Text(
                'Complete Cycle',
                style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Cycle / Week header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _HeaderChip(
                  label: 'Cycle ${cycle?.number ?? 1}',
                  icon: Icons.loop,
                ),
                const SizedBox(width: 12),
                _HeaderChip(
                  label: week == 4 ? 'Deload Week' : 'Week $week',
                  icon: Icons.calendar_today,
                  highlight: week == 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Session cards
          if (sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No sessions found. Pull down to refresh.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            for (final session in sessions)
              _SessionCard(session: session, week: week, provider: provider),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _confirmCompleteCycle(BuildContext context, AppProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Complete Cycle?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will auto-increment your Training Maxes and start Cycle 2.\n\n'
          '• Squat / Deadlift: +5 kg\n'
          '• Bench / OHP: +2.5 kg',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await provider.completeCycle();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cycle complete! TMs incremented. New cycle started.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool highlight;

  const _HeaderChip({required this.label, required this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: highlight ? Border.all(color: AppTheme.accent.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: highlight ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: highlight ? AppTheme.accent : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final int week;
  final AppProvider provider;

  const _SessionCard({
    required this.session,
    required this.week,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final liftKeys = session.liftKeys;
    final dayLabel = session.sessionType == 'mon' ? 'Monday' : 'Thursday';
    final liftNames = liftKeys.map((k) {
      final lt = LiftTypeExtension.fromDbKey(k);
      return lt?.displayName ?? k;
    }).join(' + ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (session.isComplete)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: AppTheme.success),
                        SizedBox(width: 4),
                        Text('Done', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              liftNames,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            // Weight previews
            for (final key in liftKeys) ...[
              _LiftPreviewRow(liftKey: key, week: week, provider: provider),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 14),
            if (!session.isComplete)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionScreen(session: session),
                      ),
                    );
                  },
                  child: const Text('Start Session'),
                ),
              )
            else if (session.date.isNotEmpty)
              Text(
                'Completed ${session.date}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiftPreviewRow extends StatelessWidget {
  final String liftKey;
  final int week;
  final AppProvider provider;

  const _LiftPreviewRow({
    required this.liftKey,
    required this.week,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final lift = LiftTypeExtension.fromDbKey(liftKey);
    if (lift == null) return const SizedBox.shrink();
    final tm = provider.getTrainingMax(lift);
    final sets = WendlerCalculator.getSetsForWeek(week, tm);
    if (sets.isEmpty) return const SizedBox.shrink();

    final topSet = sets.last;
    final weightStr = WendlerCalculator.formatWeight(topSet.weight);
    final repsLabel = topSet.isAmrap ? '${topSet.reps}+' : '${topSet.reps}';

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            lift.displayName,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          '$weightStr × $repsLabel',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '(top set)',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
