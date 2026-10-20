import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final s = controller.settings;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const SectionHeader(title: 'Görünüm', padding: EdgeInsets.fromLTRB(4, 8, 0, 10)),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistem'), icon: Icon(Icons.brightness_auto_rounded)),
              ButtonSegment(value: ThemeMode.light, label: Text('Açık'), icon: Icon(Icons.light_mode_rounded)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Koyu'), icon: Icon(Icons.dark_mode_rounded)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => controller.update((s) => s.copyWith(themeMode: v.first)),
          ),
          SectionHeader(
            title: 'Günlük çalışma hedefi',
            action: Text(formatMinutes(s.dailyGoalMinutes), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Column(
                children: [
                  Slider(
                    value: s.dailyGoalMinutes.toDouble(),
                    min: 15,
                    max: 600,
                    divisions: 39,
                    label: formatMinutes(s.dailyGoalMinutes),
                    onChanged: (v) => controller.update((s) => s.copyWith(dailyGoalMinutes: v.round())),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      'Ana sayfadaki halka ve istatistiklerdeki kesikli çizgi bu hedefe göre çizilir.',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Odak sayacı'),
          CardList(
            children: [
              _MinuteStepper(
                label: 'Odak süresi',
                icon: Icons.timer_rounded,
                value: s.focusMinutes,
                min: 5,
                max: 120,
                step: 5,
                onChanged: (v) => controller.update((s) => s.copyWith(focusMinutes: v)),
              ),
              _MinuteStepper(
                label: 'Kısa mola',
                icon: Icons.coffee_rounded,
                value: s.shortBreakMinutes,
                min: 1,
                max: 30,
                step: 1,
                onChanged: (v) => controller.update((s) => s.copyWith(shortBreakMinutes: v)),
              ),
              _MinuteStepper(
                label: 'Uzun mola',
                icon: Icons.weekend_rounded,
                value: s.longBreakMinutes,
                min: 5,
                max: 60,
                step: 5,
                onChanged: (v) => controller.update((s) => s.copyWith(longBreakMinutes: v)),
              ),
              _MinuteStepper(
                label: 'Uzun mola sıklığı',
                icon: Icons.repeat_rounded,
                value: s.sessionsBeforeLongBreak,
                min: 2,
                max: 8,
                step: 1,
                unit: 'odakta bir',
                onChanged: (v) => controller.update((s) => s.copyWith(sessionsBeforeLongBreak: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.play_circle_outline_rounded),
                title: const Text('Molayı otomatik başlat'),
                subtitle: const Text('Odak bitince mola sayacı kendiliğinden başlar.'),
                value: s.autoStartBreaks,
                onChanged: (v) => controller.update((s) => s.copyWith(autoStartBreaks: v)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Süre değişiklikleri çalışan bir sayacı bozmaz; bir sonraki evrede geçerli olur.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _MinuteStepper extends StatelessWidget {
  const _MinuteStepper({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.unit = 'dk',
  });

  final String label;
  final IconData icon;
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Azalt',
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 74,
            child: Text(
              '$value $unit',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Artır',
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
