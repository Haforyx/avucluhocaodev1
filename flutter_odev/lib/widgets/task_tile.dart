import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_task.dart';
import '../screens/tasks/task_form_sheet.dart';
import '../state/data_controllers.dart';
import '../utils/format.dart';
import 'common.dart';

/// Görev satırı: tamamlandı kutusu, başlık, ders ve teslim tarihi.
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.showCourse = true});

  final StudyTask task;
  final bool showCourse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final course = context.select<CourseController, String?>(
      (c) {
        final course = c.byId(task.courseId);
        if (course == null) return null;
        return course.code.isEmpty ? course.name : course.code;
      },
    );
    final courseColor = context.select<CourseController, Color?>((c) => c.byId(task.courseId)?.color);
    final now = DateTime.now();
    final overdue = task.isOverdue(now);
    final due = task.dueDate;

    final meta = <Widget>[
      if (showCourse && course != null) ...[
        ColorDot(color: courseColor!, size: 8),
        const SizedBox(width: 5),
        Flexible(
          child: Text(course, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      if (due != null) ...[
        if (showCourse && course != null) const Text('  ·  '),
        Icon(
          overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
          size: 13,
          color: overdue ? scheme.error : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            task.isDone ? formatDateShort(due) : formatDue(due, now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: overdue ? scheme.error : null, fontWeight: overdue ? FontWeight.w800 : null),
          ),
        ),
      ],
      if (due == null && (course == null || !showCourse)) Text(task.kind.label),
    ];

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      leading: _DoneButton(task: task),
      title: Text(
        task.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          decoration: task.isDone ? TextDecoration.lineThrough : null,
          color: task.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          child: Row(children: meta),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(task.kind.icon, size: 19, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
          if (task.priority == TaskPriority.high && !task.isDone) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Yüksek öncelik',
              child: Icon(Icons.flag_rounded, size: 19, color: task.priority.color),
            ),
          ],
        ],
      ),
      onTap: () => showTaskForm(context, task: task),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.task});

  final StudyTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = task.priority == TaskPriority.high ? task.priority.color : scheme.primary;
    return IconButton(
      tooltip: task.isDone ? 'Tamamlanmadı olarak işaretle' : 'Tamamlandı olarak işaretle',
      onPressed: () async {
        final tasks = context.read<TaskController>();
        await tasks.toggleDone(task);
        if (!context.mounted || task.isDone) return;
        showSnack(
          context,
          '"${task.title}" tamamlandı.',
          action: SnackBarAction(label: 'Geri al', onPressed: () => tasks.toggleDone(tasks.byId(task.id)!)),
        );
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: task.isDone
            ? Icon(Icons.check_circle_rounded, key: const ValueKey(true), color: scheme.primary, size: 28)
            : Icon(Icons.radio_button_unchecked_rounded, key: const ValueKey(false), color: color, size: 28),
      ),
    );
  }
}
