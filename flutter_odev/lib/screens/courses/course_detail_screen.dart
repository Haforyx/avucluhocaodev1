import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/course.dart';
import '../../services/grade_calculator.dart';
import '../../services/study_stats.dart';
import '../../services/validators.dart';
import '../../state/data_controllers.dart';
import '../../state/focus_controller.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/task_tile.dart';
import '../focus/focus_screen.dart';
import '../tasks/task_form_sheet.dart';
import 'course_form_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  Future<void> _delete(BuildContext context, Course course) async {
    final ok = await confirm(
      context,
      title: 'Ders silinsin mi?',
      message: '"${course.name}" ve notları silinecek. Bu derse bağlı görevler silinmez, dersten ayrılır.',
    );
    if (!ok || !context.mounted) return;
    final courses = context.read<CourseController>();
    final tasks = context.read<TaskController>();
    final focus = context.read<FocusController>();
    if (focus.courseId == course.id) focus.selectCourse(null);
    Navigator.pop(context);
    await courses.delete(course.id);
    await tasks.detachCourse(course.id);
  }

  @override
  Widget build(BuildContext context) {
    final course = context.select<CourseController, Course?>((c) => c.byId(courseId));
    if (course == null) return const Scaffold();
    final scheme = Theme.of(context).colorScheme;
    final summary = GradeCalculator.summarize(course.assessments);
    final tasks = context.watch<TaskController>().tasks.where((t) => t.courseId == course.id).toList();
    final openTasks = tasks.where((t) => !t.isDone).toList();
    final sessions = context.watch<SessionController>().forCourse(course.id);
    final now = DateTime.now();
    final weekMinutes = StudyStats.totalMinutes(sessions, from: startOfWeek(now));
    final totalMinutes = StudyStats.totalMinutes(sessions);

    return Scaffold(
      appBar: AppBar(
        title: Text(course.code.isEmpty ? 'Ders' : course.code),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => CourseFormScreen(course: course)),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Sil',
            onPressed: () => _delete(context, course),
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _Header(course: course, summary: summary),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.timer_outlined,
                  color: course.color,
                  value: formatMinutes(weekMinutes),
                  label: course.weeklyGoalMinutes > 0 ? 'Bu hafta / ${formatMinutes(course.weeklyGoalMinutes)}' : 'Bu hafta',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.hourglass_bottom_rounded,
                  color: course.color,
                  value: formatMinutes(totalMinutes),
                  label: 'Toplam çalışma',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.task_alt_rounded,
                  color: course.color,
                  value: '${openTasks.length}',
                  label: 'Açık görev',
                ),
              ),
            ],
          ),
          if (course.weeklyGoalMinutes > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LinearProgressIndicator(
                value: (weekMinutes / course.weeklyGoalMinutes).clamp(0.0, 1.0),
                minHeight: 8,
                color: course.color,
                backgroundColor: course.color.withValues(alpha: 0.12),
              ),
            ),
          ],
          const SectionHeader(title: 'Notlar'),
          CardList(
            children: [
              for (final a in course.assessments) _AssessmentTile(course: course, assessment: a),
            ],
          ),
          if (summary.hasWeightProblem)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ErrorBanner(
                message: 'Ağırlıkların toplamı %${formatScore(summary.totalWeight)}. Hesaplamaların doğru olması için '
                    'dersi düzenleyip %100 yap.',
              ),
            ),
          _TargetsSection(course: course, summary: summary),
          SectionHeader(
            title: 'Görevler',
            action: TextButton.icon(
              onPressed: () => showTaskForm(context, initialCourseId: course.id),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Ekle'),
            ),
          ),
          if (tasks.isEmpty)
            Card(
              child: ListTile(
                leading: IconBadge(icon: Icons.inbox_rounded, color: course.color),
                title: const Text('Bu derse ait görev yok'),
              ),
            )
          else
            CardList(children: [for (final t in [...openTasks, ...tasks.where((t) => t.isDone)]) TaskTile(task: t, showCourse: false)]),
          if (sessions.isNotEmpty) ...[
            const SectionHeader(title: 'Son çalışmalar'),
            CardList(children: [for (final s in sessions.take(5)) SessionTile(session: s, showDate: true)]),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.course, required this.summary});

  final Course course;
  final CourseGradeSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter = summary.letter;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            ProgressRing(
              progress: (summary.average ?? 0) / 100,
              color: letter?.color ?? course.color,
              size: 92,
              strokeWidth: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    letter?.label ?? '—',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: letter?.color ?? scheme.onSurfaceVariant),
                  ),
                  if (summary.average != null)
                    Text(
                      formatScore(summary.average!),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '${course.credits} kredi',
                      if (course.instructor.isNotEmpty) course.instructor,
                    ].join(' · '),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Tag(
                    label: summary.isComplete
                        ? (letter!.isPassing ? 'Dersi geçtin' : 'Kaldın')
                        : summary.average == null
                            ? 'Henüz not girilmedi'
                            : 'Not girişi %${summary.gradedWeight.round()}',
                    color: summary.isComplete ? (letter!.isPassing ? const Color(0xFF10B981) : scheme.error) : course.color,
                    icon: summary.isComplete ? Icons.flag_circle_rounded : Icons.pending_outlined,
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

class _AssessmentTile extends StatelessWidget {
  const _AssessmentTile({required this.course, required this.assessment});

  final Course course;
  final Assessment assessment;

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<(double?,)>(
      context: context,
      builder: (_) => _ScoreDialog(assessment: assessment),
    );
    if (result == null || !context.mounted) return;
    await context.read<CourseController>().setScore(course, assessment.id, result.$1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = assessment.score;
    final date = assessment.date;
    return ListTile(
      onTap: () => _edit(context),
      leading: IconBadge(
        icon: score == null ? Icons.hourglass_empty_rounded : Icons.check_rounded,
        color: score == null ? scheme.onSurfaceVariant : course.color,
        size: 40,
      ),
      title: Text(assessment.name),
      subtitle: Text(
        [
          'Ağırlık %${formatScore(assessment.weight)}',
          if (score != null) 'katkı ${formatScore(score * assessment.weight / 100)} puan',
          if (score == null && date != null) formatDue(date, DateTime.now()),
        ].join(' · '),
      ),
      trailing: score == null
          ? Text('Not gir', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800))
          : Text(formatScore(score), style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// Not girme penceresi. Sonuç: (not,) — not null ise not kaldırılır; pencere
/// kapatılırsa null döner.
class _ScoreDialog extends StatefulWidget {
  const _ScoreDialog({required this.assessment});

  final Assessment assessment;

  @override
  State<_ScoreDialog> createState() => _ScoreDialogState();
}

class _ScoreDialogState extends State<_ScoreDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(
    text: widget.assessment.score == null ? '' : formatEditable(widget.assessment.score!),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final text = _controller.text.trim();
    Navigator.pop(context, (text.isEmpty ? null : double.parse(text.replaceAll(',', '.')),));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assessment;
    return AlertDialog(
      title: Text('${a.name} notu'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(labelText: 'Not (0-100)', helperText: 'Ağırlık: %${formatScore(a.weight)}'),
          validator: Validators.optionalScore,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        if (a.isGraded) TextButton(onPressed: () => Navigator.pop(context, (null,)), child: const Text('Notu kaldır')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: _save,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// "Finalden kaç almalıyım?" tablosu ve kalan sınav simülatörü.
class _TargetsSection extends StatefulWidget {
  const _TargetsSection({required this.course, required this.summary});

  final Course course;
  final CourseGradeSummary summary;

  @override
  State<_TargetsSection> createState() => _TargetsSectionState();
}

class _TargetsSectionState extends State<_TargetsSection> {
  double _whatIf = 70;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final assessments = widget.course.assessments;
    final requirements = GradeCalculator.requirements(assessments);
    if (requirements.isEmpty) return const SizedBox.shrink();
    final remainingNames = assessments.where((a) => !a.isGraded).map((a) => a.name).join(', ');

    // Kalan her sınavdan _whatIf alınırsa ortalama ne olur?
    final projected = GradeCalculator.summarize([
      for (final a in assessments) a.isGraded ? a : a.copyWith(score: _whatIf),
    ]);
    final projectedLetter = projected.letter!;

    // Yalnızca anlamlı hedefleri göster: garanti olanlardan en iyisi ve ulaşılabilir olanlar.
    final reachable = requirements.where((r) => !r.isImpossible && !r.isGuaranteed).toList();
    final guaranteed = requirements.where((r) => r.isGuaranteed).firstOrNull;
    final impossible = requirements.where((r) => r.isImpossible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: '$remainingNames için hedef'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hangi harf notu için kalan sınav(lar)dan en az kaç alman gerektiği:',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in reachable)
                      _RequirementChip(
                        label: r.grade.label,
                        value: r.requiredScore.ceil().toString(),
                        color: r.grade.color,
                      ),
                    if (guaranteed != null)
                      _RequirementChip(label: guaranteed.grade.label, value: 'garanti', color: guaranteed.grade.color),
                  ],
                ),
                if (impossible.isNotEmpty && reachable.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${impossible.map((r) => r.grade.label).join(', ')}: kalanlardan 100 alsan bile ulaşılamıyor.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
                if (reachable.isEmpty && guaranteed == null)
                  Text('Kalan sınavlardan 100 alsan bile geçer not zor görünüyor.', style: TextStyle(color: scheme.error)),
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text('Kalanlardan ${_whatIf.round()} alırsan', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    Text(
                      '${formatScore(projected.average!)} · ${projectedLetter.label}',
                      style: TextStyle(color: projectedLetter.color, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                Slider(
                  value: _whatIf,
                  max: 100,
                  divisions: 100,
                  label: '${_whatIf.round()}',
                  activeColor: projectedLetter.color,
                  onChanged: (v) => setState(() => _whatIf = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RequirementChip extends StatelessWidget {
  const _RequirementChip({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
