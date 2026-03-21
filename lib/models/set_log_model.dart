class SetLogModel {
  final int? id;
  final int sessionId;
  final String lift;
  final int setNumber;
  final double prescribedWeight;
  final int prescribedReps;
  final int? actualReps;
  final bool isComplete;
  final bool isAmrap;

  SetLogModel({
    this.id,
    required this.sessionId,
    required this.lift,
    required this.setNumber,
    required this.prescribedWeight,
    required this.prescribedReps,
    this.actualReps,
    this.isComplete = false,
    this.isAmrap = false,
  });

  factory SetLogModel.fromMap(Map<String, dynamic> map) {
    return SetLogModel(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      lift: map['lift'] as String,
      setNumber: map['set_number'] as int,
      prescribedWeight: (map['prescribed_weight'] as num).toDouble(),
      prescribedReps: map['prescribed_reps'] as int,
      actualReps: map['actual_reps'] as int?,
      isComplete: (map['is_complete'] as int) == 1,
      isAmrap: (map['is_amrap'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'lift': lift,
      'set_number': setNumber,
      'prescribed_weight': prescribedWeight,
      'prescribed_reps': prescribedReps,
      'actual_reps': actualReps,
      'is_complete': isComplete ? 1 : 0,
      'is_amrap': isAmrap ? 1 : 0,
    };
  }

  SetLogModel copyWith({bool? isComplete, int? actualReps}) {
    return SetLogModel(
      id: id,
      sessionId: sessionId,
      lift: lift,
      setNumber: setNumber,
      prescribedWeight: prescribedWeight,
      prescribedReps: prescribedReps,
      actualReps: actualReps ?? this.actualReps,
      isComplete: isComplete ?? this.isComplete,
      isAmrap: isAmrap,
    );
  }

  String get repsLabel {
    if (isAmrap) {
      return '$prescribedReps+';
    }
    return '$prescribedReps';
  }
}
