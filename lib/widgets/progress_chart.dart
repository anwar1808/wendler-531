import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/lift_type.dart';
import '../models/history_entry.dart';
import '../services/gap_interpolator.dart';
import '../theme/app_theme.dart';

// Per-lift colours as specified
const _liftColors = {
  LiftType.benchPress: Color(0xFFE8C547),
  LiftType.deadlift: Color(0xFFE87847),
  LiftType.militaryPress: Color(0xFF47A8E8),
  LiftType.backSquat: Color(0xFF78E847),
};

Color liftColor(LiftType l) => _liftColors[l] ?? Colors.white;

const Color _bodyweightColor = Color(0xFF9E9E9E);

class ProgressChart extends StatelessWidget {
  /// Full history for all lifts, keyed by lift type.
  final Map<LiftType, List<HistoryEntry>> data;
  final Set<LiftType> visibleLifts;
  final List<Map<String, dynamic>> bodyweightEntries;
  final bool showBodyweight;

  const ProgressChart({
    super.key,
    required this.data,
    required this.visibleLifts,
    this.bodyweightEntries = const [],
    this.showBodyweight = false,
  });

  @override
  Widget build(BuildContext context) {
    // Flatten all entries for the gap interpolator
    final allEntries = <HistoryEntry>[];
    for (final entries in data.values) {
      allEntries.addAll(entries);
    }

    final chartData = GapInterpolator.process(allEntries);

    // Determine axis bounds
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    void updateBounds(DateTime date, double value) {
      final x = date.millisecondsSinceEpoch.toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (value < minY) minY = value;
      if (value > maxY) maxY = value;
    }

    for (final lift in LiftType.values) {
      if (!visibleLifts.contains(lift)) continue;
      final lcd = chartData[lift];
      if (lcd == null) continue;
      for (final p in lcd.realPoints) {
        updateBounds(p.date, p.value);
      }
      for (final seg in lcd.gapSegments) {
        for (final p in seg) {
          updateBounds(p.date, p.value);
        }
      }
      for (final p in lcd.projectedPoints) {
        updateBounds(p.date, p.value);
      }
    }

    // Include bodyweight bounds if visible
    if (showBodyweight) {
      for (final e in bodyweightEntries) {
        final date = DateTime.tryParse(e['date'] as String);
        final w = e['weight_kg'] as double?;
        if (date != null && w != null) {
          updateBounds(date, w);
        }
      }
    }

    if (minX == double.infinity) {
      return const Center(
        child: Text(
          'No data yet.\nComplete some sessions to see your progress.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    final yPad = ((maxY - minY) * 0.12) + 10;
    final xPad = ((maxX - minX) * 0.05) + 86400000.0;

    final lineBarsData = <LineChartBarData>[];

    for (final lift in LiftType.values) {
      if (!visibleLifts.contains(lift)) continue;
      final lcd = chartData[lift];
      if (lcd == null) continue;
      final color = liftColor(lift);

      // --- Real segments (solid, full opacity, small dots) ---
      if (lcd.realPoints.isNotEmpty) {
        final solidSegs = _buildSolidSegments(lcd.realPoints);
        for (final seg in solidSegs) {
          if (seg.isEmpty) continue;
          lineBarsData.add(LineChartBarData(
            spots: seg
                .map((p) => FlSpot(
                      p.date.millisecondsSinceEpoch.toDouble(),
                      p.value,
                    ))
                .toList(),
            isCurved: false,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: color,
                strokeColor: AppTheme.background,
                strokeWidth: 1.5,
              ),
            ),
            dashArray: null,
          ));
        }
      }

      // --- Gap segments (dashed, 50% opacity) ---
      for (final seg in lcd.gapSegments) {
        if (seg.length < 2) continue;
        lineBarsData.add(LineChartBarData(
          spots: seg
              .map((p) => FlSpot(
                    p.date.millisecondsSinceEpoch.toDouble(),
                    p.value,
                  ))
              .toList(),
          isCurved: true,
          color: color.withValues(alpha: 0.5),
          barWidth: 2.0,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: [5, 5],
        ));
      }

      // --- Projection segment (dotted, 30% opacity, squat only) ---
      if (lcd.projectedPoints.length >= 2) {
        lineBarsData.add(LineChartBarData(
          spots: lcd.projectedPoints
              .map((p) => FlSpot(
                    p.date.millisecondsSinceEpoch.toDouble(),
                    p.value,
                  ))
              .toList(),
          isCurved: false,
          color: color.withValues(alpha: 0.3),
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: [2, 6],
        ));
      }
    }

    // --- Bodyweight line (dashed grey, always dashed) ---
    if (showBodyweight && bodyweightEntries.isNotEmpty) {
      final bwSpots = <FlSpot>[];
      for (final e in bodyweightEntries) {
        final date = DateTime.tryParse(e['date'] as String);
        final w = e['weight_kg'] as double?;
        if (date != null && w != null) {
          bwSpots.add(FlSpot(date.millisecondsSinceEpoch.toDouble(), w));
        }
      }
      bwSpots.sort((a, b) => a.x.compareTo(b.x));
      if (bwSpots.isNotEmpty) {
        lineBarsData.add(LineChartBarData(
          spots: bwSpots,
          isCurved: false,
          color: _bodyweightColor,
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: [4, 4],
        ));
      }
    }

    // Build lift name lookup for tooltips (bar color → lift)
    final liftByColor = <int, LiftType>{
      for (final lift in LiftType.values)
        liftColor(lift).toARGB32(): lift,
    };

    return LineChart(
      LineChartData(
        minX: minX - xPad,
        maxX: maxX + xPad,
        minY: minY - yPad,
        maxY: maxY + yPad,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.divider,
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: AppTheme.divider,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: _xInterval(minX, maxX),
              getTitlesWidget: (value, meta) {
                final dt =
                    DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    DateFormat('yyyy').format(dt),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    '${value.toInt()}kg',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: lineBarsData,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.card,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final dt =
                    DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                final barColor = spot.bar.color ?? Colors.white;
                // Match lift by full-opacity ARGB value
                final fullAlphaArgb = Color.fromARGB(
                  255,
                  barColor.r.round(),
                  barColor.g.round(),
                  barColor.b.round(),
                ).toARGB32();
                final matchedLift = liftByColor[fullAlphaArgb];
                final liftName = matchedLift?.displayName ?? '';
                return LineTooltipItem(
                  liftName.isNotEmpty
                      ? '$liftName\n${spot.y.toStringAsFixed(1)}kg\n${DateFormat('d MMM yy').format(dt)}'
                      : '${spot.y.toStringAsFixed(1)}kg\n${DateFormat('d MMM yy').format(dt)}',
                  TextStyle(
                    color: barColor.withValues(alpha: 1.0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  /// Split a sorted list of real points into sub-segments separated by gaps >30d.
  List<List<DataPoint>> _buildSolidSegments(List<DataPoint> pts) {
    if (pts.isEmpty) return [];
    final segs = <List<DataPoint>>[];
    var current = <DataPoint>[pts.first];
    for (int i = 1; i < pts.length; i++) {
      final gap = pts[i].date.difference(pts[i - 1].date).inDays;
      if (gap > GapInterpolator.gapThresholdDays) {
        segs.add(List.from(current));
        current = [pts[i]];
      } else {
        current.add(pts[i]);
      }
    }
    if (current.isNotEmpty) segs.add(current);
    return segs;
  }

  double _xInterval(double minX, double maxX) {
    final rangeDays = (maxX - minX) / 86400000.0;
    if (rangeDays < 60) return 7 * 86400000.0;
    if (rangeDays < 365) return 90 * 86400000.0;
    if (rangeDays < 730) return 180 * 86400000.0;
    return 365 * 86400000.0;
  }
}
