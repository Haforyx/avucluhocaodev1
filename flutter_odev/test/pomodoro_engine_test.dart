import 'package:avuclu_hoca/services/pomodoro_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testte elle ileri sarılan saat.
class FakeClock {
  DateTime now = DateTime(2026, 10, 20, 10);
  void advance(Duration d) => now = now.add(d);
}

void main() {
  late FakeClock clock;
  late PomodoroEngine engine;

  const config = FocusConfig(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15, sessionsBeforeLongBreak: 2);

  setUp(() {
    clock = FakeClock();
    engine = PomodoroEngine(config: config, clock: () => clock.now);
  });

  test('başlangıçta boşta ve tam süre', () {
    expect(engine.status, TimerStatus.idle);
    expect(engine.phase, FocusPhase.focus);
    expect(engine.remaining, const Duration(minutes: 25));
    expect(engine.progress, 0);
  });

  test('kalan süre saatle azalır, duraklatınca durur', () {
    engine.start();
    clock.advance(const Duration(minutes: 10));
    expect(engine.remaining, const Duration(minutes: 15));
    expect(engine.progress, closeTo(0.4, 1e-9));

    engine.pause();
    clock.advance(const Duration(minutes: 30)); // duraklatılmışken geçen süre sayılmaz
    expect(engine.remaining, const Duration(minutes: 15));
    expect(engine.status, TimerStatus.paused);

    engine.start();
    clock.advance(const Duration(minutes: 5));
    expect(engine.remaining, const Duration(minutes: 10));
  });

  test('süre dolunca odak tamamlanır ve kısa molaya geçilir', () {
    engine.start();
    clock.advance(const Duration(minutes: 24));
    expect(engine.tick(), isNull);
    clock.advance(const Duration(minutes: 2));
    final result = engine.tick();
    expect(result, isNotNull);
    expect(result!.phase, FocusPhase.focus);
    expect(result.completed, isTrue);
    expect(result.minutes, 25);
    expect(result.startedAt, DateTime(2026, 10, 20, 10));
    expect(engine.completedFocusCount, 1);
    expect(engine.phase, FocusPhase.shortBreak);
    expect(engine.status, TimerStatus.idle);
    expect(engine.remaining, const Duration(minutes: 5));
  });

  test('ayarlanan sayıda odaktan sonra uzun mola', () {
    void completeCurrent() {
      engine.start();
      clock.advance(engine.remaining);
      engine.tick();
    }

    completeCurrent(); // odak 1
    expect(engine.phase, FocusPhase.shortBreak);
    completeCurrent(); // mola
    expect(engine.phase, FocusPhase.focus);
    completeCurrent(); // odak 2
    expect(engine.phase, FocusPhase.longBreak);
    expect(engine.remaining, const Duration(minutes: 15));
    expect(engine.focusUntilLongBreak, 2);
  });

  test('erken bitirince geçen süre kaydedilir', () {
    engine.start();
    clock.advance(const Duration(minutes: 12, seconds: 40));
    final result = engine.finishEarly();
    expect(result, isNotNull);
    expect(result!.completed, isFalse);
    expect(result.minutes, 13);
    // Erken biten odak uzun mola sayısına katılmaz.
    expect(engine.completedFocusCount, 0);
    expect(engine.phase, FocusPhase.shortBreak);
  });

  test('bir dakikadan kısa erken bitiş kaydedilmez', () {
    engine.start();
    clock.advance(const Duration(seconds: 20));
    expect(engine.finishEarly(), isNull);
  });

  test('atlama odak saymaz', () {
    engine.skip();
    expect(engine.phase, FocusPhase.shortBreak);
    expect(engine.completedFocusCount, 0);
    engine.skip();
    expect(engine.phase, FocusPhase.focus);
  });

  test('ayar değişikliği çalışan evreyi bozmaz', () {
    engine.start();
    clock.advance(const Duration(minutes: 5));
    engine.updateConfig(const FocusConfig(focusMinutes: 50));
    expect(engine.remaining, const Duration(minutes: 20));
    expect(engine.phaseDuration, const Duration(minutes: 25));
    engine.reset();
    expect(engine.remaining, const Duration(minutes: 50));
  });

  test('molayı otomatik başlat', () {
    engine.updateConfig(const FocusConfig(focusMinutes: 25, autoStartBreaks: true));
    engine.start();
    clock.advance(const Duration(minutes: 25));
    engine.tick();
    expect(engine.phase, FocusPhase.shortBreak);
    expect(engine.status, TimerStatus.running);
  });

  test('evre seçimi sayacı sıfırlar', () {
    engine.start();
    clock.advance(const Duration(minutes: 3));
    engine.selectPhase(FocusPhase.longBreak);
    expect(engine.status, TimerStatus.idle);
    expect(engine.remaining, const Duration(minutes: 15));
  });
}
