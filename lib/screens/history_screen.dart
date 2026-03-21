import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/session_model.dart';
import '../models/set_log_model.dart';
import '../models/lift_type.dart';
import '../db/database_helper.dart';
import '../services/wendler_calculator.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sessions = provider.completedSessions;

    if (sessions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: const Center(
          child: Text(
            'No completed sessions yet.\nFinish your first session to see history.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          return _SessionHistoryTile(session: sessions[index]);
        },
      ),
    );
  }
}

class _SessionHistoryTile extends StatefulWidget {
  final SessionModel session;
  const _SessionHistoryTile({required this.session});

  @override
  State<_SessionHistoryTile> createState() => _SessionHistoryTileState();
}

class _SessionHistoryTileState extends State<_SessionHistoryTile> {
  bool _expanded = false;
  List<SetLogModel>? _setLogs;

  Future<void> _loadSetLogs() async {
    if (_setLogs != null) return;
    final logs = await DatabaseHelper.instance.getSetLogsForSession(widget.session.id!);
    if (mounted) setState(() => _setLogs = logs);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _expanded = !_expanded);
          if (_expanded) _loadSetLogs();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          liftNames,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Week ${session.week} · ${session.sessionType == 'mon' ? 'Monday' : 'Thursday'}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              if (session.notes.isNotEmpty && !_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  session.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (_expanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (_setLogs == null)
                  const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    ),
                  )
                else
                  _SetLogTable(setLogs: _setLogs!, session: session),
                if (session.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session.notes,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SetLogTable extends StatelessWidget {
  final List<SetLogModel> setLogs;
  final SessionModel session;

  const _SetLogTable({required this.setLogs, required this.session});

  @override
  Widget build(BuildContext context) {
    final liftKeys = session.liftKeys;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final liftKey in liftKeys) ...[
          _LiftLogSection(
            liftKey: liftKey,
            logs: setLogs.where((s) => s.lift == liftKey).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LiftLogSection extends StatelessWidget {
  final String liftKey;
  final List<SetLogModel> logs;

  const _LiftLogSection({required this.liftKey, required this.logs});

  @override
  Widget build(BuildContext context) {
    final lift = LiftTypeExtension.fromDbKey(liftKey);
    if (logs.isEmpty) return const SizedBox.shrink();

    double? topWeight;
    for (final log in logs) {
      if (log.isComplete && (topWeight == null || log.prescribedWeight > topWeight)) {
        topWeight = log.prescribedWeight;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              lift?.displayName ?? liftKey,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (topWeight != null) ...[
              const SizedBox(width: 8),
              Text(
                'top: ${WendlerCalculator.formatWeight(topWeight)}',
                style: const TextStyle(color: AppTheme.accent, fontSize: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        for (final log in logs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    'Set ${log.setNumber}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
                Text(
                  WendlerCalculator.formatWeight(log.prescribedWeight),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
                Text(
                  ' × ',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                Text(
                  log.isAmrap
                      ? (log.actualReps != null ? '${log.actualReps} (${log.prescribedReps}+)' : '${log.prescribedReps}+')
                      : '${log.prescribedReps}',
                  style: TextStyle(
                    color: log.isAmrap ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: log.isAmrap ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  log.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: log.isComplete ? AppTheme.success : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
