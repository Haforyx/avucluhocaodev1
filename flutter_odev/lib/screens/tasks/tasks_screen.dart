import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/study_task.dart';
import '../../services/study_stats.dart';
import '../../state/data_controllers.dart';
import '../../utils/text_utils.dart';
import '../../widgets/common.dart';
import '../../widgets/task_tile.dart';
import 'task_form_sheet.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskFilter _filter = TaskFilter.active;
  String? _courseId;
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TaskController>();
    final courses = context.watch<CourseController>().courses;
    final now = DateTime.now();
    final query = foldForSearch(_search.text.trim());
    final courseValid = _courseId == null || courses.any((c) => c.id == _courseId);
    final list = controller
        .filtered(_filter, now: now, courseId: courseValid ? _courseId : null)
        .where((t) => query.isEmpty || foldForSearch('${t.title} ${t.note}').contains(query))
        .toList();
    final total = controller.tasks.length;
    final done = controller.count(TaskFilter.done, now: now);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Görevlerde ara',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              )
            : const Text('Görevler'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Aramayı kapat' : 'Ara',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          if (courses.isNotEmpty)
            PopupMenuButton<String?>(
              tooltip: 'Derse göre süz',
              icon: Badge(isLabelVisible: _courseId != null, smallSize: 8, child: const Icon(Icons.filter_list_rounded)),
              initialValue: _courseId,
              onSelected: (v) => setState(() => _courseId = v == '' ? null : v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('Bütün dersler')),
                for (final c in courses)
                  PopupMenuItem(
                    value: c.id,
                    child: Row(children: [ColorDot(color: c.color), const SizedBox(width: 10), Expanded(child: Text(c.displayName))]),
                  ),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasks-fab',
        onPressed: () => showTaskForm(context, initialCourseId: courseValid ? _courseId : null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni görev'),
      ),
      body: Column(
        children: [
          if (total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: LinearProgressIndicator(
                        value: done / total,
                        minHeight: 8,
                        backgroundColor: scheme.surfaceContainerHigh,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$done/$total tamamlandı', style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final f in TaskFilter.values) ...[
                  ChoiceChip(
                    label: Text(
                      '${f.label} ${controller.count(f, now: now)}',
                      style: TextStyle(color: _filter == f ? scheme.onPrimary : scheme.onSurface),
                    ),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(
                    children: [
                      EmptyState(
                        icon: _filter == TaskFilter.done ? Icons.inventory_2_outlined : Icons.task_alt_rounded,
                        title: query.isNotEmpty ? 'Sonuç yok' : _emptyTitle,
                        message: query.isNotEmpty
                            ? '"${_search.text}" ile eşleşen görev bulunamadı.'
                            : 'Ödev, sınav ya da proje ekleyerek başla. Yaklaşan teslimleri ana sayfada görürsün.',
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    children: [
                      for (final group in _group(list, now)) ...[
                        SectionHeader(title: group.$1, padding: const EdgeInsets.fromLTRB(4, 14, 0, 8)),
                        CardList(children: [for (final t in group.$2) _Swipeable(task: t)]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String get _emptyTitle => switch (_filter) {
        TaskFilter.active => 'Yapılacak görev yok',
        TaskFilter.today => 'Bugün teslim yok',
        TaskFilter.upcoming => 'Bu hafta boş görünüyor',
        TaskFilter.overdue => 'Geciken görev yok, harika!',
        TaskFilter.done => 'Henüz tamamlanan görev yok',
      };

  /// Görevleri teslim tarihine göre başlıklar altında toplar.
  List<(String, List<StudyTask>)> _group(List<StudyTask> tasks, DateTime now) {
    if (_filter == TaskFilter.done) return [('Tamamlananlar', tasks)];
    final today = dateOnly(now);
    final groups = <String, List<StudyTask>>{};
    for (final t in tasks) {
      final due = t.dueDate;
      final String key;
      if (due == null) {
        key = 'Tarihsiz';
      } else if (t.isOverdue(now)) {
        key = 'Gecikenler';
      } else {
        final days = dateOnly(due).difference(today).inDays;
        key = switch (days) {
          0 => 'Bugün',
          1 => 'Yarın',
          < 7 => 'Bu hafta',
          < 30 => 'Bu ay',
          _ => 'Daha sonra',
        };
      }
      groups.putIfAbsent(key, () => []).add(t);
    }
    const order = ['Gecikenler', 'Bugün', 'Yarın', 'Bu hafta', 'Bu ay', 'Daha sonra', 'Tarihsiz'];
    return [
      for (final k in order)
        if (groups[k] != null) ('$k · ${groups[k]!.length}', groups[k]!),
    ];
  }
}

/// Sola kaydırınca silinen görev satırı (geri alınabilir).
class _Swipeable extends StatelessWidget {
  const _Swipeable({required this.task});

  final StudyTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline_rounded, color: scheme.onError),
      ),
      onDismissed: (_) {
        final tasks = context.read<TaskController>();
        tasks.delete(task.id);
        showSnack(
          context,
          '"${task.title}" silindi.',
          action: SnackBarAction(label: 'Geri al', onPressed: () => tasks.save(task)),
        );
      },
      child: TaskTile(task: task),
    );
  }
}

