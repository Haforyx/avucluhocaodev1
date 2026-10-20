import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/study_task.dart';
import '../../services/study_stats.dart';
import '../../state/auth_controller.dart';
import '../../state/data_controllers.dart';
import '../../state/focus_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../utils/quotes.dart';
import '../../widgets/common.dart';
import '../../widgets/task_tile.dart';
import '../../widgets/week_bars.dart';
import '../profile/profile_screen.dart';
import '../tasks/task_form_sheet.dart';
import 'home_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<HomeTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final tasks = context.watch<TaskController>();
    final sessions = context.watch<SessionController>();
    final courses = context.watch<CourseController>();
    final goal = context.select<SettingsController, int>((s) => s.settings.dailyGoalMinutes);
    final now = DateTime.now();

    final todayTasks = [
      ...tasks.filtered(TaskFilter.overdue, now: now),
      ...tasks.filtered(TaskFilter.today, now: now).where((t) => !t.isOverdue(now)),
    ];
    final upcoming = tasks
        .filtered(TaskFilter.upcoming, now: now)
        .where((t) => !isSameDay(t.dueDate!, now))
        .take(4)
        .toList();
    final exams = tasks.tasks
        .where((t) =>
            !t.isDone &&
            t.kind == TaskKind.exam &&
            t.dueDate != null &&
            !t.dueDate!.isBefore(dateOnly(now)) &&
            t.dueDate!.isBefore(addDays(now, 45)))
        .toList();
    final gpa = courses.gpa;
    final weekStart = startOfWeek(now);
    final week = StudyStats.dailyTotals(sessions.sessions, weekStart, 7);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _GreetingCard(
            name: user.firstName,
            initials: user.initials,
            now: now,
            minutesToday: sessions.minutesToday(now),
            goalMinutes: goal,
            streak: sessions.streak(now),
            onFocus: () => onNavigate(HomeTab.focus),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.today_rounded,
                  color: const Color(0xFF0EA5E9),
                  value: '${tasks.count(TaskFilter.today, now: now)}',
                  label: 'Bugün teslim',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFEF4444),
                  value: '${tasks.count(TaskFilter.overdue, now: now)}',
                  label: 'Geciken',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onNavigate(HomeTab.courses),
                  child: StatTile(
                    icon: Icons.workspace_premium_rounded,
                    color: accentColor,
                    value: gpa == null ? '—' : formatNumber(gpa),
                    label: 'GANO',
                  ),
                ),
              ),
            ],
          ),
          SectionHeader(
            title: 'Bugün',
            action: TextButton.icon(
              onPressed: () => showTaskForm(context, initialDue: DateTime(now.year, now.month, now.day, 23, 59)),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Görev ekle'),
            ),
          ),
          if (todayTasks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const IconBadge(icon: Icons.celebration_rounded, color: Color(0xFF10B981)),
                  title: const Text('Bugün için teslim yok'),
                  subtitle: Text(
                    upcoming.isEmpty ? 'Yeni bir görev ekleyebilirsin.' : 'Yaklaşan işlere göz atmaya ne dersin?',
                  ),
                ),
              ),
            )
          else
            CardList(children: [for (final t in todayTasks.take(6)) TaskTile(task: t)]),
          if (exams.isNotEmpty) ...[
            const SectionHeader(title: 'Sınav geri sayımı'),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: exams.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _ExamCard(task: exams[i], now: now),
              ),
            ),
          ],
          if (upcoming.isNotEmpty) ...[
            SectionHeader(
              title: 'Yaklaşanlar',
              action: TextButton(onPressed: () => onNavigate(HomeTab.tasks), child: const Text('Tümü')),
            ),
            CardList(children: [for (final t in upcoming) TaskTile(task: t)]),
          ],
          SectionHeader(
            title: 'Bu hafta',
            action: TextButton(onPressed: () => onNavigate(HomeTab.stats), child: const Text('Ayrıntılar')),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatMinutes(week.fold(0, (a, b) => a + b)),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Tag(
                        icon: Icons.flag_rounded,
                        label: 'Hedef ${formatMinutes(goal)}/gün',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(height: 150, child: WeekBars(start: weekStart, minutes: week, goal: goal)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _QuoteCard(now: now),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({
    required this.name,
    required this.initials,
    required this.now,
    required this.minutesToday,
    required this.goalMinutes,
    required this.streak,
    required this.onFocus,
  });

  final String name;
  final String initials;
  final DateTime now;
  final int minutesToday;
  final int goalMinutes;
  final int streak;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final progress = goalMinutes == 0 ? 0.0 : minutesToday / goalMinutes;
    final running = context.select<FocusController, bool>((f) => f.isRunning);
    final white70 = Colors.white.withValues(alpha: 0.78);
    return Container(
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: brandColor.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${timeGreeting(now)} · ${formatDateLong(now)}',
                            style: TextStyle(color: white70, fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Merhaba $name!',
                                key: const Key('greeting'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const Text('  👋', style: TextStyle(fontSize: 24)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: 'Profil ve ayarlar',
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                        ),
                        child: UserAvatar(
                          initials: initials,
                          size: 42,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    ProgressRing(
                      progress: progress,
                      size: 84,
                      strokeWidth: 9,
                      color: Colors.white,
                      trackColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        '%${(progress * 100).clamp(0, 999).round()}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bugünkü çalışma', style: TextStyle(color: white70, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '${formatMinutes(minutesToday)} / ${formatMinutes(goalMinutes)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFDBA74), size: 18),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  streak == 0 ? 'Seri başlatmak için bugün çalış' : '$streak günlük seri',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: brandColor,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: onFocus,
                    icon: Icon(running ? Icons.timer_rounded : Icons.play_arrow_rounded),
                    label: Text(running ? 'Sayaç çalışıyor' : 'Odaklanmaya başla'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.task, required this.now});

  final StudyTask task;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final color = context.select<CourseController, Color?>((c) => c.byId(task.courseId)?.color) ??
        Theme.of(context).colorScheme.primary;
    final days = dateOnly(task.dueDate!).difference(dateOnly(now)).inDays;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showTaskForm(context, task: task),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      days == 0 ? 'BUGÜN' : '$days',
                      style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w900, height: 1),
                    ),
                    if (days > 0) ...[
                      const SizedBox(width: 4),
                      Text('gün', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                    ],
                  ],
                ),
                const Spacer(),
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDue(task.dueDate!, now),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (quote, author) = quoteOfTheDay(now);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote_rounded, color: scheme.primary, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Günün sözü', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Text(
                    quote,
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontSize: 15.5,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('— $author', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
