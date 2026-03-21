import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/lift_type.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_chart.dart';
import 'import_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final Set<LiftType> _visible = {
    LiftType.backSquat,
    LiftType.benchPress,
    LiftType.deadlift,
    LiftType.militaryPress,
  };

  static const List<Color> _colors = [
    Color(0xFFE8C547),
    Color(0xFF64B5F6),
    Color(0xFF81C784),
    Color(0xFFFF8A65),
  ];

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
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import data',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Legend / toggle chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LiftType.values.map((lift) {
                final color = _colors[lift.index];
                final isOn = _visible.contains(lift);
                return FilterChip(
                  label: Text(
                    lift.displayName,
                    style: TextStyle(
                      color: isOn ? Colors.black : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  selected: isOn,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _visible.add(lift);
                      } else {
                        _visible.remove(lift);
                      }
                    });
                  },
                  selectedColor: color,
                  backgroundColor: AppTheme.surface,
                  checkmarkColor: Colors.black,
                  side: BorderSide(color: isOn ? color : Colors.transparent),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
              child: ProgressChart(data: data, visibleLifts: _visible),
            ),
          ),
        ],
      ),
    );
  }
}
