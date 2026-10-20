import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/course.dart';
import '../../services/grade_calculator.dart';
import '../../state/data_controllers.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'course_detail_screen.dart';
import 'course_form_screen.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CourseController>();
    final courses = controller.courses;

    return Scaffold(
      appBar: AppBar(title: const Text('Dersler')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'courses-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CourseFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ders ekle'),
      ),
      body: courses.isEmpty
          ? ListView(
              children: const [
                EmptyState(
                  icon: Icons.class_rounded,
                  title: 'Henüz ders eklemedin',
                  message: 'Derslerini, kredilerini ve sınav ağırlıklarını gir; ortalamanı ve GANO\'nu '
                      'Avuçlu Hoca hesaplasın.',
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                _GpaCard(courses: courses),
                const SectionHeader(title: 'Bu dönem'),
                for (final c in courses) ...[
                  _CourseCard(course: c),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _GpaCard extends StatelessWidget {
  const _GpaCard({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final gpa = GradeCalculator.gpa(courses);
    final credits = GradeCalculator.gradedCredits(courses);
    final total = courses.fold<int>(0, (s, c) => s + c.credits);
    final complete = courses.where((c) => GradeCalculator.summarize(c.assessments).isComplete).length;
    final white70 = Colors.white.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: brandGradient, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          ProgressRing(
            progress: gpa == null ? 0 : gpa / 4,
            size: 96,
            strokeWidth: 10,
            color: Colors.white,
            trackColor: Colors.white.withValues(alpha: 0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gpa == null ? '—' : formatNumber(gpa),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Text('/ 4,00', style: TextStyle(color: white70, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tahmini dönem ortalaması',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  '${courses.length} ders · $total kredi\n'
                  '$complete ders tamamlandı · $credits kredi hesaba katıldı',
                  style: TextStyle(color: white70, height: 1.4, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Notu tamamlanmamış dersler mevcut notlara göre tahmin edilir.',
                  style: TextStyle(color: white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = GradeCalculator.summarize(course.assessments);
    final letter = summary.letter;
    final weekMinutes = context.select<SessionController, int>((s) => s.minutesThisWeekFor(course.id));
    final openTasks = context.select<TaskController, int>(
      (t) => t.tasks.where((x) => x.courseId == course.id && !x.isDone).length,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CourseDetailScreen(courseId: course.id)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: course.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CourseBadge(course: course, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                Text(
                                  [
                                    if (course.code.isNotEmpty) course.code,
                                    '${course.credits} kredi',
                                    if (course.instructor.isNotEmpty) course.instructor,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _LetterChip(letter: letter, average: summary.average),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: LinearProgressIndicator(
                          value: summary.gradedWeight / 100,
                          minHeight: 6,
                          color: course.color,
                          backgroundColor: course.color.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DefaultTextStyle.merge(
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w700),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Not girişi %${summary.gradedWeight.round()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.timer_outlined, size: 14),
                            const SizedBox(width: 3),
                            Text(formatMinutes(weekMinutes)),
                            if (openTasks > 0) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.task_alt_rounded, size: 14),
                              const SizedBox(width: 3),
                              Text('$openTasks'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({required this.letter, required this.average});

  final LetterGrade? letter;
  final double? average;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (letter == null) {
      return Text('Not yok', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: letter!.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(letter!.label, style: TextStyle(color: letter!.color, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        const SizedBox(height: 2),
        Text(formatScore(average!), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
