class TrainingMax {
  final int? id;
  final String lift;
  final double valueKg;
  final String updatedAt;

  TrainingMax({
    this.id,
    required this.lift,
    required this.valueKg,
    required this.updatedAt,
  });

  factory TrainingMax.fromMap(Map<String, dynamic> map) {
    return TrainingMax(
      id: map['id'] as int?,
      lift: map['lift'] as String,
      valueKg: (map['value_kg'] as num).toDouble(),
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'lift': lift,
      'value_kg': valueKg,
      'updated_at': updatedAt,
    };
  }

  TrainingMax copyWith({double? valueKg, String? updatedAt}) {
    return TrainingMax(
      id: id,
      lift: lift,
      valueKg: valueKg ?? this.valueKg,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
