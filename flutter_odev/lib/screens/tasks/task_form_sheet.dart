import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/study_task.dart';
import '../../services/study_stats.dart';
import '../../state/data_controllers.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Görev ekleme/düzenleme alt sayfasını açar.
Future<void> showTaskForm(
  BuildContext context, {
  StudyTask? task,
  String? initialCourseId,
  DateTime? initialDue,
  TaskKind? initialKind,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TaskFormSheet(
      task: task,
      initialCourseId: initialCourseId,
      initialDue: initialDue,
      initialKind: initialKind,
    ),
  );
}

class TaskFormSheet extends StatefulWidget {
  const TaskFormSheet({super.key, this.task, this.initialCourseId, this.initialDue, this.initialKind});

  final StudyTask? task;
  final String? initialCourseId;
  final DateTime? initialDue;
  final TaskKind? initialKind;

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _note = TextEditingController(text: widget.task?.note ?? '');
  late TaskKind _kind = widget.task?.kind ?? widget.initialKind ?? TaskKind.homework;
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.normal;
  late String? _courseId = widget.task?.courseId ?? widget.initialCourseId;
  late DateTime? _due = widget.task?.dueDate ?? widget.initialDue;
  bool _saving = false;

  bool get _editing => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _due ?? now;
    // Eski tarihli bir görev düzenlenirken de seçici açılabilsin.
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 3);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: initial.isBefore(first) ? dateOnly(initial) : first,
      lastDate: initial.isAfter(last) ? initial : last,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _due == null ? const TimeOfDay(hour: 23, minute: 59) : TimeOfDay.fromDateTime(_due!),
    );
    final t = time ?? const TimeOfDay(hour: 23, minute: 59);
    setState(() => _due = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  void _quickDue(int days) {
    final d = addDays(DateTime.now(), days);
    setState(() => _due = DateTime(d.year, d.month, d.day, 23, 59));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final tasks = context.read<TaskController>();
    final existing = widget.task;
    if (existing == null) {
      await tasks.create(
        title: _title.text,
        note: _note.text,
        courseId: _courseId,
        dueDate: _due,
        kind: _kind,
        priority: _priority,
      );
    } else {
      await tasks.save(
        existing.copyWith(
          title: _title.text.trim(),
          note: _note.text.trim(),
          courseId: _courseId,
          clearCourse: _courseId == null,
          dueDate: _due,
          clearDueDate: _due == null,
          kind: _kind,
          priority: _priority,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final task = widget.task!;
    final ok = await confirm(context, title: 'Görev silinsin mi?', message: '"${task.title}" kalıcı olarak silinecek.');
    if (!ok || !mounted) return;
    final tasks = context.read<TaskController>();
    final messenger = ScaffoldMessenger.of(context);
    await tasks.delete(task.id);
    if (!mounted) return;
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Görev silindi.'),
          action: SnackBarAction(label: 'Geri al', onPressed: () => tasks.save(task)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final courses = context.watch<CourseController>().courses;
    final courseExists = _courseId == null || courses.any((c) => c.id == _courseId);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_editing ? 'Görevi düzenle' : 'Yeni görev', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  if (_editing)
                    IconButton(
                      tooltip: 'Sil',
                      onPressed: _delete,
                      icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('task-title'),
                controller: _title,
                autofocus: !_editing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Başlık', hintText: 'Örn. Lineer cebir 3. ödev'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bir başlık yaz.' : null,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in TaskKind.values)
                    ChoiceChip(
                      avatar: Icon(k.icon, size: 18, color: _kind == k ? scheme.onPrimary : scheme.onSurfaceVariant),
                      label: Text(k.label, style: TextStyle(color: _kind == k ? scheme.onPrimary : scheme.onSurface)),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: courseExists ? _courseId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ders', prefixIcon: Icon(Icons.class_outlined)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ders yok')),
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
                onChanged: (v) => setState(() => _courseId = v),
              ),
              const SizedBox(height: 16),
              Text('Son teslim', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(Icons.event_rounded, color: scheme.primary),
                  title: Text(_due == null ? 'Tarih yok' : '${formatDate(_due!)}, ${formatTime(_due!)}'),
                  subtitle: _due == null ? const Text('Seçmek için dokun') : Text(formatCountdown(_due!, DateTime.now())),
                  trailing: _due == null
                      ? null
                      : IconButton(
                          tooltip: 'Tarihi kaldır',
                          onPressed: () => setState(() => _due = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(label: const Text('Bugün'), onPressed: () => _quickDue(0)),
                  ActionChip(label: const Text('Yarın'), onPressed: () => _quickDue(1)),
                  ActionChip(label: const Text('3 gün'), onPressed: () => _quickDue(3)),
                  ActionChip(label: const Text('1 hafta'), onPressed: () => _quickDue(7)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Öncelik', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<TaskPriority>(
                segments: [
                  for (final p in TaskPriority.values)
                    ButtonSegment(value: p, label: Text(p.label), icon: Icon(Icons.flag_rounded, color: p.color)),
                ],
                selected: {_priority},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)', alignLabelWithHint: true),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('task-save'),
                onPressed: _saving ? null : _save,
                child: Text(_editing ? 'Kaydet' : 'Görevi ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
