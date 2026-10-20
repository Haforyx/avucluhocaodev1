import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/course.dart';
import '../../services/grade_calculator.dart';
import '../../services/validators.dart';
import '../../state/data_controllers.dart';
import '../../utils/format.dart';
import '../../utils/ids.dart';
import '../../widgets/common.dart';

/// Hazır değerlendirme şablonları.
const _presets = <String, List<(String, double)>>{
  'Vize + Final': [('Vize', 40), ('Final', 60)],
  'Vize + Ödev + Final': [('Vize', 30), ('Ödev', 20), ('Final', 50)],
  'Vize + Proje + Final': [('Vize', 30), ('Proje', 30), ('Final', 40)],
  '2 Vize + Final': [('1. Vize', 25), ('2. Vize', 25), ('Final', 50)],
};

/// Ders ekleme ve düzenleme.
class CourseFormScreen extends StatefulWidget {
  const CourseFormScreen({super.key, this.course});

  final Course? course;

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _AssessmentDraft {
  _AssessmentDraft({String? id, String name = '', double? weight, double? score, this.date})
      : id = id ?? newId(),
        name = TextEditingController(text: name),
        weight = TextEditingController(text: weight == null ? '' : formatEditable(weight)),
        score = TextEditingController(text: score == null ? '' : formatEditable(score));

  final String id;
  final TextEditingController name;
  final TextEditingController weight;
  final TextEditingController score;
  final DateTime? date;

  double get weightValue => double.tryParse(weight.text.replaceAll(',', '.')) ?? 0;

  Assessment toAssessment() {
    final s = score.text.trim();
    return Assessment(
      id: id,
      name: name.text.trim(),
      weight: weightValue,
      score: s.isEmpty ? null : double.parse(s.replaceAll(',', '.')),
      date: date,
    );
  }

  void dispose() {
    name.dispose();
    weight.dispose();
    score.dispose();
  }
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.course?.name ?? '');
  late final _code = TextEditingController(text: widget.course?.code ?? '');
  late final _instructor = TextEditingController(text: widget.course?.instructor ?? '');
  late int _credits = widget.course?.credits ?? 5;
  late int _colorIndex;
  late int _weeklyGoal = widget.course?.weeklyGoalMinutes ?? 180;
  late final List<_AssessmentDraft> _drafts;
  bool _showWeightError = false;

  bool get _editing => widget.course != null;

  @override
  void initState() {
    super.initState();
    _colorIndex = widget.course?.colorIndex ?? context.read<CourseController>().suggestColorIndex();
    final existing = widget.course?.assessments;
    _drafts = existing != null && existing.isNotEmpty
        ? [
            for (final a in existing)
              _AssessmentDraft(id: a.id, name: a.name, weight: a.weight, score: a.score, date: a.date),
          ]
        : [for (final (n, w) in _presets.values.first) _AssessmentDraft(name: n, weight: w)];
    for (final d in _drafts) {
      d.weight.addListener(_onWeightChanged);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _instructor.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _onWeightChanged() => setState(() {});

  double get _totalWeight => _drafts.fold(0, (s, d) => s + d.weightValue);

  void _applyPreset(List<(String, double)> preset) {
    setState(() {
      for (final d in _drafts) {
        d.dispose();
      }
      _drafts
        ..clear()
        ..addAll([for (final (n, w) in preset) _AssessmentDraft(name: n, weight: w)..weight.addListener(_onWeightChanged)]);
    });
  }

  void _addDraft() {
    final left = (100 - _totalWeight).clamp(0, 100).toDouble();
    setState(() => _drafts.add(
          _AssessmentDraft(name: '', weight: left == 0 ? null : left)..weight.addListener(_onWeightChanged),
        ));
  }

  void _removeDraft(int i) {
    setState(() => _drafts.removeAt(i).dispose());
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    final weightOk = _drafts.isNotEmpty && (_totalWeight - 100).abs() <= weightTolerance;
    setState(() => _showWeightError = !weightOk);
    if (!valid || !weightOk) return;

    final controller = context.read<CourseController>();
    final assessments = [for (final d in _drafts) d.toAssessment()];
    final existing = widget.course;
    if (existing == null) {
      await controller.create(
        name: _name.text,
        code: _code.text,
        instructor: _instructor.text,
        credits: _credits,
        colorIndex: _colorIndex,
        assessments: assessments,
        weeklyGoalMinutes: _weeklyGoal,
      );
    } else {
      await controller.save(
        existing.copyWith(
          name: _name.text.trim(),
          code: _code.text.trim(),
          instructor: _instructor.text.trim(),
          credits: _credits,
          colorIndex: _colorIndex,
          assessments: assessments,
          weeklyGoalMinutes: _weeklyGoal,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _totalWeight;
    final weightOk = (total - 100).abs() <= weightTolerance;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Dersi düzenle' : 'Yeni ders')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            TextFormField(
              key: const Key('course-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ders adı', hintText: 'Örn. Mobil Programlama'),
              validator: (v) => Validators.required(v, 'Ders adını yaz.'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Ders kodu', hintText: 'BİL304'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _CreditStepper(value: _credits, onChanged: (v) => setState(() => _credits = v))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructor,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Öğretim üyesi (isteğe bağlı)'),
            ),
            const SectionHeader(title: 'Renk'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < coursePalette.length; i++)
                  Semantics(
                    button: true,
                    selected: _colorIndex == i,
                    label: 'Renk ${i + 1}',
                    child: GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: coursePalette[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorIndex == i ? scheme.onSurface : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _colorIndex == i ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                      ),
                    ),
                  ),
              ],
            ),
            SectionHeader(
              title: 'Haftalık çalışma hedefi',
              action: Text(
                _weeklyGoal == 0 ? 'Hedef yok' : formatMinutes(_weeklyGoal),
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
              ),
            ),
            Slider(
              value: _weeklyGoal.toDouble(),
              max: 900,
              divisions: 30,
              label: _weeklyGoal == 0 ? 'Hedef yok' : formatMinutes(_weeklyGoal),
              onChanged: (v) => setState(() => _weeklyGoal = v.round()),
            ),
            SectionHeader(
              title: 'Değerlendirme',
              action: Tag(
                label: 'Toplam %${formatScore(total)}',
                color: weightOk ? const Color(0xFF10B981) : scheme.error,
                icon: weightOk ? Icons.check_rounded : Icons.error_outline_rounded,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _presets.entries)
                  ActionChip(label: Text(e.key), onPressed: () => _applyPreset(e.value)),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _drafts.length; i++) ...[
              _AssessmentRow(
                key: ValueKey(_drafts[i].id),
                draft: _drafts[i],
                onRemove: _drafts.length > 1 ? () => _removeDraft(i) : null),
              const SizedBox(height: 10),
            ],
            if (_showWeightError && !weightOk)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ErrorBanner(
                  message: 'Ağırlıkların toplamı %100 olmalı (şu an %${formatScore(total)}).',
                ),
              ),
            OutlinedButton.icon(
              onPressed: _addDraft,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Değerlendirme ekle'),
            ),
            const SizedBox(height: 8),
            Text(
              'Notları şimdi ya da açıklandıkça ders sayfasından girebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('course-save'),
              onPressed: _save,
              child: Text(_editing ? 'Kaydet' : 'Dersi ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({super.key, required this.draft, required this.onRemove});

  final _AssessmentDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final numberFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: TextFormField(
            controller: draft.name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Ad'),
            validator: (v) => Validators.required(v, 'Ad gir.'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: draft.weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [numberFormatter],
            decoration: const InputDecoration(labelText: 'Ağırlık', suffixText: '%'),
            validator: Validators.weight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: draft.score,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [numberFormatter],
            decoration: const InputDecoration(labelText: 'Not'),
            validator: Validators.optionalScore,
          ),
        ),
        SizedBox(
          width: 40,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: IconButton(
              tooltip: 'Kaldır',
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreditStepper extends StatelessWidget {
  const _CreditStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Kredi / AKTS',
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Azalt',
            visualDensity: VisualDensity.compact,
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            tooltip: 'Artır',
            visualDensity: VisualDensity.compact,
            onPressed: value < 30 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
