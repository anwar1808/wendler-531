class DataPoint {
  final DateTime date;
  final double value;
  final bool isReal;

  DataPoint({required this.date, required this.value, this.isReal = true});
}

class GapInterpolator {
  static const int gapThresholdDays = 30;

  /// Takes a sorted list of real data points and returns a list with
  /// interpolated points inserted in gaps > 30 days.
  /// Each point carries an [isReal] flag.
  static List<DataPoint> interpolate(List<DataPoint> realPoints) {
    if (realPoints.length < 2) return realPoints;

    final result = <DataPoint>[];
    result.add(realPoints.first);

    for (int i = 1; i < realPoints.length; i++) {
      final prev = realPoints[i - 1];
      final curr = realPoints[i];
      final gapDays = curr.date.difference(prev.date).inDays;

      if (gapDays > gapThresholdDays) {
        // Insert a midpoint
        final midDate = prev.date.add(Duration(days: gapDays ~/ 2));
        final midValue = (prev.value + curr.value) / 2.0;
        result.add(DataPoint(date: midDate, value: midValue, isReal: false));
      }

      result.add(curr);
    }

    return result;
  }

  /// Returns segments: each segment is a list of DataPoints that should
  /// be drawn with the same line style (solid for real, dashed for interpolated).
  /// A dashed segment is created between a real point and the interpolated midpoint,
  /// and from the midpoint to the next real point.
  static List<List<DataPoint>> toSegments(List<DataPoint> points) {
    if (points.isEmpty) return [];
    final segments = <List<DataPoint>>[];
    var current = <DataPoint>[points.first];

    for (int i = 1; i < points.length; i++) {
      final p = points[i];
      if (p.isReal == current.first.isReal) {
        current.add(p);
      } else {
        // Bridge the segments — repeat the boundary point
        current.add(p);
        segments.add(List.from(current));
        current = [p];
      }
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }
}
