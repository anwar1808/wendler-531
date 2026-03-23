import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/lift_type.dart';
import '../services/wendler_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/tm_edit_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _SectionHeader(label: 'Training Maxes'),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Edit your TM directly or use +2.5 / +5 quick buttons.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          for (final lift in LiftType.values)
            _TmCard(lift: lift, provider: provider),

          const SizedBox(height: 8),
          _SectionHeader(label: 'Rest Timer'),
          _RestTimerCard(provider: provider),

          const SizedBox(height: 8),
          _SectionHeader(label: 'About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wendler 5/3/1',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'v1.2.0',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A training tracker for Jim Wendler\'s 5/3/1 powerlifting programme. '
                    'Metric (kg) only. Each lift tracks its own week independently.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _TmCard extends StatelessWidget {
  final LiftType lift;
  final AppProvider provider;

  const _TmCard({required this.lift, required this.provider});

  @override
  Widget build(BuildContext context) {
    final tm = provider.getTrainingMax(lift);
    final increment = lift.isLower ? 5.0 : 2.5;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => _editTm(context, lift, tm, provider),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        WendlerCalculator.formatWeight(tm),
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 16, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _QuickButton(
                  label: '-$increment',
                  onPressed: () {
                    final newVal = (tm - increment).clamp(20.0, 500.0);
                    provider.updateTrainingMax(lift, newVal);
                  },
                ),
                const SizedBox(width: 8),
                _QuickButton(
                  label: '-2.5',
                  onPressed: increment > 2.5
                      ? () {
                          final newVal = (tm - 2.5).clamp(20.0, 500.0);
                          provider.updateTrainingMax(lift, newVal);
                        }
                      : null,
                ),
                const Spacer(),
                _QuickButton(
                  label: '+2.5',
                  onPressed: increment > 2.5
                      ? () {
                          final newVal = (tm + 2.5).clamp(20.0, 500.0);
                          provider.updateTrainingMax(lift, newVal);
                        }
                      : null,
                  accent: true,
                ),
                const SizedBox(width: 8),
                _QuickButton(
                  label: '+$increment',
                  onPressed: () {
                    final newVal = (tm + increment).clamp(20.0, 500.0);
                    provider.updateTrainingMax(lift, newVal);
                  },
                  accent: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editTm(BuildContext context, LiftType lift, double tm, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => TmEditDialog(
        lift: lift,
        currentValue: tm,
        onSave: (val) => provider.updateTrainingMax(lift, val),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool accent;

  const _QuickButton({
    required this.label,
    required this.onPressed,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? (accent
                  ? AppTheme.accent.withValues(alpha: 0.15)
                  : AppTheme.surface)
              : AppTheme.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? (accent ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.divider)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled
                ? (accent ? AppTheme.accent : AppTheme.textSecondary)
                : AppTheme.textSecondary.withValues(alpha: 0.4),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _RestTimerCard extends StatelessWidget {
  final AppProvider provider;
  const _RestTimerCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final seconds = provider.restTimerSeconds;
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final label = secs == 0 ? '${mins}m' : '${mins}m ${secs}s';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rest Duration',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: seconds.toDouble(),
              min: 60,
              max: 300,
              divisions: 24,
              onChanged: (val) {
                provider.setRestTimerSeconds(val.round());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('1m', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                Text('5m', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
