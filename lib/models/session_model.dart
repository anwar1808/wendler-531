class SessionModel {
  final int? id;
  final int cycleId;
  final int week;
  final String lifts; // comma-separated liftKeys, e.g. "backSquat,benchPress"
  final String date;
  final String notes;
  final bool isComplete;

  SessionModel({
    this.id,
    required this.cycleId,
    required this.week,
    required this.lifts,
    required this.date,
    this.notes = '',
    this.isComplete = false,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    // Support legacy 'session_type' rows (mon/thu) during migration
    final rawLifts = map['lifts'] as String?;
    final sessionType = map['session_type'] as String?;
    String resolvedLifts;
    if (rawLifts != null && rawLifts.isNotEmpty) {
      resolvedLifts = rawLifts;
    } else if (sessionType == 'mon') {
      resolvedLifts = 'backSquat,benchPress';
    } else if (sessionType == 'thu') {
      resolvedLifts = 'deadlift,militaryPress';
    } else {
      resolvedLifts = rawLifts ?? '';
    }

    return SessionModel(
      id: map['id'] as int?,
      cycleId: map['cycle_id'] as int,
      week: map['week'] as int,
      lifts: resolvedLifts,
      date: map['date'] as String,
      notes: map['notes'] as String? ?? '',
      isComplete: (map['is_complete'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cycle_id': cycleId,
      'week': week,
      'lifts': lifts,
      'date': date,
      'notes': notes,
      'is_complete': isComplete ? 1 : 0,
    };
  }

  SessionModel copyWith({
    String? notes,
    bool? isComplete,
    String? date,
    String? lifts,
  }) {
    return SessionModel(
      id: id,
      cycleId: cycleId,
      week: week,
      lifts: lifts ?? this.lifts,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  List<String> get liftKeys {
    return lifts.split(',').where((s) => s.isNotEmpty).toList();
  }
}
