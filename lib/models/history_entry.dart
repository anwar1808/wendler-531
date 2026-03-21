class HistoryEntry {
  final int? id;
  final String date;
  final String lift;
  final double weightKg;
  final int reps;
  final double oneRm;
  final String notes;
  final bool isImported;

  HistoryEntry({
    this.id,
    required this.date,
    required this.lift,
    required this.weightKg,
    required this.reps,
    required this.oneRm,
    this.notes = '',
    this.isImported = false,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'] as int?,
      date: map['date'] as String,
      lift: map['lift'] as String,
      weightKg: (map['weight_kg'] as num).toDouble(),
      reps: map['reps'] as int,
      oneRm: (map['one_rm'] as num).toDouble(),
      notes: map['notes'] as String? ?? '',
      isImported: (map['is_imported'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'lift': lift,
      'weight_kg': weightKg,
      'reps': reps,
      'one_rm': oneRm,
      'notes': notes,
      'is_imported': isImported ? 1 : 0,
    };
  }
}
