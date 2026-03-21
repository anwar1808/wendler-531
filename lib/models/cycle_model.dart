class CycleModel {
  final int? id;
  final int number;
  final String startDate;
  final bool isComplete;

  CycleModel({
    this.id,
    required this.number,
    required this.startDate,
    this.isComplete = false,
  });

  factory CycleModel.fromMap(Map<String, dynamic> map) {
    return CycleModel(
      id: map['id'] as int?,
      number: map['number'] as int,
      startDate: map['start_date'] as String,
      isComplete: (map['is_complete'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'number': number,
      'start_date': startDate,
      'is_complete': isComplete ? 1 : 0,
    };
  }

  CycleModel copyWith({bool? isComplete}) {
    return CycleModel(
      id: id,
      number: number,
      startDate: startDate,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
