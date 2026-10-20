import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/study_session.dart';
import '../services/pomodoro_engine.dart';
import 'auth_controller.dart';
import 'data_controllers.dart';
import 'settings_controller.dart';

/// Bir evre bittiğinde ekranlara iletilen olay.
class FocusEvent {
  const FocusEvent(this.result, this.session, this.nextPhase);

  final PhaseResult result;

  /// Odak kaydedildiyse oluşan oturum.
  final StudySession? session;
  final FocusPhase nextPhase;
}

/// Pomodoro sayacını uygulama genelinde çalıştırır.
///
/// Sekme değiştirilse de sayaç devam eder; odak bittiğinde süre seçili derse
/// çalışma oturumu olarak kaydedilir.
class FocusController extends ChangeNotifier {
  FocusController(this._settings, this._sessions, this._auth, {DateTime Function()? clock})
      : _engine = PomodoroEngine(config: _settings.focusConfig, clock: clock) {
    _settings.addListener(_onSettingsChanged);
    _auth.addListener(_onAuthChanged);
    _ownerId = _auth.currentUser?.id;
  }

  final SettingsController _settings;
  final SessionController _sessions;
  final AuthController _auth;
  final PomodoroEngine _engine;
  final _events = StreamController<FocusEvent>.broadcast();
  Timer? _ticker;
  String? _ownerId;

  String? _courseId;
  String? get courseId => _courseId;

  Stream<FocusEvent> get events => _events.stream;

  FocusPhase get phase => _engine.phase;
  TimerStatus get status => _engine.status;
  bool get isRunning => _engine.isRunning;
  Duration get remaining => _engine.remaining;
  double get progress => _engine.progress;
  int get completedFocusCount => _engine.completedFocusCount;
  int get focusUntilLongBreak => _engine.focusUntilLongBreak;
  FocusConfig get config => _engine.config;

  void selectCourse(String? id) {
    _courseId = id;
    notifyListeners();
  }

  void toggle() {
    _engine.toggle();
    _syncTicker();
    notifyListeners();
  }

  void reset() {
    _engine.reset();
    _syncTicker();
    notifyListeners();
  }

  void skip() {
    _engine.skip();
    _syncTicker();
    notifyListeners();
  }

  void selectPhase(FocusPhase phase) {
    _engine.selectPhase(phase);
    _syncTicker();
    notifyListeners();
  }

  /// Odağı erken bitirip geçen süreyi kaydeder.
  Future<void> finishEarly() async {
    final result = _engine.finishEarly();
    _syncTicker();
    notifyListeners();
    if (result != null) await _handle(result);
  }

  Future<void> _onTick() async {
    final result = _engine.tick();
    notifyListeners();
    if (result == null) return;
    _syncTicker();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    await _handle(result);
  }

  Future<void> _handle(PhaseResult result) async {
    StudySession? session;
    if (result.phase == FocusPhase.focus && _auth.isLoggedIn) {
      session = await _sessions.record(
        minutes: result.minutes,
        start: result.startedAt,
        courseId: _courseId,
        source: SessionSource.focus,
      );
    }
    if (!_events.isClosed) _events.add(FocusEvent(result, session, _engine.phase));
  }

  void _syncTicker() {
    if (_engine.isRunning) {
      _ticker ??= Timer.periodic(const Duration(milliseconds: 500), (_) => _onTick());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _onSettingsChanged() {
    _engine.updateConfig(_settings.focusConfig);
    notifyListeners();
  }

  void _onAuthChanged() {
    final id = _auth.currentUser?.id;
    if (id == _ownerId) return;
    _ownerId = id;
    // Kullanıcı değişti: sayaç ve seçili ders sıfırlanır.
    _courseId = null;
    _engine.selectPhase(FocusPhase.focus);
    _engine.updateConfig(_settings.focusConfig);
    _syncTicker();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _events.close();
    _settings.removeListener(_onSettingsChanged);
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
