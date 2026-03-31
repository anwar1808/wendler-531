import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/session_model.dart';
import '../models/lift_type.dart';
import '../services/wendler_calculator.dart';
import '../theme/app_theme.dart';
import 'historical_data_screen.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sessions = provider.completedSessions;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sessions.length + 1,
        itemBuilder: (context, index) {
          if (index < sessions.length) {
            return _SessionHistoryTile(session: sessions[index]);
          }
          return const _HistoricalDataTile();
        },
      ),
    );
  }
}

class _SessionHistoryTile extends StatelessWidget {
  final SessionModel session;
  const _SessionHistoryTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final liftKeys = session.liftKeys;
    final liftNames = liftKeys.map((k) {
      final lt = LiftTypeExtension.fromDbKey(k);
      return lt?.displayName ?? k;
    }).join(' + ');

    String dateLabel = session.date;
    try {
      final dt = DateTime.parse(session.date);
      dateLabel = DateFormat('EEE d MMM yyyy').format(dt);
    } catch (_) {}

    final weekLabel = session.week == 4 ? 'Deload' : 'Week ${session.week}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: session),
          ),
        ),
        onLongPress: () => _confirmDelete(context, provider),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check, color: AppTheme.success, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      liftNames,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateLabel  •  $weekLabel',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (liftKeys.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _TopSetLine(liftKeys: liftKeys, week: session.week),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Session?',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently delete this session and remove its data from the graph.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await provider.deleteSessionById(session);
    }
  }
}

class _HistoricalDataTile extends StatelessWidget {
  const _HistoricalDataTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HistoricalDataScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history_edu, color: AppTheme.teal, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historical Data',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '2018 – 2024 training records',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
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

class _TopSetLine extends StatelessWidget {
  final List<String> liftKeys;
  final int week;

  const _TopSetLine({required this.liftKeys, required this.week});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final parts = <String>[];
    for (final key in liftKeys) {
      final lift = LiftTypeExtension.fromDbKey(key);
      if (lift == null) continue;
      final tm = provider.getTrainingMax(lift);
      final sets = WendlerCalculator.getSetsForWeek(week, tm);
      if (sets.isNotEmpty) {
        final top = sets.last;
        final repsLabel = top.isAmrap ? '${top.reps}+' : '${top.reps}';
        parts.add('${lift.displayName}: ${WendlerCalculator.formatWeight(top.weight)} × $repsLabel');
      }
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  |  '),
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
    );
  }
}
