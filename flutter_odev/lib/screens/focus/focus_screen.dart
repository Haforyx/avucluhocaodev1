import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/course.dart';
import '../../models/study_session.dart';
import '../../services/pomodoro_engine.dart';
import '../../services/study_stats.dart';
import '../../state/data_controllers.dart';
import '../../state/focus_controller.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../utils/text_utils.dart';
import '../../widgets/common.dart';
import '../profile/settings_screen.dart';
import 'manual_session_sheet.dart';

/// Pomodoro odak sayacı.
class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusController>();
    final courses = context.watch<CourseController>().courses;
    final sessions = context.watch<SessionController>();
    final scheme = Theme.of(context).colorScheme;
    final color = focus.phase.isBreak ? breakColor : (courses.where((c) => c.id == focus.courseId).firstOrNull?.color ?? focusColor);
    final now = DateTime.now();
    final today = sessions.sessions.where((s) => isSameDay(s.start, now)).toList();
    final idle = focus.status == TimerStatus.idle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Odak'),
        actions: [
          IconButton(
            tooltip: 'Elle çalışma ekle',
            onPressed: () => showManualSessionSheet(context),
            icon: const Icon(Icons.more_time_rounded),
          ),
          IconButton(
            tooltip: 'Sayaç ayarları',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Center(
            child: SegmentedButton<FocusPhase>(
              segments: [
                for (final p in FocusPhase.values) ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {focus.phase},
              showSelectedIcon: false,
              onSelectionChanged: (s) async {
                if (!idle) {
                  final ok = await confirm(
                    context,
                    title: 'Sayaç sıfırlansın mı?',
                    message: 'Devam eden süre kaydedilmeden evre değişecek.',
                    confirmLabel: 'Değiştir',
                  );
                  if (!ok) return;
                }
                focus.selectPhase(s.first);
              },
            ),
          ),
          const SizedBox(height: 26),
          Center(
            child: ProgressRing(
              progress: focus.progress,
              color: color,
              size: 260,
              strokeWidth: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trUpper(focus.phase.label),
                    style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatClock(focus.remaining),
                    key: const Key('focus-clock'),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 58),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    switch (focus.status) {
                      TimerStatus.idle => '${focus.config.durationOf(focus.phase).inMinutes} dakika',
                      TimerStatus.running => 'Çalışıyor',
                      TimerStatus.paused => 'Duraklatıldı',
                    },
                    style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _PomodoroDots(
            total: focus.config.sessionsBeforeLongBreak,
            filled: focus.completedFocusCount % focus.config.sessionsBeforeLongBreak,
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            focus.completedFocusCount == 0
                ? '${focus.config.sessionsBeforeLongBreak} odakta bir uzun mola'
                : '${focus.completedFocusCount} odak tamamlandı · uzun molaya ${focus.focusUntilLongBreak}',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundButton(
                tooltip: 'Sıfırla',
                icon: Icons.replay_rounded,
                onPressed: idle ? null : focus.reset,
              ),
              const SizedBox(width: 22),
              SizedBox.square(
                dimension: 84,
                child: FilledButton(
                  key: const Key('focus-toggle'),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(84),
                  ),
                  onPressed: focus.toggle,
                  child: Icon(focus.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44),
                ),
              ),
              const SizedBox(width: 22),
              _RoundButton(tooltip: 'Atla', icon: Icons.skip_next_rounded, onPressed: focus.skip),
            ],
          ),
          if (!idle && focus.phase == FocusPhase.focus) ...[
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: focus.finishEarly,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Bitir ve kaydet'),
              ),
            ),
          ],
          const SizedBox(height: 22),
          DropdownButtonFormField<String?>(
            initialValue: courses.any((c) => c.id == focus.courseId) ? focus.courseId : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Hangi derse çalışıyorsun?',
              prefixIcon: Icon(Icons.class_outlined),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Genel çalışma')),
              for (final c in courses)
                DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      ColorDot(color: c.color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c.displayName, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
            ],
            onChanged: focus.selectCourse,
          ),
          SectionHeader(
            title: 'Bugünkü oturumlar',
            action: Text(
              formatMinutes(today.fold(0, (s, e) => s + e.minutes)),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.primary),
            ),
          ),
          if (today.isEmpty)
            Card(
              child: ListTile(
                leading: IconBadge(icon: Icons.self_improvement_rounded, color: scheme.primary),
                title: const Text('Henüz oturum yok'),
                subtitle: const Text('İlk odağını başlat; bittiğinde burada görünür.'),
              ),
            )
          else
            CardList(children: [for (final s in today) SessionTile(session: s)]),
        ],
      ),
    );
  }
}

/// Bir çalışma oturumu satırı (kaydırınca silinir).
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session, this.showDate = false});

  final StudySession session;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final course = context.select<CourseController, Course?>((c) => c.byId(session.courseId));
    final scheme = Theme.of(context).colorScheme;
    final time = '${formatTime(session.start)} – ${formatTime(session.end)}';
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline_rounded, color: scheme.onError),
      ),
      onDismissed: (_) {
        final sessions = context.read<SessionController>();
        sessions.delete(session.id);
        showSnack(
          context,
          'Oturum silindi.',
          action: SnackBarAction(label: 'Geri al', onPressed: () => sessions.save(session)),
        );
      },
      child: ListTile(
        leading: CourseBadge(course: course, size: 40),
        title: Text(course?.name ?? 'Genel çalışma', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (showDate) formatDateShort(session.start),
            time,
            if (session.source == SessionSource.manual) 'elle eklendi',
          ].join(' · '),
        ),
        trailing: Text(
          formatMinutes(session.minutes),
          style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _PomodoroDots extends StatelessWidget {
  const _PomodoroDots({required this.total, required this.filled, required this.color});

  final int total;
  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i < filled ? 22 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: i < filled ? color : color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 28,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(58),
        backgroundColor: scheme.surface,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      icon: Icon(icon),
    );
  }
}
