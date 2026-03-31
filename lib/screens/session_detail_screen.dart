import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/session_model.dart';
import '../models/set_log_model.dart';
import '../models/lift_type.dart';
import '../services/wendler_calculator.dart';
import '../services/plate_calculator.dart';
import '../theme/app_theme.dart';

class SessionDetailScreen extends StatefulWidget {
  final SessionModel session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final TextEditingController _notesController;
  List<SetLogModel>? _setLogs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.session.notes);
    _loadSetLogs();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSetLogs() async {
    final provider = context.read<AppProvider>();
    final logs = await provider.fetchSetLogsForCompletedSession(widget.session.id!);

    // If session.notes is empty, recover notes from history_entries (WorkoutScreen
    // used to only save notes there, not on the session record).
    String resolvedNotes = widget.session.notes;
    if (resolvedNotes.isEmpty) {
      final liftKeys = widget.session.liftKeys;
      final allHistory = provider.historyEntries;
      final parts = <String>[];
      for (final key in liftKeys) {
        final entry = allHistory
            .where((e) => e.lift == key && e.date == widget.session.date && e.notes.isNotEmpty)
            .firstOrNull;
        if (entry != null) parts.add(entry.notes);
      }
      if (parts.isNotEmpty) {
        resolvedNotes = parts.join('\n');
        // Persist so future opens don't need to recover again
        await provider.updateSessionNotes(widget.session, resolvedNotes);
      }
    }

    if (mounted) {
      _notesController.text = resolvedNotes;
      setState(() {
        _setLogs = logs;
        _loading = false;
      });
    }
  }

  String get _dateLabel {
    try {
      return DateFormat('EEEE d MMMM yyyy').format(DateTime.parse(widget.session.date));
    } catch (_) {
      return widget.session.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final liftKeys = widget.session.liftKeys;
    final weekLabel = widget.session.week == 4 ? 'Deload' : 'Week ${widget.session.week}';

    return Scaffold(
      appBar: AppBar(
        title: Text(weekLabel),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Cycle ${widget.session.cycleId}',
                style: const TextStyle(color: AppTheme.accent, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              _dateLabel,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              liftKeys.map((k) {
                final lt = LiftTypeExtension.fromDbKey(k);
                return lt?.displayName ?? k;
              }).join(' + '),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Sets per lift
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_setLogs != null)
              for (final liftKey in liftKeys) ...[
                _LiftDetailCard(
                  liftKey: liftKey,
                  setLogs: _setLogs!.where((s) => s.lift == liftKey).toList(),
                  provider: provider,
                ),
                const SizedBox(height: 12),
              ],

            const SizedBox(height: 8),

            // Notes section
            const Text(
              'SESSION NOTES',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tap to add notes...',
              ),
              onChanged: (val) {
                provider.updateSessionNotes(widget.session, val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LiftDetailCard extends StatelessWidget {
  final String liftKey;
  final List<SetLogModel> setLogs;
  final AppProvider provider;

  const _LiftDetailCard({
    required this.liftKey,
    required this.setLogs,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final lift = LiftTypeExtension.fromDbKey(liftKey);
    if (lift == null) return const SizedBox.shrink();

    // Find AMRAP set to calculate e1RM
    final amrapSet = setLogs.where((s) => s.isAmrap).firstOrNull;
    double? e1rm;
    if (amrapSet != null && amrapSet.actualReps != null && amrapSet.actualReps! > 0) {
      e1rm = WendlerCalculator.calcEpley1RM(
          amrapSet.prescribedWeight, amrapSet.actualReps!);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lift.displayName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (e1rm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'e1RM ${e1rm.round()} kg',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (setLogs.isEmpty)
              const Text(
                'No sets recorded',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              )
            else
              for (final log in setLogs) _SetRow(setLog: log),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final SetLogModel setLog;

  const _SetRow({required this.setLog});

  @override
  Widget build(BuildContext context) {
    final weightStr = WendlerCalculator.formatWeight(setLog.prescribedWeight);
    final platesStr = PlateCalculator.formatPlates(setLog.prescribedWeight);

    String repsStr;
    if (setLog.isAmrap) {
      final actual = setLog.actualReps;
      repsStr = actual != null && actual > 0 ? '$actual reps (AMRAP)' : '${setLog.prescribedReps}+ reps (AMRAP)';
    } else {
      repsStr = '${setLog.prescribedReps} reps';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              'Set ${setLog.setNumber}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$weightStr × $repsStr',
                  style: TextStyle(
                    color: setLog.isAmrap ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: setLog.isAmrap ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (platesStr.isNotEmpty)
                  Text(
                    platesStr,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (setLog.isComplete)
            const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success)
          else
            const Icon(Icons.radio_button_unchecked, size: 16, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}
