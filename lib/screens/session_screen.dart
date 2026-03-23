import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/session_model.dart';
import '../models/set_log_model.dart';
import '../models/lift_type.dart';
import '../services/wendler_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/set_tile.dart';
import '../widgets/rest_timer_widget.dart';
import '../widgets/tm_edit_dialog.dart';

class SessionScreen extends StatefulWidget {
  final SessionModel session;

  const SessionScreen({super.key, required this.session});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _timerVisible = false;
  String _timerLiftName = '';
  String? _timerNextSet;
  late SessionModel _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _notesController.text = _session.notes;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showRestTimer(String liftName, String? nextSet) {
    setState(() {
      _timerVisible = true;
      _timerLiftName = liftName;
      _timerNextSet = nextSet;
    });
  }

  void _hideRestTimer() {
    setState(() => _timerVisible = false);
  }

  String get _sessionTitle {
    final liftNames = _session.liftKeys.map((k) {
      final lt = LiftTypeExtension.fromDbKey(k);
      return lt?.displayName ?? k;
    }).join(' + ');
    return liftNames.isEmpty ? 'Session' : liftNames;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final sessionId = _session.id!;
    final setLogs = provider.getSetLogsForSession(sessionId);
    final lifts = _session.liftKeys;
    final restSeconds = provider.restTimerSeconds;

    final dateLabel = _session.date.isNotEmpty
        ? DateFormat('EEE d MMM yyyy').format(DateTime.parse(_session.date))
        : DateFormat('EEE d MMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Week ${_session.week}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                Text(
                  'Cycle ${provider.currentCycle?.number ?? 1}',
                  style: const TextStyle(color: AppTheme.accent, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // Session title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  _sessionTitle,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Lift sections
              for (final liftKey in lifts)
                _LiftSection(
                  liftKey: liftKey,
                  setLogs: setLogs.where((s) => s.lift == liftKey).toList(),
                  provider: provider,
                  session: _session,
                  onSetCompleted: (log, nextSetInfo) {
                    _showRestTimer(
                      LiftTypeExtension.fromDbKey(liftKey)?.displayName ?? liftKey,
                      nextSetInfo,
                    );
                  },
                ),

              // Session notes
              if (setLogs.isNotEmpty) ...[
                const Divider(height: 32, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'How did it go? Any pain, PRs, notes...',
                        ),
                        onChanged: (val) {
                          provider.updateSessionNotes(_session, val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Finish session button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: () => _finishSession(context, provider),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Finish Session', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),

          // Rest timer overlay
          if (_timerVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: RestTimerWidget(
                  durationSeconds: restSeconds,
                  liftName: _timerLiftName,
                  nextSetInfo: _timerNextSet,
                  onDone: _hideRestTimer,
                  onSkip: _hideRestTimer,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _finishSession(BuildContext context, AppProvider provider) async {
    await provider.finishSession(_session, _notesController.text);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session complete! Week advanced for each lift.'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }
}

class _LiftSection extends StatelessWidget {
  final String liftKey;
  final List<SetLogModel> setLogs;
  final AppProvider provider;
  final SessionModel session;
  final void Function(SetLogModel log, String? nextSetInfo) onSetCompleted;

  const _LiftSection({
    required this.liftKey,
    required this.setLogs,
    required this.provider,
    required this.session,
    required this.onSetCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final lift = LiftTypeExtension.fromDbKey(liftKey);
    if (lift == null) return const SizedBox.shrink();
    final tm = provider.getTrainingMax(lift);

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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => _editTm(context, lift, tm, provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TM: ${WendlerCalculator.formatWeight(tm)}',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: AppTheme.accent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (setLogs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Loading sets...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              )
            else
              for (int i = 0; i < setLogs.length; i++) ...[
                SetTile(
                  setLog: setLogs[i],
                  onChecked: (checked) async {
                    if (checked == true) {
                      final log = setLogs[i];
                      final next = i + 1 < setLogs.length ? setLogs[i + 1] : null;
                      String? nextSetInfo;
                      if (next != null) {
                        nextSetInfo =
                            '${WendlerCalculator.formatWeight(next.prescribedWeight)} × ${next.repsLabel}';
                      }
                      if (log.isAmrap) {
                        final reps = await _askAmrapReps(context);
                        await provider.completeSet(log, actualReps: reps);
                      } else {
                        await provider.completeSet(log);
                      }
                      onSetCompleted(log, nextSetInfo);
                    } else {
                      await provider.uncompleteSet(setLogs[i]);
                    }
                  },
                  onAmrapRepsChanged: setLogs[i].isAmrap
                      ? (reps) async {
                          await provider.completeSet(setLogs[i], actualReps: reps);
                        }
                      : null,
                ),
              ],
          ],
        ),
      ),
    );
  }

  Future<int?> _askAmrapReps(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('AMRAP Reps', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'How many reps?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              Navigator.pop(ctx, n);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editTm(BuildContext context, LiftType lift, double tm, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => TmEditDialog(
        lift: lift,
        currentValue: tm,
        onSave: (val) {
          provider.updateTrainingMax(lift, val);
        },
      ),
    );
  }
}
