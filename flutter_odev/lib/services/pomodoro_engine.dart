enum FocusPhase {
  focus('Odak'),
  shortBreak('Kısa mola'),
  longBreak('Uzun mola');

  const FocusPhase(this.label);

  final String label;

  bool get isBreak => this != focus;
}

enum TimerStatus { idle, running, paused }

class FocusConfig {
  const FocusConfig({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoStartBreaks = false,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  final bool autoStartBreaks;

  Duration durationOf(FocusPhase phase) => Duration(
        minutes: switch (phase) {
          FocusPhase.focus => focusMinutes,
          FocusPhase.shortBreak => shortBreakMinutes,
          FocusPhase.longBreak => longBreakMinutes,
        },
      );
}

/// Biten (ya da erken bitirilen) bir evrenin sonucu.
class PhaseResult {
  const PhaseResult({
    required this.phase,
    required this.startedAt,
    required this.focused,
    required this.completed,
  });

  final FocusPhase phase;
  final DateTime startedAt;

  /// Duraklatmalar hariç geçen süre.
  final Duration focused;

  /// Süre dolarak mı bitti, yoksa kullanıcı mı bitirdi?
  final bool completed;

  /// Kayda geçecek dakika (en yakın dakikaya yuvarlanır).
  int get minutes => (focused.inSeconds / 60).round();
}

/// Pomodoro sayacının saf durum makinesi.
///
/// Kalan süre her saniye bir sayaç azaltılarak değil, bitiş anı ile şimdiki
/// zaman karşılaştırılarak hesaplanır. Bu sayede uygulama arka plana atılsa
/// ya da zamanlayıcı gecikse bile süre kaymaz. Saat dışarıdan verildiği için
/// testlerde zaman ileri sarılabilir.
class PomodoroEngine {
  PomodoroEngine({FocusConfig config = const FocusConfig(), DateTime Function()? clock})
      : _config = config,
        _clock = clock ?? DateTime.now,
        _remaining = config.durationOf(FocusPhase.focus);

  final DateTime Function() _clock;
  FocusConfig _config;

  FocusPhase _phase = FocusPhase.focus;
  TimerStatus _status = TimerStatus.idle;
  int _completedFocusCount = 0;

  /// Çalışırken: evrenin biteceği an.
  DateTime? _endsAt;

  /// Duraklatılmış/boştayken: kalan süre.
  Duration _remaining;

  /// Evrenin ilk başlatıldığı an.
  DateTime? _startedAt;

  /// Başlatılmış evrenin süresi. Ayar sonradan değişse de bu evre için sabit kalır.
  Duration? _activeDuration;

  FocusConfig get config => _config;
  FocusPhase get phase => _phase;
  TimerStatus get status => _status;
  bool get isRunning => _status == TimerStatus.running;

  /// Bu oturumda tamamlanan odak sayısı (uzun mola hesabı için).
  int get completedFocusCount => _completedFocusCount;

  Duration get phaseDuration => _activeDuration ?? _config.durationOf(_phase);

  Duration get remaining {
    if (_status != TimerStatus.running) return _remaining;
    final left = _endsAt!.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  Duration get elapsed => phaseDuration - remaining;

  /// 0..1 arası ilerleme.
  double get progress {
    final total = phaseDuration.inMilliseconds;
    if (total == 0) return 1;
    return (elapsed.inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// Uzun molaya kalan odak sayısı.
  int get focusUntilLongBreak {
    final n = _config.sessionsBeforeLongBreak;
    return n - (_completedFocusCount % n);
  }

  /// Ayarlar değişti. Çalışan bir sayaç bozulmasın diye yalnızca boştayken
  /// süreye yansır.
  void updateConfig(FocusConfig config) {
    _config = config;
    if (_status == TimerStatus.idle) _remaining = phaseDuration;
  }

  void start() {
    if (_status == TimerStatus.running) return;
    final now = _clock();
    _startedAt ??= now;
    _activeDuration ??= _config.durationOf(_phase);
    _endsAt = now.add(_remaining);
    _status = TimerStatus.running;
  }

  void pause() {
    if (_status != TimerStatus.running) return;
    _remaining = remaining;
    _endsAt = null;
    _status = TimerStatus.paused;
  }

  void toggle() => isRunning ? pause() : start();

  /// Evreyi baştan alır (kayıt yapılmaz).
  void reset() {
    _status = TimerStatus.idle;
    _endsAt = null;
    _startedAt = null;
    _activeDuration = null;
    _remaining = phaseDuration;
  }

  /// Seçilen evreye geçer (sayaç durur).
  void selectPhase(FocusPhase phase) {
    _phase = phase;
    reset();
  }

  /// Zamanlayıcı her tetiklendiğinde çağrılır. Süre dolduysa evreyi bitirir
  /// ve sonucunu döner; dolmadıysa null.
  PhaseResult? tick() {
    if (_status != TimerStatus.running || remaining > Duration.zero) return null;
    return _finish(completed: true);
  }

  /// Odağı erken bitirir. Geçen süre kaydedilebilir; bir dakikadan azsa null.
  PhaseResult? finishEarly() {
    if (_status == TimerStatus.idle) return null;
    final result = _finish(completed: false);
    return result.minutes >= 1 ? result : null;
  }

  /// Evreyi atlar: odak sayılmaz, sonraki evreye geçilir.
  void skip() {
    _advance(countFocus: false, autoStart: false);
  }

  PhaseResult _finish({required bool completed}) {
    final result = PhaseResult(
      phase: _phase,
      startedAt: _startedAt ?? _clock(),
      focused: completed ? phaseDuration : elapsed,
      completed: completed,
    );
    _advance(
      countFocus: _phase == FocusPhase.focus && completed,
      autoStart: completed && _phase == FocusPhase.focus && _config.autoStartBreaks,
    );
    return result;
  }

  void _advance({required bool countFocus, required bool autoStart}) {
    if (_phase == FocusPhase.focus) {
      if (countFocus) _completedFocusCount++;
      final long = countFocus && _completedFocusCount % _config.sessionsBeforeLongBreak == 0;
      _phase = long ? FocusPhase.longBreak : FocusPhase.shortBreak;
    } else {
      _phase = FocusPhase.focus;
    }
    reset();
    if (autoStart) start();
  }
}
