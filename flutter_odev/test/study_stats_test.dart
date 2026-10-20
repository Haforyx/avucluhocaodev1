import 'package:avuclu_hoca/models/study_session.dart';
import 'package:avuclu_hoca/models/study_task.dart';
import 'package:avuclu_hoca/services/study_stats.dart';
import 'package:avuclu_hoca/utils/format.dart';
import 'package:avuclu_hoca/utils/text_utils.dart';
import 'package:avuclu_hoca/widgets/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

var _id = 0;

StudySession session(DateTime start, int minutes, [String? course]) => StudySession(
      id: '${_id++}',
      ownerId: 'u',
      courseId: course,
      start: start,
      minutes: minutes,
    );

StudyTask task(String title, {DateTime? due, TaskPriority priority = TaskPriority.normal, DateTime? done}) =>
    StudyTask(
      id: title,
      ownerId: 'u',
      title: title,
      dueDate: due,
      priority: priority,
      createdAt: DateTime(2026, 10, 1),
      completedAt: done,
    );

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  // 20 Ekim 2026 Salı, 15:00
  final now = DateTime(2026, 10, 20, 15);

  group('Tarih yardımcıları', () {
    test('hafta Pazartesi başlar', () {
      expect(startOfWeek(now), DateTime(2026, 10, 19));
      expect(startOfWeek(DateTime(2026, 10, 25, 23)), DateTime(2026, 10, 19)); // Pazar
      expect(startOfWeek(DateTime(2026, 10, 26)), DateTime(2026, 10, 26));
    });

    test('takvim günü farkı saatleri yok sayar', () {
      expect(daysBetween(DateTime(2026, 10, 20, 23), DateTime(2026, 10, 21, 1)), 1);
      expect(daysBetween(DateTime(2026, 10, 20, 1), DateTime(2026, 10, 20, 23)), 0);
      expect(daysBetween(DateTime(2026, 10, 25), DateTime(2026, 10, 18)), -7);
      expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2); // yaz saati geçişi
    });

    test('takvim günü ekleme ay sonunu aşar', () {
      expect(addDays(DateTime(2026, 10, 31), 1), DateTime(2026, 11, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });
  });

  group('Çalışma istatistikleri', () {
    final sessions = [
      session(DateTime(2026, 10, 20, 9), 25, 'mat'),
      session(DateTime(2026, 10, 20, 11), 50, 'fiz'),
      session(DateTime(2026, 10, 19, 20), 30, 'mat'),
      session(DateTime(2026, 10, 18, 10), 45),
      session(DateTime(2026, 10, 15, 10), 60, 'mat'), // seri burada kopuk (16-17 boş)
      session(DateTime(2026, 10, 14, 10), 60, 'mat'),
      session(DateTime(2026, 10, 13, 10), 60, 'mat'),
      session(DateTime(2026, 10, 12, 10), 60, 'mat'),
    ];

    test('bugünkü dakika', () {
      expect(StudyStats.minutesOn(sessions, now), 75);
    });

    test('günlük toplamlar', () {
      expect(StudyStats.dailyTotals(sessions, DateTime(2026, 10, 17), 4), [0, 45, 30, 75]);
    });

    test('aralık toplamı', () {
      expect(StudyStats.totalMinutes(sessions, from: startOfWeek(now)), 105);
      expect(StudyStats.totalMinutes(sessions), 390);
    });

    test('güncel seri: bugün dahil 3 gün', () {
      expect(StudyStats.currentStreak(sessions, now), 3);
    });

    test('bugün henüz çalışılmadıysa seri dünden sayılır', () {
      final withoutToday = sessions.where((s) => s.start.day != 20).toList();
      expect(StudyStats.currentStreak(withoutToday, now), 2);
    });

    test('dün de çalışılmadıysa seri sıfır', () {
      expect(StudyStats.currentStreak(sessions, DateTime(2026, 10, 23)), 0);
    });

    test('en uzun seri', () {
      expect(StudyStats.bestStreak(sessions), 4); // 12-15 Ekim
      expect(StudyStats.bestStreak(const []), 0);
    });

    test('derslere göre dağılım (çoktan aza)', () {
      final byCourse = StudyStats.minutesByCourse(sessions);
      expect(byCourse.first.key, 'mat');
      expect(byCourse.first.value, 295);
      expect(byCourse.map((e) => e.key), containsAll(<String?>['fiz', null]));
    });

    test('saat dağılımı', () {
      final hours = StudyStats.minutesByHour(sessions);
      expect(hours[10], 285);
      expect(hours[20], 30);
      expect(hours.fold(0, (a, b) => a + b), 390);
    });

    test('hedef tutturulan gün sayısı', () {
      expect(StudyStats.goalDays(sessions, 60, DateTime(2026, 10, 12), 9), 5);
    });
  });

  group('Görev filtreleri', () {
    final tasks = [
      task('geciken', due: DateTime(2026, 10, 19, 23, 59)),
      task('bugün sabah geçti', due: DateTime(2026, 10, 20, 9)),
      task('bugün akşam', due: DateTime(2026, 10, 20, 21)),
      task('bugün öncelikli', due: DateTime(2026, 10, 20, 21), priority: TaskPriority.high),
      task('yarın', due: DateTime(2026, 10, 21, 12)),
      task('gelecek hafta', due: DateTime(2026, 10, 28)),
      task('tarihsiz'),
      task('bitti', due: DateTime(2026, 10, 18), done: DateTime(2026, 10, 17)),
    ];

    List<String> titles(TaskFilter f) => f.apply(tasks, now).map((t) => t.title).toList();

    test('aktif: tarihliler önce, aynı saatte yüksek öncelik önde', () {
      expect(titles(TaskFilter.active), [
        'geciken',
        'bugün sabah geçti',
        'bugün öncelikli',
        'bugün akşam',
        'yarın',
        'gelecek hafta',
        'tarihsiz',
      ]);
    });

    test('bugün', () {
      expect(titles(TaskFilter.today), ['bugün sabah geçti', 'bugün öncelikli', 'bugün akşam']);
    });

    test('bu hafta (bugünden itibaren 7 gün)', () {
      expect(titles(TaskFilter.upcoming), ['bugün sabah geçti', 'bugün öncelikli', 'bugün akşam', 'yarın']);
    });

    test('geciken', () {
      expect(titles(TaskFilter.overdue), ['geciken', 'bugün sabah geçti']);
    });

    test('tamamlanan', () {
      expect(titles(TaskFilter.done), ['bitti']);
    });
  });

  group('Biçimlendirme', () {
    test('dakika', () {
      expect(formatMinutes(40), '40 dk');
      expect(formatMinutes(60), '1 sa');
      expect(formatMinutes(95), '1 sa 35 dk');
    });

    test('grafik ekseni için kısa süre', () {
      expect(formatMinutesShort(45), '45 dk');
      expect(formatMinutesShort(60), '1 sa');
      expect(formatMinutesShort(90), '1,5 sa');
      expect(formatMinutesShort(720), '12 sa');
    });

    test('ders rozeti baş harfleri', () {
      expect(courseInitials('Veri Yapıları'), 'VY');
      expect(courseInitials('Olasılık ve İstatistik'), 'Oİ');
      expect(courseInitials('fizik'), 'Fi');
      expect(courseInitials('  '), '?');
    });

    test('düzenleme alanı hassasiyeti korur', () {
      expect(formatEditable(33.333), '33,333');
      expect(formatEditable(40), '40');
      expect(formatScore(72.25), '72,3');
    });

    test('sayaç', () {
      expect(formatClock(const Duration(minutes: 24, seconds: 5)), '24:05');
      expect(formatClock(const Duration(seconds: -3)), '00:00');
    });

    test('selam', () {
      expect(timeGreeting(DateTime(2026, 1, 1, 8)), 'Günaydın');
      expect(timeGreeting(DateTime(2026, 1, 1, 14)), 'İyi günler');
      expect(timeGreeting(DateTime(2026, 1, 1, 20)), 'İyi akşamlar');
      expect(timeGreeting(DateTime(2026, 1, 1, 2)), 'İyi geceler');
    });

    test('teslim tarihi', () {
      expect(formatDue(DateTime(2026, 10, 20, 17), now), 'Bugün 17:00');
      expect(formatDue(DateTime(2026, 10, 20, 9), now), 'Bugün 09:00');
      expect(formatDue(DateTime(2026, 10, 20, 23, 59), now), 'Bugün');
      expect(formatDue(DateTime(2026, 10, 21, 23, 59), now), 'Yarın');
      expect(formatDue(DateTime(2026, 10, 17, 23, 59), now), '3 gün gecikti');
      expect(formatDue(DateTime(2026, 10, 23, 12), now), 'Cuma 12:00');
      expect(formatCountdown(DateTime(2026, 10, 29), now), '9 gün kaldı');
    });

    test('Türkçe büyük/küçük harf', () {
      expect(trCapitalize('hakan'), 'Hakan');
      expect(trCapitalize('irem'), 'İrem');
      expect(trCapitalize('ILGAZ'), 'Ilgaz');
      expect(trTitleCase('  hakan   yılmaz '), 'Hakan Yılmaz');
      expect(trUpper('bilgi'), 'BİLGİ');
      expect(foldForSearch('Çalışma ŞİİR'), 'calisma siir');
    });
  });
}
