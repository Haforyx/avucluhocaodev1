import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/study_session.dart';
import '../../state/data_controllers.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Sayaç kullanmadan yapılan çalışmayı (kütüphane, ders tekrarı...) kaydetme.
Future<void> showManualSessionSheet(BuildContext context, {String? courseId}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ManualSessionSheet(initialCourseId: courseId),
    );

class _ManualSessionSheet extends StatefulWidget {
  const _ManualSessionSheet({this.initialCourseId});

  final String? initialCourseId;

  @override
  State<_ManualSessionSheet> createState() => _ManualSessionSheetState();
}

class _ManualSessionSheetState extends State<_ManualSessionSheet> {
  late String? _courseId = widget.initialCourseId;
  int _minutes = 45;
  late DateTime _start = DateTime.now().subtract(const Duration(minutes: 45));
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (time == null) return;
    setState(() => _start = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (_start.isAfter(DateTime.now())) {
      showSnack(context, 'Gelecekteki bir zamana çalışma eklenemez.');
      return;
    }
    await context.read<SessionController>().record(
          minutes: _minutes,
          start: _start,
          courseId: _courseId,
          source: SessionSource.manual,
          note: _note.text,
        );
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, '${formatMinutes(_minutes)} çalışma eklendi.');
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseController>().courses;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Elle çalışma ekle', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: courses.any((c) => c.id == _courseId) ? _courseId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ders', prefixIcon: Icon(Icons.class_outlined)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Genel çalışma')),
                for (final c in courses) DropdownMenuItem(value: c.id, child: Text(c.displayName, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _courseId = v),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(Icons.schedule_rounded, color: scheme.primary),
                title: Text('${formatDate(_start)}, ${formatTime(_start)}'),
                subtitle: const Text('Başlangıç zamanı'),
                onTap: _pickStart,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Süre', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(formatMinutes(_minutes), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.primary)),
              ],
            ),
            Slider(
              value: _minutes.toDouble(),
              min: 5,
              max: 240,
              divisions: 47,
              label: formatMinutes(_minutes),
              onChanged: (v) => setState(() => _minutes = v.round()),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Kaydet')),
          ],
        ),
      ),
    );
  }
}
