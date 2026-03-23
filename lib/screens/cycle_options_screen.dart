import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cycle_model.dart';
import '../models/lift_type.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class CycleOptionsScreen extends StatefulWidget {
  final CycleModel cycle;

  const CycleOptionsScreen({super.key, required this.cycle});

  @override
  State<CycleOptionsScreen> createState() => _CycleOptionsScreenState();
}

class _CycleOptionsScreenState extends State<CycleOptionsScreen> {
  late DateTime _startDate;
  late Map<LiftType, TextEditingController> _tmControllers;
  bool _saving = false;

  // Display order: Military Press, Back Squat, Bench Press, Deadlift
  static const _displayOrder = [
    LiftType.militaryPress,
    LiftType.backSquat,
    LiftType.benchPress,
    LiftType.deadlift,
  ];

  @override
  void initState() {
    super.initState();
    try {
      _startDate = DateTime.parse(widget.cycle.startDate);
    } catch (_) {
      _startDate = DateTime.now();
    }

    final provider = context.read<AppProvider>();
    _tmControllers = {
      for (final lift in _displayOrder)
        lift: TextEditingController(
          text: _fmtWeight(provider.getTrainingMax(lift)),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _tmControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmtWeight(double v) {
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  String _formatDate(DateTime dt) {
    return DateFormat('MMM d, yyyy').format(dt);
  }

  String get _liftLabel {
    return 'kg';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle Options'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cycle Start Date
                  _FieldRow(
                    label: 'Cycle Start Date',
                    valueWidget: InkWell(
                      onTap: () => _pickDate(context),
                      child: Text(
                        _formatDate(_startDate),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 24),

                  // Training maxes per lift
                  for (final lift in _displayOrder) ...[
                    _FieldRow(
                      label: '${lift.displayName} 1RM ($_liftLabel)',
                      valueWidget: SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _tmControllers[lift],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.accent),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (lift != _displayOrder.last)
                      const Divider(height: 16),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Bottom action buttons: Delete | Help | Save
          Row(
            children: [
              // Delete button
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, provider),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              // Help button
              OutlinedButton.icon(
                onPressed: () => _showHelp(context),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Help'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.textSecondary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const Spacer(),
              // Save button
              ElevatedButton.icon(
                onPressed: _saving ? null : () => _save(context, provider),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save(BuildContext context, AppProvider provider) async {
    setState(() => _saving = true);
    try {
      // Save start date
      final startDateStr = _startDate.toIso8601String().substring(0, 10);
      await provider.updateCycleStartDate(widget.cycle.id!, startDateStr);

      // Save training maxes
      for (final lift in _displayOrder) {
        final text = _tmControllers[lift]!.text.trim();
        final val = double.tryParse(text);
        if (val != null && val > 0) {
          await provider.updateTrainingMax(lift, val);
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cycle options saved.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Delete Cycle?'),
        content: const Text(
          'This will permanently delete this cycle and all its sessions. This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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
      await provider.deleteCycleById(widget.cycle.id!);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('About Wendler 5/3/1'),
        content: const SingleChildScrollView(
          child: Text(
            'Wendler 5/3/1 is a strength training programme by Jim Wendler.\n\n'
            '• Each cycle lasts 4 weeks (3 working weeks + 1 deload)\n'
            '• The 1RM values here are your Training Maxes (TM = ~90% of your true 1RM)\n'
            '• Each week uses different percentages of your TM\n'
            '  - Week 1: 65% × 5, 75% × 5, 85% × 5+\n'
            '  - Week 2: 70% × 3, 80% × 3, 90% × 3+\n'
            '  - Week 3: 75% × 5, 85% × 3, 95% × 1+\n'
            '  - Week 4 (Deload): 40% × 5, 50% × 5, 60% × 5\n'
            '• After completing a cycle, increase your TM by:\n'
            '  - Upper lifts (OHP, Bench): +2.5kg\n'
            '  - Lower lifts (Squat, Deadlift): +5kg',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget valueWidget;

  const _FieldRow({required this.label, required this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          valueWidget,
        ],
      ),
    );
  }
}
