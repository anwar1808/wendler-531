class SessionModel {
  final int? id;
  final int cycleId;
  final int week;
  final String sessionType; // 'mon' or 'thu'
  final String date;
  final String notes;
  final bool isComplete;

  SessionModel({
    this.id,
    required this.cycleId,
    required this.week,
    required this.sessionType,
    required this.date,
    this.notes = '',
    this.isComplete = false,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'] as int?,
      cycleId: map['cycle_id'] as int,
      week: map['week'] as int,
      sessionType: map['session_type'] as String,
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
      'session_type': sessionType,
      'date': date,
      'notes': notes,
      'is_complete': isComplete ? 1 : 0,
    };
  }

  SessionModel copyWith({String? notes, bool? isComplete, String? date}) {
    return SessionModel(
      id: id,
      cycleId: cycleId,
      week: week,
      sessionType: sessionType,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  List<String> get liftKeys {
    if (sessionType == 'mon') return ['backSquat', 'benchPress'];
    return ['deadlift', 'militaryPress'];
  }
}
