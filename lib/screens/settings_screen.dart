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
          for (final lift in LiftType.values)
            _TmRow(lift: lift, provider: provider),

          const SizedBox(height: 8),
          _SectionHeader(label: 'Rest Timer'),
          _RestTimerRow(provider: provider),

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
                  Text(
                    'v1.0.0',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A training tracker for Jim Wendler\'s 5/3/1 powerlifting programme. '
                    'Metric (kg) only. Dark mode always.',
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

class _TmRow extends StatelessWidget {
  final LiftType lift;
  final AppProvider provider;

  const _TmRow({required this.lift, required this.provider});

  @override
  Widget build(BuildContext context) {
    final tm = provider.getTrainingMax(lift);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lift.displayName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Minus button
            _StepButton(
              icon: Icons.remove,
              onPressed: () {
                final newVal = (tm - 2.5).clamp(20.0, 500.0);
                provider.updateTrainingMax(lift, newVal);
              },
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _editTm(context, lift, tm, provider),
              child: Container(
                constraints: const BoxConstraints(minWidth: 80),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  WendlerCalculator.formatWeight(tm),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Plus button
            _StepButton(
              icon: Icons.add,
              onPressed: () {
                final newVal = (tm + 2.5).clamp(20.0, 500.0);
                provider.updateTrainingMax(lift, newVal);
              },
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

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _StepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.accent, size: 18),
      ),
    );
  }
}

class _RestTimerRow extends StatelessWidget {
  final AppProvider provider;
  const _RestTimerRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final seconds = provider.restTimerSeconds;
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final label = secs == 0 ? '${mins}m' : '${mins}m ${secs}s';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 16,
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
              divisions: 24, // 10-second steps
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
