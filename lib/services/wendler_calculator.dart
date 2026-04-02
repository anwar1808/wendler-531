import '../models/lift_type.dart';

class WendlerSet {
  final double weight;
  final int reps;
  final bool isAmrap;

  WendlerSet({required this.weight, required this.reps, this.isAmrap = false});
}

class WendlerCalculator {
  static double roundToNearest2_5(double value) {
    return (value / 2.5).ceil() * 2.5;
  }

  // For TM reductions: floor so the decrease isn't swallowed by rounding up.
  static double roundDownToNearest2_5(double value) {
    return (value / 2.5).floor() * 2.5;
  }

  static double calcTrainingMax(double oneRm) {
    return roundToNearest2_5(oneRm * 0.85);
  }

  static double calcEpley1RM(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  static List<WendlerSet> getSetsForWeek(int week, double tm) {
    switch (week) {
      case 1:
        return [
          WendlerSet(weight: roundToNearest2_5(tm * 0.65), reps: 5),
          WendlerSet(weight: roundToNearest2_5(tm * 0.75), reps: 5),
          WendlerSet(weight: roundToNearest2_5(tm * 0.85), reps: 5, isAmrap: true),
        ];
      case 2:
        return [
          WendlerSet(weight: roundToNearest2_5(tm * 0.70), reps: 3),
          WendlerSet(weight: roundToNearest2_5(tm * 0.80), reps: 3),
          WendlerSet(weight: roundToNearest2_5(tm * 0.90), reps: 3, isAmrap: true),
        ];
      case 3:
        return [
          WendlerSet(weight: roundToNearest2_5(tm * 0.75), reps: 5),
          WendlerSet(weight: roundToNearest2_5(tm * 0.85), reps: 3),
          WendlerSet(weight: roundToNearest2_5(tm * 0.95), reps: 1, isAmrap: true),
        ];
      case 4: // deload
        return [
          WendlerSet(weight: roundToNearest2_5(tm * 0.40), reps: 5),
          WendlerSet(weight: roundToNearest2_5(tm * 0.50), reps: 5),
          WendlerSet(weight: roundToNearest2_5(tm * 0.60), reps: 5),
        ];
      default:
        return [];
    }
  }

  static double incrementTm(LiftType lift, double currentTm) {
    return currentTm + lift.tmIncrement;
  }

  static String formatWeight(double kg) {
    if (kg == kg.truncateToDouble()) {
      return '${kg.toInt()}kg';
    }
    return '${kg.toStringAsFixed(1)}kg';
  }
}
