import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/course.dart';
import '../../models/study_session.dart';
import '../../services/study_stats.dart';
import '../../state/data_controllers.dart';
import '../../state/settings_controller.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/week_bars.dart';

enum StatsPeriod { week, month }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsPeriod _period = StatsPeriod.week;

  /// 0: bu hafta/ay, -1: önceki...
  int _offset = 0;

  (DateTime, int) _range(DateTime now) {
    if (_period == StatsPeriod.week) {
      return (addDays(startOfWeek(now), 7 * _offset), 7);
    }
    final start = DateTime(now.year, now.month + _offset);
    final days = DateTime(start.year, start.month + 1, 0).day;
    return (start, days);
  }

  String _title(DateTime start, int days) {
    if (_period == StatsPeriod.month) return DateFormat('MMMM y', 'tr_TR').format(start);
    if (_offset == 0) return 'Bu hafta';
    if (_offset == -1) return 'Geçen hafta';
    return '${formatDateShort(start)} – ${formatDateShort(addDays(start, days - 1))}';
  }

  @override
  Widget build(BuildContext context) {
    final allSessions = context.watch<SessionController>().sessions;
    final courses = context.watch<CourseController>().courses;
    final tasks = context.watch<TaskController>().tasks;
    final goal = context.select<SettingsController, int>((s) => s.settings.dailyGoalMinutes);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final (start, days) = _range(now);
    final end = addDays(start, days);
    final sessions = allSessions.where((s) => !s.start.isBefore(start) && s.start.isBefore(end)).toList();
    final daily = StudyStats.dailyTotals(sessions, start, days);
    final total = daily.fold(0, (a, b) => a + b);
    // Ortalama yalnızca geçmiş günlere bölünür (ayın kalanı ortalamayı düşürmesin).
    final elapsedDays = now.isBefore(end) ? math.max(1, dateOnly(now).difference(start).inDays + 1) : days;
    final average = total / elapsedDays;
    final goalDays = StudyStats.goalDays(sessions, goal, start, days);
    final prevStart = _period == StatsPeriod.week ? addDays(start, -7) : DateTime(start.year, start.month - 1);
    // Süren dönem, önceki dönemin aynı uzunluktaki başıyla karşılaştırılır.
    final prevTotal = StudyStats.totalMinutes(allSessions, from: prevStart, to: addDays(prevStart, elapsedDays));
    final completed = tasks.where((t) => t.completedAt != null && !t.completedAt!.isBefore(start) && t.completedAt!.isBefore(end)).toList();
    final onTime = completed.where((t) => t.dueDate == null || !t.completedAt!.isAfter(t.dueDate!)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('İstatistik')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          SegmentedButton<StatsPeriod>(
            segments: const [
              ButtonSegment(value: StatsPeriod.week, label: Text('Haftalık'), icon: Icon(Icons.view_week_rounded)),
              ButtonSegment(value: StatsPeriod.month, label: Text('Aylık'), icon: Icon(Icons.calendar_month_rounded)),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() {
              _period = s.first;
              _offset = 0;
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Önceki',
                onPressed: () => setState(() => _offset--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(_title(start, days), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Sonraki',
                onPressed: _offset >= 0 ? null : () => setState(() => _offset++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.hourglass_bottom_rounded,
                  color: scheme.primary,
                  value: formatMinutes(total),
                  label: _change(total, prevTotal),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.av_timer_rounded,
                  color: const Color(0xFF0EA5E9),
                  value: formatMinutes(average.round()),
                  label: 'Günlük ortalama',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.flag_rounded,
                  color: const Color(0xFF10B981),
                  value: '$goalDays / $days gün',
                  label: 'Hedef tutturuldu',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF97316),
                  value: '${StudyStats.currentStreak(allSessions, now)} gün',
                  label: 'Seri · en iyi ${StudyStats.bestStreak(allSessions)}',
                ),
              ),
            ],
          ),
          const SectionHeader(title: 'Günlük çalışma'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 16, 10),
              child: SizedBox(height: 190, child: WeekBars(start: start, minutes: daily, goal: goal)),
            ),
          ),
          const SectionHeader(title: 'Derslere göre'),
          _CourseBreakdown(sessions: sessions, courses: courses),
          const SectionHeader(title: 'En verimli saatler'),
          _HourStrip(hours: StudyStats.minutesByHour(sessions)),
          const SectionHeader(title: 'Görevler'),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.task_alt_rounded,
                  color: scheme.primary,
                  value: '${completed.length}',
                  label: 'Tamamlanan',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.verified_rounded,
                  color: const Color(0xFF10B981),
                  value: completed.isEmpty ? '—' : '%${(onTime * 100 / completed.length).round()}',
                  label: 'Zamanında teslim',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _change(int current, int previous) {
    final week = _period == StatsPeriod.week;
    if (previous == 0) return 'Toplam çalışma';
    final pct = ((current - previous) * 100 / previous).round();
    if (pct == 0) return week ? 'Geçen haftayla aynı' : 'Geçen ayla aynı';
    return '${pct > 0 ? '▲' : '▼'} %${pct.abs()} ${week ? 'geçen haftadan' : 'geçen aydan'}';
  }
}

class _CourseBreakdown extends StatelessWidget {
  const _CourseBreakdown({required this.sessions, required this.courses});

  final List<StudySession> sessions;
  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shares = StudyStats.minutesByCourse(sessions);
    final total = shares.fold(0, (s, e) => s + e.value);
    if (total == 0) {
      return const Card(
        child: EmptyState(
          icon: Icons.donut_large_rounded,
          title: 'Bu dönemde çalışma yok',
          message: 'Odak sayacını kullandıkça dağılım burada görünür.',
        ),
      );
    }
    Course? courseOf(String? id) => courses.where((c) => c.id == id).firstOrNull;
    Color colorOf(String? id) => courseOf(id)?.color ?? scheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 130,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                  sections: [
                    for (final e in shares)
                      PieChartSectionData(value: e.value.toDouble(), color: colorOf(e.key), radius: 22, showTitle: false),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (final e in shares.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          ColorDot(color: colorOf(e.key)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              courseOf(e.key)?.name ?? 'Genel çalışma',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          Text(
                            '%${(e.value * 100 / total).round()}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 24 saatlik ısı şeridi.
class _HourStrip extends StatelessWidget {
  const _HourStrip({required this.hours});

  final List<int> hours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = hours.fold(0, math.max);
    final best = maxValue == 0 ? null : hours.indexOf(maxValue);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              best == null
                  ? 'Henüz veri yok'
                  : 'En çok ${best.toString().padLeft(2, '0')}:00 – ${(best + 1).toString().padLeft(2, '0')}:00 arasında çalışıyorsun.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var h = 6; h < 24; h++)
                  Expanded(
                    child: Tooltip(
                      message: '${h.toString().padLeft(2, '0')}:00 · ${formatMinutes(hours[h])}',
                      child: Container(
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: maxValue == 0
                              ? scheme.surfaceContainerHigh
                              : Color.lerp(scheme.surfaceContainerHigh, scheme.primary, hours[h] / maxValue),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            DefaultTextStyle.merge(
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('06'), Text('12'), Text('18'), Text('24')],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
