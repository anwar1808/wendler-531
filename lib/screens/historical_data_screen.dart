import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/lift_type.dart';
import '../theme/app_theme.dart';
import '../services/wendler_calculator.dart';

const _liftColors = {
  'benchPress': Color(0xFFE8C547),
  'deadlift': Color(0xFFE87847),
  'militaryPress': Color(0xFF47A8E8),
  'backSquat': Color(0xFF78E847),
};

class HistoricalDataScreen extends StatefulWidget {
  const HistoricalDataScreen({super.key});

  @override
  State<HistoricalDataScreen> createState() => _HistoricalDataScreenState();
}

class _HistoricalDataScreenState extends State<HistoricalDataScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final raw = await db.getImportedHistoryEntries();
    setState(() {
      _entries = raw;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historical Data')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _entries.isEmpty
              ? const Center(
                  child: Text('No historical data.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final e = _entries[index];
                    return _HistoryRow(entry: e);
                  },
                ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final liftKey = entry['lift'] as String;
    final lift = LiftTypeExtension.fromDbKey(liftKey);
    final liftName = lift?.displayName ?? liftKey;
    final color = _liftColors[liftKey] ?? AppTheme.textSecondary;
    final weight = (entry['weight_kg'] as num).toDouble();
    final reps = entry['reps'] as int;
    final oneRm = (entry['one_rm'] as num).toDouble();
    final notes = (entry['notes'] as String?) ?? '';

    String dateLabel = entry['date'] as String;
    try {
      dateLabel = DateFormat('d MMM yyyy').format(DateTime.parse(dateLabel));
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colour dot
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      liftName,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${WendlerCalculator.formatWeight(weight)} × $reps  •  est. 1RM: ${oneRm.round()}kg',
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
                if (notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      notes,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const Divider(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
