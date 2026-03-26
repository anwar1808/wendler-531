import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/app_provider.dart';
import '../models/lift_type.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_chart.dart';
import 'import_screen.dart';

// Canonical lift colours (matches progress_chart.dart)
const _liftColors = {
  LiftType.benchPress: Color(0xFFE8C547),
  LiftType.deadlift: Color(0xFFE87847),
  LiftType.militaryPress: Color(0xFF47A8E8),
  LiftType.backSquat: Color(0xFF78E847),
};

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  // All 4 lifts visible by default
  final Set<LiftType> _hiddenLifts = {};
  // Bodyweight hidden by default
  bool _showBodyweight = false;
  // Filter: null = all time, 6 = last 6 weeks, 12 = last 12 weeks
  int? _filterWeeks;

  void _toggleLift(LiftType lift) {
    setState(() {
      if (_hiddenLifts.contains(lift)) {
        _hiddenLifts.remove(lift);
      } else {
        _hiddenLifts.add(lift);
      }
    });
  }

  void _toggleBodyweight() {
    setState(() {
      _showBodyweight = !_showBodyweight;
    });
  }

  void _showFilterSheet(BuildContext context) {
    int? selected = _filterWeeks;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Graph',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _FilterOption(
                label: 'Last 6 weeks',
                value: 6,
                groupValue: selected,
                onChanged: (v) => setSheetState(() => selected = v),
              ),
              _FilterOption(
                label: 'Last 12 weeks',
                value: 12,
                groupValue: selected,
                onChanged: (v) => setSheetState(() => selected = v),
              ),
              _FilterOption(
                label: 'All time',
                value: null,
                groupValue: selected,
                onChanged: (v) => setSheetState(() => selected = v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _filterWeeks = selected);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Show'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, AppProvider provider) async {
    try {
      final entries = provider.historyEntries;
      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export.')),
        );
        return;
      }

      final buf = StringBuffer();
      buf.writeln('date,lift,weight_kg,reps,one_rm,notes,is_imported');
      for (final e in entries) {
        final notes = e.notes.replaceAll('"', '""');
        buf.writeln('${e.date},${e.lift},${e.weightKg},${e.reps},${e.oneRm},"$notes",${e.isImported ? 1 : 0}');
      }

      final dir = await getExternalStorageDirectory();
      final timestamp = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir!.path}/wendler_export_$timestamp.csv');
      await file.writeAsString(buf.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${entries.length} entries to ${file.path}'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Set<LiftType> get _visibleLifts {
    return LiftType.values.where((l) => !_hiddenLifts.contains(l)).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    final data = {
      for (final lift in LiftType.values)
        lift: provider.getHistoryForLift(lift),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import data',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.upload),
            tooltip: 'Export data',
            onPressed: () => _exportData(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chart
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: ProgressChart(
                data: data,
                visibleLifts: _visibleLifts,
                bodyweightEntries: provider.bodyweightEntries,
                showBodyweight: _showBodyweight,
                filterStart: _filterWeeks == null
                    ? null
                    : DateTime.now().subtract(Duration(days: _filterWeeks! * 7)),
              ),
            ),
          ),

          // Lift toggle chips
          _LiftToggleRow(
            hiddenLifts: _hiddenLifts,
            onToggle: _toggleLift,
            showBodyweight: _showBodyweight,
            onToggleBodyweight: _toggleBodyweight,
          ),

          const Divider(height: 1),

          // Summary table
          _SummaryTable(
            provider: provider,
            visibleLifts: _visibleLifts,
          ),
        ],
      ),
    );
  }
}

/// Row of lift name chips at the bottom of the chart area.
/// Long-press to toggle visibility; short tap shows a tooltip hint.
class _LiftToggleRow extends StatelessWidget {
  final Set<LiftType> hiddenLifts;
  final ValueChanged<LiftType> onToggle;
  final bool showBodyweight;
  final VoidCallback onToggleBodyweight;

  const _LiftToggleRow({
    required this.hiddenLifts,
    required this.onToggle,
    required this.showBodyweight,
    required this.onToggleBodyweight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ...LiftType.values.map((lift) {
            final hidden = hiddenLifts.contains(lift);
            final color = _liftColors[lift] ?? Colors.white;
            return GestureDetector(
                onTap: () => onToggle(lift),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: hidden ? 0.35 : 1.0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: hidden ? AppTheme.textSecondary : color,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color: hidden
                          ? Colors.transparent
                          : color.withValues(alpha: 0.12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: hidden ? AppTheme.textSecondary : color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _shortName(lift),
                          style: TextStyle(
                            color: hidden ? AppTheme.textSecondary : color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            );
          }),
          // Bodyweight chip — tap to toggle
          GestureDetector(
              onTap: onToggleBodyweight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: showBodyweight ? 1.0 : 0.35,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: showBodyweight
                          ? AppTheme.textSecondary
                          : AppTheme.textSecondary,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    color: showBodyweight
                        ? AppTheme.textSecondary.withValues(alpha: 0.12)
                        : Colors.transparent,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Body Wt',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }

  String _shortName(LiftType lift) {
    switch (lift) {
      case LiftType.backSquat:
        return 'Squat';
      case LiftType.benchPress:
        return 'Bench';
      case LiftType.deadlift:
        return 'Deadlift';
      case LiftType.militaryPress:
        return 'OHP';
    }
  }
}

// ---------------------------------------------------------------------------
// Summary table (unchanged from previous version, kept below the chips)
// ---------------------------------------------------------------------------

class _SummaryTable extends StatelessWidget {
  final AppProvider provider;
  final Set<LiftType> visibleLifts;

  const _SummaryTable({
    required this.provider,
    required this.visibleLifts,
  });

  @override
  Widget build(BuildContext context) {
    final liftsToShow =
        LiftType.values.where((l) => visibleLifts.contains(l)).toList();

    return Container(
      color: AppTheme.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text(
                    'LIFT',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'RECENT 1RM',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'PEAK',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          for (int i = 0; i < liftsToShow.length; i++) ...[
            _SummaryRow(
              lift: liftsToShow[i],
              provider: provider,
              color: _liftColors[liftsToShow[i]] ?? Colors.white,
            ),
            if (i < liftsToShow.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final LiftType lift;
  final AppProvider provider;
  final Color color;

  const _SummaryRow({
    required this.lift,
    required this.provider,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final summary = provider.get1RMSummary(lift);
    final hasData = summary.allTimePeak != null;

    String recentLabel;
    if (!hasData) {
      recentLabel = 'No data';
    } else {
      final min = summary.recentMin!;
      final max = summary.recentMax!;
      final dateRange = summary.recentDateRange ?? '';
      if ((max - min).abs() < 0.5) {
        recentLabel = '${_fmt(max)}kg';
      } else {
        recentLabel = '${_fmt(min)}–${_fmt(max)}kg';
      }
      if (dateRange.isNotEmpty) recentLabel += ' ($dateRange)';
    }

    final peakLabel = hasData
        ? '${_fmt(summary.allTimePeak!)}kg\n(${summary.peakDate ?? ''})'
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6, top: 3),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    lift.displayName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              recentLabel,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              peakLabel,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.round().toString();
}

class _FilterOption extends StatelessWidget {
  final String label;
  final int? value;
  final int? groupValue;
  final ValueChanged<int?> onChanged;

  const _FilterOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Radio<int?>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: AppTheme.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
