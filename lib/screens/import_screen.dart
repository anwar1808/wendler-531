import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/lift_type.dart';
import '../providers/app_provider.dart';
import '../services/import_parser.dart';
import '../theme/app_theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ParsedEntry>? _preview;
  String? _error;
  bool _importing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste your data above first.');
      return;
    }
    try {
      final entries = ImportParser.parse(text);
      if (entries.isEmpty) {
        setState(() {
          _error = 'No valid entries found. Check your format.';
          _preview = null;
        });
      } else {
        setState(() {
          _preview = entries;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Parse error: $e';
        _preview = null;
      });
    }
  }

  Future<void> _confirmImport() async {
    if (_preview == null || _preview!.isEmpty) return;
    setState(() => _importing = true);

    final historyEntries = ImportParser.toHistoryEntries(_preview!);
    final provider = context.read<AppProvider>();
    await provider.importHistoryEntries(historyEntries);

    if (mounted) {
      setState(() {
        _importing = false;
        _preview = null;
        _controller.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${historyEntries.length} entries imported. Training maxes updated.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline, color: AppTheme.accent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Paste Format',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Date: 9/25/24\n'
                  'Lift: Bench Press\n'
                  'Weight: 57.5 kg\n'
                  'Score: 15\n'
                  '1RM: 86 kg\n'
                  'Notes: some text\n\n'
                  'Separate entries with a blank line.\n'
                  'Entries with Weight/Score = N/A are skipped.\n'
                  'Supported lifts: Back Squat, Bench Press, Deadlift, Military Press.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Text area
          TextField(
            controller: _controller,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Paste your training log here...',
              alignLabelWithHint: true,
            ),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
            onChanged: (_) {
              if (_preview != null || _error != null) {
                setState(() {
                  _preview = null;
                  _error = null;
                });
              }
            },
          ),
          const SizedBox(height: 12),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),

          // Parse button
          ElevatedButton.icon(
            onPressed: _parse,
            icon: const Icon(Icons.search),
            label: const Text('Parse & Preview'),
          ),

          // Preview
          if (_preview != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'PREVIEW',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_preview!.length} entries',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 2,
                          child: Text('Date',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('Lift',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Weight',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('Reps',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('1RM',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _preview!.length,
                    separatorBuilder: (context2, idx2) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = _preview![index];
                      String dateLabel = entry.date;
                      try {
                        final dt = DateTime.parse(entry.date);
                        dateLabel = DateFormat('d MMM yy').format(dt);
                      } catch (_) {}
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                dateLabel,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                entry.lift.displayName, // uses LiftTypeExtension
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${entry.weightKg}kg',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${entry.reps}',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${entry.oneRm.toStringAsFixed(1)}kg',
                                style: const TextStyle(
                                    color: AppTheme.accent, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _importing ? null : _confirmImport,
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.download_done),
              label: Text(_importing ? 'Importing...' : 'Confirm Import'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
