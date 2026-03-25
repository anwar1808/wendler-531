import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/lift_type.dart';
import '../models/cycle_model.dart';
import '../theme/app_theme.dart';
import 'weeks_in_cycle_screen.dart';
import 'historical_data_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wendler Log'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        children: [
          // 1RM Personal Records Section
          const _SectionHeader(title: '1RM Personal Records'),
          _OneRMSection(provider: provider),

          const SizedBox(height: 8),

          // Lifting Cycles Section
          const _SectionHeader(title: 'Lifting Cycles'),
          _CyclesSection(provider: provider),

          const SizedBox(height: 8),

          // Historical Data
          const _SectionHeader(title: 'Historical Data'),
          _HistoricalDataTile(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewCycle(context, provider),
        backgroundColor: AppTheme.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Future<void> _createNewCycle(BuildContext context, AppProvider provider) async {
    final newCycle = await provider.startNewCycle();

    if (!context.mounted) return;

    // Show "New Cycle Created" dialog
    await showDialog<void>(
      context: context,
      builder: (_) => _NewCycleDialog(cycle: newCycle, provider: provider),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _OneRMSection extends StatelessWidget {
  final AppProvider provider;
  const _OneRMSection({required this.provider});

  // Display order: Military Press, Back Squat, Bench Press, Deadlift
  static const _displayOrder = [
    LiftType.militaryPress,
    LiftType.backSquat,
    LiftType.benchPress,
    LiftType.deadlift,
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: Column(
        children: [
          for (int i = 0; i < _displayOrder.length; i++) ...[
            _OneRMRow(lift: _displayOrder[i], provider: provider),
            if (i < _displayOrder.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _OneRMRow extends StatelessWidget {
  final LiftType lift;
  final AppProvider provider;

  const _OneRMRow({required this.lift, required this.provider});

  @override
  Widget build(BuildContext context) {
    final summary = provider.get1RMSummary(lift);
    final tm = provider.getTrainingMax(lift);

    // Best 1RM to show: allTimePeak or fall back to TM
    String rmLabel;
    if (summary.allTimePeak != null) {
      final peak = summary.allTimePeak!;
      final peakInt = peak == peak.truncateToDouble() ? peak.toInt().toString() : peak.toStringAsFixed(1);
      rmLabel = '${peakInt}kg';
    } else {
      final tmInt = tm == tm.truncateToDouble() ? tm.toInt().toString() : tm.toStringAsFixed(1);
      rmLabel = '${tmInt}kg';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Trophy icon
          const Icon(Icons.emoji_events, color: AppTheme.gold, size: 22),
          const SizedBox(width: 12),
          // Lift name
          Expanded(
            child: Text(
              lift.displayName,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 1RM value
          Text(
            rmLabel,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CyclesSection extends StatelessWidget {
  final AppProvider provider;
  const _CyclesSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cycles = provider.allCycles;

    if (cycles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No cycles yet.\nTap + to create your first cycle.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final cycle in cycles)
          _CycleTile(cycle: cycle, provider: provider),
      ],
    );
  }
}

class _CycleTile extends StatelessWidget {
  final CycleModel cycle;
  final AppProvider provider;

  const _CycleTile({required this.cycle, required this.provider});

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Cycle?',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently delete this cycle and all its sessions.',
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
    if (confirmed == true && cycle.id != null) {
      await provider.deleteCycleById(cycle.id!);
      await provider.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(cycle.startDate);
    final pct = provider.getCyclePercentComplete(cycle);
    final pctLabel = '$pct% Complete';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: GestureDetector(
        onLongPress: () => _confirmDelete(context),
        child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WeeksInCycleScreen(cycle: cycle),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Cycle icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sync, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 14),
              // Date + % complete
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pctLabel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 22),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _HistoricalDataTile extends StatelessWidget {
  const _HistoricalDataTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
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

class _NewCycleDialog extends StatelessWidget {
  final CycleModel cycle;
  final AppProvider provider;

  const _NewCycleDialog({required this.cycle, required this.provider});

  String _fmtWeight(double v) {
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  // Display order: Military Press, Back Squat, Bench Press, Deadlift
  static const _displayOrder = [
    LiftType.militaryPress,
    LiftType.backSquat,
    LiftType.benchPress,
    LiftType.deadlift,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'New Cycle Created',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'One Rep Maxes:',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final lift in _displayOrder)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lift.displayName,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  Text(
                    '${_fmtWeight(provider.getTrainingMax(lift))}kg',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
          child: const Text(
            'OK',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
