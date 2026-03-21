import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/lift_type.dart';
import '../models/history_entry.dart';
import '../services/gap_interpolator.dart';
import '../theme/app_theme.dart';

class ProgressChart extends StatelessWidget {
  final Map<LiftType, List<HistoryEntry>> data;
  final Set<LiftType> visibleLifts;

  const ProgressChart({
    super.key,
    required this.data,
    required this.visibleLifts,
  });

  static const List<Color> liftColors = [
    Color(0xFFE8C547), // accent yellow — backSquat
    Color(0xFF64B5F6), // blue — benchPress
    Color(0xFF81C784), // green — deadlift
    Color(0xFFFF8A65), // orange — militaryPress
  ];

  Color colorForLift(LiftType lift) {
    return liftColors[lift.index % liftColors.length];
  }

  @override
  Widget build(BuildContext context) {
    // Collect all dates across visible lifts for x-axis
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    final liftSegments = <LiftType, List<List<DataPoint>>>{};

    for (final lift in LiftType.values) {
      if (!visibleLifts.contains(lift)) continue;
      final entries = data[lift] ?? [];
      if (entries.isEmpty) continue;

      final realPoints = entries.map((e) {
        final dt = DateTime.tryParse(e.date) ?? DateTime.now();
        return DataPoint(date: dt, value: e.oneRm);
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final interpolated = GapInterpolator.interpolate(realPoints);
      liftSegments[lift] = GapInterpolator.toSegments(interpolated);

      for (final p in interpolated) {
        final x = p.date.millisecondsSinceEpoch.toDouble();
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (p.value < minY) minY = p.value;
        if (p.value > maxY) maxY = p.value;
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

    final yPad = (maxY - minY) * 0.1 + 10;
    final xPad = (maxX - minX) * 0.05 + 86400000.0;

    final lineBarsData = <LineChartBarData>[];

    for (final lift in LiftType.values) {
      if (!visibleLifts.contains(lift)) continue;
      final segments = liftSegments[lift];
      if (segments == null || segments.isEmpty) continue;
      final color = colorForLift(lift);

      for (final segment in segments) {
        if (segment.isEmpty) continue;
        final isReal = segment.first.isReal;
        final spots = segment.map((p) => FlSpot(
          p.date.millisecondsSinceEpoch.toDouble(),
          p.value,
        )).toList();

        lineBarsData.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: isReal,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 4,
              color: color,
              strokeColor: AppTheme.background,
              strokeWidth: 1.5,
            ),
          ),
          dashArray: isReal ? null : [6, 4],
        ));
      }
    }

    return LineChart(
      LineChartData(
        minX: minX - xPad,
        maxX: maxX + xPad,
        minY: minY - yPad,
        maxY: maxY + yPad,
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
                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    DateFormat('MMM yy').format(dt),
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
                    '${value.toInt()}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: lineBarsData,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.card,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final dt = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                return LineTooltipItem(
                  '${DateFormat('d MMM yy').format(dt)}\n${spot.y.toStringAsFixed(1)}kg',
                  TextStyle(
                    color: spot.bar.color,
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

  double _xInterval(double minX, double maxX) {
    final rangeDays = (maxX - minX) / 86400000.0;
    if (rangeDays < 60) return 7 * 86400000.0;
    if (rangeDays < 180) return 30 * 86400000.0;
    if (rangeDays < 730) return 90 * 86400000.0;
    return 180 * 86400000.0;
  }
}
