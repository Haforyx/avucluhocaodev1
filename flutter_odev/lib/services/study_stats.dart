import '../models/study_session.dart';
import '../models/study_task.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Haftanın başı (Pazartesi). Takvim günüyle hesaplanır; yaz saati
/// geçişinde Duration(days:) gibi bir saat kaymaz.
DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// İki tarih arasındaki takvim günü farkı (saatler yok sayılır). UTC üzerinden
/// hesaplandığı için yaz saati geçişinde 23 saatlik gün 0 sayılmaz.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Takvim günü ekler (yaz saati geçişlerinde Duration(days:) kaymasın diye).
DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Çalışma oturumlarından istatistik çıkaran saf fonksiyonlar.
class StudyStats {
  StudyStats._();

  /// Gün -> dakika. Oturum başladığı güne yazılır.
  static Map<DateTime, int> minutesByDay(Iterable<StudySession> sessions) {
    final map = <DateTime, int>{};
    for (final s in sessions) {
      final day = dateOnly(s.start);
      map[day] = (map[day] ?? 0) + s.minutes;
    }
    return map;
  }

  static int minutesOn(Iterable<StudySession> sessions, DateTime day) =>
      sessions.where((s) => isSameDay(s.start, day)).fold(0, (sum, s) => sum + s.minutes);

  /// [from] gününden başlayarak [days] günün günlük toplamları.
  static List<int> dailyTotals(Iterable<StudySession> sessions, DateTime from, int days) {
    final byDay = minutesByDay(sessions);
    return [for (var i = 0; i < days; i++) byDay[addDays(dateOnly(from), i)] ?? 0];
  }

  static int totalMinutes(Iterable<StudySession> sessions, {DateTime? from, DateTime? to}) =>
      sessions
          .where((s) => (from == null || !s.start.isBefore(from)) && (to == null || s.start.isBefore(to)))
          .fold(0, (sum, s) => sum + s.minutes);

  /// Bugün (ya da bugün henüz çalışılmadıysa dün) biten, art arda çalışılan gün sayısı.
  ///
  /// Bugün çalışılmamış olması seriyi bozmaz; gün bitene kadar seri korunur.
  static int currentStreak(Iterable<StudySession> sessions, DateTime now, {int minMinutes = 1}) {
    final byDay = minutesByDay(sessions);
    bool studied(DateTime day) => (byDay[day] ?? 0) >= minMinutes;

    var day = dateOnly(now);
    if (!studied(day)) day = addDays(day, -1);
    var streak = 0;
    while (studied(day)) {
      streak++;
      day = addDays(day, -1);
    }
    return streak;
  }

  /// Şimdiye kadarki en uzun seri.
  static int bestStreak(Iterable<StudySession> sessions, {int minMinutes = 1}) {
    final days = minutesByDay(sessions).entries
        .where((e) => e.value >= minMinutes)
        .map((e) => e.key)
        .toList()
      ..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in days) {
      run = (previous != null && addDays(previous, 1) == day) ? run + 1 : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  /// Ders id -> dakika (ders seçilmemiş oturumlar null anahtarında). Çoktan aza sıralı.
  static List<MapEntry<String?, int>> minutesByCourse(Iterable<StudySession> sessions) {
    final map = <String?, int>{};
    for (final s in sessions) {
      map[s.courseId] = (map[s.courseId] ?? 0) + s.minutes;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Saat dilimine göre dağılım (0-23). En verimli saatleri göstermek için.
  static List<int> minutesByHour(Iterable<StudySession> sessions) {
    final hours = List<int>.filled(24, 0);
    for (final s in sessions) {
      hours[s.start.hour] += s.minutes;
    }
    return hours;
  }

  /// Hedefin tutturulduğu gün sayısı.
  static int goalDays(Iterable<StudySession> sessions, int goalMinutes, DateTime from, int days) =>
      dailyTotals(sessions, from, days).where((m) => goalMinutes > 0 && m >= goalMinutes).length;
}

/// Görev listesi filtreleri.
enum TaskFilter {
  active('Aktif'),
  today('Bugün'),
  upcoming('Bu hafta'),
  overdue('Geciken'),
  done('Tamamlanan');

  const TaskFilter(this.label);

  final String label;

  bool matches(StudyTask task, DateTime now) {
    final due = task.dueDate;
    final startOfToday = dateOnly(now);
    return switch (this) {
      TaskFilter.active => !task.isDone,
      TaskFilter.today => !task.isDone && due != null && isSameDay(due, now),
      TaskFilter.upcoming => !task.isDone &&
          due != null &&
          !due.isBefore(startOfToday) &&
          due.isBefore(addDays(startOfToday, 7)),
      TaskFilter.overdue => task.isOverdue(now),
      TaskFilter.done => task.isDone,
    };
  }

  /// Filtreye uygun görevler, filtreye uygun sırada.
  List<StudyTask> apply(Iterable<StudyTask> tasks, DateTime now) {
    final list = tasks.where((t) => matches(t, now)).toList();
    if (this == done) {
      list.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    } else {
      list.sort(compareByUrgency);
    }
    return list;
  }

  /// Önce tarihi olanlar (yakın tarih önde), aynı tarihte yüksek öncelik önde.
  static int compareByUrgency(StudyTask a, StudyTask b) {
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad != null && bd != null) {
      final byDate = ad.compareTo(bd);
      if (byDate != 0) return byDate;
    } else if (ad != null) {
      return -1;
    } else if (bd != null) {
      return 1;
    }
    final byPriority = b.priority.index.compareTo(a.priority.index);
    if (byPriority != 0) return byPriority;
    return a.createdAt.compareTo(b.createdAt);
  }
}
