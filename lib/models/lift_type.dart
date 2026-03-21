enum LiftType {
  backSquat,
  benchPress,
  deadlift,
  militaryPress,
}

extension LiftTypeExtension on LiftType {
  String get displayName {
    switch (this) {
      case LiftType.backSquat:
        return 'Back Squat';
      case LiftType.benchPress:
        return 'Bench Press';
      case LiftType.deadlift:
        return 'Deadlift';
      case LiftType.militaryPress:
        return 'Military Press';
    }
  }

  String get dbKey {
    switch (this) {
      case LiftType.backSquat:
        return 'backSquat';
      case LiftType.benchPress:
        return 'benchPress';
      case LiftType.deadlift:
        return 'deadlift';
      case LiftType.militaryPress:
        return 'militaryPress';
    }
  }

  bool get isLower {
    return this == LiftType.backSquat || this == LiftType.deadlift;
  }

  double get tmIncrement {
    return isLower ? 5.0 : 2.5;
  }

  static LiftType? fromDbKey(String key) {
    for (final lift in LiftType.values) {
      if (lift.dbKey == key) return lift;
    }
    return null;
  }

  static LiftType? fromDisplayName(String name) {
    final cleaned = name.replaceAll(RegExp(r'\s*\(Deload\)\s*', caseSensitive: false), '').trim();
    for (final lift in LiftType.values) {
      if (lift.displayName.toLowerCase() == cleaned.toLowerCase()) return lift;
    }
    return null;
  }
}
