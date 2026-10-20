import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../models/user_settings.dart';
import '../services/pomodoro_engine.dart';
import 'auth_controller.dart';

/// Giriş yapmış kullanıcının tercihleri (tema, günlük hedef, odak süreleri).
class SettingsController extends ChangeNotifier {
  SettingsController(this._db, this._auth) {
    _auth.addListener(_onAuthChanged);
    _load();
  }

  final AppDatabase _db;
  final AuthController _auth;
  String? _ownerId;
  UserSettings _settings = const UserSettings();

  UserSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;

  FocusConfig get focusConfig => FocusConfig(
        focusMinutes: _settings.focusMinutes,
        shortBreakMinutes: _settings.shortBreakMinutes,
        longBreakMinutes: _settings.longBreakMinutes,
        sessionsBeforeLongBreak: _settings.sessionsBeforeLongBreak,
        autoStartBreaks: _settings.autoStartBreaks,
      );

  Future<void> update(UserSettings Function(UserSettings s) change) async {
    _settings = change(_settings);
    notifyListeners();
    final owner = _ownerId;
    if (owner != null) await _db.settings.put(owner, _settings.toJson());
  }

  void _onAuthChanged() {
    if (_auth.currentUser?.id == _ownerId) return;
    _load();
    notifyListeners();
  }

  void _load() {
    _ownerId = _auth.currentUser?.id;
    final json = _ownerId == null ? null : _db.settings.get(_ownerId!);
    _settings = json == null ? const UserSettings() : UserSettings.fromJson(json);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
