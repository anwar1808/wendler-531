import '../models/history_entry.dart';
import '../models/lift_type.dart';

class DataPoint {
  final DateTime date;
  final double value;
  final bool isReal;
  final bool isProjected;

  DataPoint({
    required this.date,
    required this.value,
    this.isReal = true,
    this.isProjected = false,
  });
}

/// Holds the processed data for a single lift ready for rendering.
class LiftChartData {
  final LiftType lift;
  final List<DataPoint> realPoints;
  final List<List<DataPoint>> gapSegments; // each inner list = one gap segment (dashed)
  final List<DataPoint> projectedPoints; // dotted line (squat only)

  LiftChartData({
    required this.lift,
    required this.realPoints,
    required this.gapSegments,
    required this.projectedPoints,
  });
}

class GapInterpolator {
  static const int gapThresholdDays = 30;
  static const int interpolationSteps = 20;

  /// Main entry point. Takes the full list of HistoryEntry objects,
  /// groups by lift, sorts, finds gaps, generates interpolated gap segments
  /// and a squat projection.
  static Map<LiftType, LiftChartData> process(List<HistoryEntry> allEntries) {
    // 1. Group and sort by lift
    final grouped = <LiftType, List<DataPoint>>{};
    for (final lift in LiftType.values) {
      grouped[lift] = [];
    }
    for (final e in allEntries) {
      final lift = LiftTypeExtension.fromDbKey(e.lift);
      if (lift == null) continue;
      final date = DateTime.tryParse(e.date);
      if (date == null) continue;
      grouped[lift]!.add(DataPoint(date: date, value: e.oneRm));
    }
    for (final lift in LiftType.values) {
      grouped[lift]!.sort((a, b) => a.date.compareTo(b.date));
    }

    // 2. Deduplicate: if same date appears multiple times, keep the highest 1RM
    for (final lift in LiftType.values) {
      final pts = grouped[lift]!;
      if (pts.isEmpty) continue;
      final deduped = <DateTime, double>{};
      for (final p in pts) {
        final key = DateTime(p.date.year, p.date.month, p.date.day);
        if (!deduped.containsKey(key) || p.value > deduped[key]!) {
          deduped[key] = p.value;
        }
      }
      grouped[lift] = deduped.entries
          .map((e) => DataPoint(date: e.key, value: e.value))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }

    // 3. Build bench lookup for squat projection
    final benchPoints = grouped[LiftType.benchPress] ?? [];

    // 4. Build LiftChartData for each lift
    final result = <LiftType, LiftChartData>{};
    for (final lift in LiftType.values) {
      final realPts = grouped[lift]!;
      final gapSegments = _buildGapSegments(realPts);
      final projectedPts = lift == LiftType.backSquat
          ? _buildSquatProjection(realPts, benchPoints)
          : <DataPoint>[];
      result[lift] = LiftChartData(
        lift: lift,
        realPoints: realPts,
        gapSegments: gapSegments,
        projectedPoints: projectedPts,
      );
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Gap segments: for each gap >30 days, produce ~20 bezier interpolated points
  // ---------------------------------------------------------------------------
  static List<List<DataPoint>> _buildGapSegments(List<DataPoint> realPts) {
    if (realPts.length < 2) return [];
    final segments = <List<DataPoint>>[];

    for (int i = 0; i < realPts.length - 1; i++) {
      final p0 = realPts[i];
      final p1 = realPts[i + 1];
      final gapDays = p1.date.difference(p0.date).inDays;
      if (gapDays <= gapThresholdDays) continue;

      // Quadratic bezier: P0=(0,v1), P1=(0.35, floor), P2=(1.0,v2)
      final v1 = p0.value;
      final v2 = p1.value;
      final vMid = (v1 + v2) / 2.0;
      final dipDepth =
          (((v2 - v1).abs() * 0.3) + (gapDays / 365.0) * 0.05 * (v1 < v2 ? v1 : v2)) * 0.4;
      final floor = vMid - dipDepth;
      // Control point at t=0.35
      const tCtrl = 0.35;

      final segmentPts = <DataPoint>[];
      // Start with the real anchor (so lines connect cleanly)
      segmentPts.add(DataPoint(date: p0.date, value: p0.value, isReal: false));

      for (int s = 1; s <= interpolationSteps; s++) {
        final t = s / interpolationSteps.toDouble();
        // Bezier B(t) = (1-t)^2*P0 + 2*(1-t)*t*P1 + t^2*P2
        // x-axis: 0..1 mapped, control x = tCtrl
        // value:
        final bVal = (1 - t) * (1 - t) * v1 +
            2 * (1 - t) * t * floor +
            t * t * v2;

        // Interpolate the date
        final totalMs = p1.date.millisecondsSinceEpoch - p0.date.millisecondsSinceEpoch;
        final tAdjusted = _bezierX(t, tCtrl);
        final dateMs = p0.date.millisecondsSinceEpoch + (totalMs * tAdjusted).round();
        final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
        segmentPts.add(DataPoint(date: date, value: bVal, isReal: false));
      }
      // End anchor
      segmentPts.add(DataPoint(date: p1.date, value: p1.value, isReal: false));

      segments.add(segmentPts);
    }
    return segments;
  }

  /// Simple linear x progression for the bezier (the control point x is just
  /// used for the value curve, not for the date — date is always linear).
  static double _bezierX(double t, double ctrlX) {
    // We only use bezier for the y-axis (value); x (time) stays linear.
    return t;
  }

  // ---------------------------------------------------------------------------
  // Squat projection: use bench press % change as proxy
  // ---------------------------------------------------------------------------
  static List<DataPoint> _buildSquatProjection(
      List<DataPoint> squatPts, List<DataPoint> benchPts) {
    if (squatPts.isEmpty || benchPts.isEmpty) return [];

    final lastSquat = squatPts.last;
    final lastSquatDate = lastSquat.date;

    // Find bench value at (or just before) the squat's last date
    DataPoint? benchAtSquatDate;
    for (final b in benchPts) {
      if (!b.date.isAfter(lastSquatDate)) {
        benchAtSquatDate = b;
      }
    }
    if (benchAtSquatDate == null) return [];

    final benchBase = benchAtSquatDate.value;
    if (benchBase == 0) return [];

    // Collect bench points strictly after squat's last date (and up to today)
    final today = DateTime.now();
    final futureBenchPts = benchPts
        .where((b) => b.date.isAfter(lastSquatDate) && !b.date.isAfter(today))
        .toList();
    if (futureBenchPts.isEmpty) return [];

    final projected = <DataPoint>[];
    // Anchor at last squat point
    projected.add(DataPoint(
        date: lastSquat.date,
        value: lastSquat.value,
        isReal: false,
        isProjected: true));

    for (final b in futureBenchPts) {
      final pctChange = (b.value - benchBase) / benchBase;
      final projectedValue = lastSquat.value * (1.0 + pctChange);
      projected.add(DataPoint(
          date: b.date,
          value: projectedValue,
          isReal: false,
          isProjected: true));
    }
    return projected;
  }
}
