import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/study_stats.dart';
import '../utils/format.dart';

/// Günlük çalışma dakikalarının sütun grafiği; hedef kesikli çizgiyle gösterilir.
///
/// [minutes] listesindeki her eleman [start] gününden itibaren bir günü temsil
/// eder. 7 gün için gün adları, daha uzun aralıklar için gün numaraları yazılır.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.start, required this.minutes, required this.goal});

  final DateTime start;
  final List<int> minutes;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    final maxValue = [...minutes, goal, 60].fold<int>(0, math.max);
    // Eksen çizgileri "yuvarlak" sürelere denk gelsin: 30 dk, 1 sa, 2 sa...
    final step = _niceStep(maxValue / 3);
    final maxY = ((maxValue * 1.08 / step).ceil() * step).toDouble();
    final compact = minutes.length > 7;
    final barWidth = compact ? 6.0 : 18.0;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step.toDouble(),
          getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.6), strokeWidth: 1),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (goal > 0)
              HorizontalLine(
                y: goal.toDouble(),
                color: scheme.tertiary.withValues(alpha: 0.8),
                strokeWidth: 1.5,
                dashArray: const [6, 4],
              ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: step.toDouble(),
              getTitlesWidget: (value, meta) {
                if (value == 0 || value % step != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    formatMinutesShort(value),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10.5),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final day = addDays(start, i);
                // Uzun aralıkta her gün yazılırsa sığmaz: 5 günde bir yaz.
                if (compact && i % 5 != 0 && i != minutes.length - 1) return const SizedBox.shrink();
                final isToday = day == today;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    compact ? '${day.day}' : formatWeekdayShort(day),
                    style: TextStyle(
                      color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${formatDateShort(addDays(start, group.x))}\n',
              TextStyle(color: scheme.onInverseSurface, fontSize: 11),
              children: [
                TextSpan(
                  text: formatMinutes(minutes[group.x]),
                  style: TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < minutes.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: minutes[i].toDouble(),
                  width: barWidth,
                  color: goal > 0 && minutes[i] >= goal ? const Color(0xFF10B981) : scheme.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(compact ? 3 : 6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: !compact,
                    toY: maxY,
                    color: scheme.primary.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static int _niceStep(double raw) {
    for (final s in const [15, 30, 60, 90, 120, 180, 240, 360, 480]) {
      if (raw <= s) return s;
    }
    return 600;
  }
}
