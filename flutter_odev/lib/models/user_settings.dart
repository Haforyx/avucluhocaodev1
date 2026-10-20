import 'package:flutter/material.dart';

/// Kullanıcıya özel tercihler.
class UserSettings {
  const UserSettings({
    this.themeMode = ThemeMode.system,
    this.dailyGoalMinutes = 120,
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoStartBreaks = false,
  });

  final ThemeMode themeMode;
  final int dailyGoalMinutes;
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;

  /// Odak bitince molayı kendiliğinden başlat.
  final bool autoStartBreaks;

  UserSettings copyWith({
    ThemeMode? themeMode,
    int? dailyGoalMinutes,
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? sessionsBeforeLongBreak,
    bool? autoStartBreaks,
  }) =>
      UserSettings(
        themeMode: themeMode ?? this.themeMode,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        focusMinutes: focusMinutes ?? this.focusMinutes,
        shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
        longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
        sessionsBeforeLongBreak: sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
        autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'dailyGoalMinutes': dailyGoalMinutes,
        'focusMinutes': focusMinutes,
        'shortBreakMinutes': shortBreakMinutes,
        'longBreakMinutes': longBreakMinutes,
        'sessionsBeforeLongBreak': sessionsBeforeLongBreak,
        'autoStartBreaks': autoStartBreaks,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    const d = UserSettings();
    return UserSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == json['themeMode'],
        orElse: () => d.themeMode,
      ),
      dailyGoalMinutes: json['dailyGoalMinutes'] as int? ?? d.dailyGoalMinutes,
      focusMinutes: json['focusMinutes'] as int? ?? d.focusMinutes,
      shortBreakMinutes: json['shortBreakMinutes'] as int? ?? d.shortBreakMinutes,
      longBreakMinutes: json['longBreakMinutes'] as int? ?? d.longBreakMinutes,
      sessionsBeforeLongBreak: json['sessionsBeforeLongBreak'] as int? ?? d.sessionsBeforeLongBreak,
      autoStartBreaks: json['autoStartBreaks'] as bool? ?? d.autoStartBreaks,
    );
  }
}
