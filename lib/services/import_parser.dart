import '../models/history_entry.dart';
import '../models/lift_type.dart';
import '../services/wendler_calculator.dart';

class ParsedEntry {
  final String date;
  final LiftType lift;
  final double weightKg;
  final int reps;
  final double oneRm;
  final String notes;

  ParsedEntry({
    required this.date,
    required this.lift,
    required this.weightKg,
    required this.reps,
    required this.oneRm,
    required this.notes,
  });
}

class ImportParser {
  static List<ParsedEntry> parse(String rawText) {
    final entries = <ParsedEntry>[];
    final blocks = rawText.trim().split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      if (block.trim().isEmpty) continue;

      final lines = block.trim().split('\n');
      final fields = <String, String>{};

      for (final line in lines) {
        final colonIdx = line.indexOf(':');
        if (colonIdx < 0) continue;
        final key = line.substring(0, colonIdx).trim();
        final value = line.substring(colonIdx + 1).trim();
        fields[key] = value;
      }

      // Required fields
      final dateStr = fields['Date'];
      final liftStr = fields['Lift'];
      final weightStr = fields['Weight'];
      final scoreStr = fields['Score'];

      if (dateStr == null || liftStr == null || weightStr == null || scoreStr == null) continue;
      if (weightStr == 'N/A' || scoreStr == 'N/A') continue;

      // Parse lift
      final lift = LiftTypeExtension.fromDisplayName(liftStr);
      if (lift == null) continue;

      // Parse weight (strip " kg")
      final weightClean = weightStr.replaceAll(RegExp(r'[^\d.]'), '');
      final weight = double.tryParse(weightClean);
      if (weight == null) continue;

      // Parse reps
      final reps = int.tryParse(scoreStr);
      if (reps == null) continue;

      // Parse 1RM (use provided if available, else calculate)
      double oneRm;
      final oneRmStr = fields['1RM'];
      if (oneRmStr != null && oneRmStr != 'N/A') {
        final oneRmClean = oneRmStr.replaceAll(RegExp(r'[^\d.]'), '');
        oneRm = double.tryParse(oneRmClean) ?? WendlerCalculator.calcEpley1RM(weight, reps);
      } else {
        oneRm = WendlerCalculator.calcEpley1RM(weight, reps);
      }

      final notes = fields['Notes'] ?? '';

      // Parse date — supports M/D/YY or M/D/YYYY
      final date = _parseDate(dateStr);
      if (date == null) continue;

      entries.add(ParsedEntry(
        date: date,
        lift: lift,
        weightKg: weight,
        reps: reps,
        oneRm: oneRm,
        notes: notes,
      ));
    }

    // Sort by date ascending
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  static String? _parseDate(String raw) {
    // Format: M/D/YY or M/D/YYYY
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    var yearStr = parts[2].trim();
    int? year;
    if (yearStr.length == 2) {
      year = 2000 + (int.tryParse(yearStr) ?? 0);
    } else {
      year = int.tryParse(yearStr);
    }
    if (month == null || day == null || year == null) return null;
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  static List<HistoryEntry> toHistoryEntries(List<ParsedEntry> parsed) {
    return parsed.map((p) => HistoryEntry(
      date: p.date,
      lift: p.lift.dbKey,
      weightKg: p.weightKg,
      reps: p.reps,
      oneRm: p.oneRm,
      notes: p.notes,
      isImported: true,
    )).toList();
  }
}
