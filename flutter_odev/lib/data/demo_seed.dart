import 'dart:math';

import '../models/app_user.dart';
import '../models/course.dart';
import '../models/study_session.dart';
import '../models/study_task.dart';
import '../services/password_hasher.dart';
import '../services/study_stats.dart';
import '../utils/ids.dart';
import 'app_database.dart';

/// Uygulamayı boş ekranlarla değil, dolu haliyle görmek için örnek hesap.
///
/// Kullanıcı adı `demo`, şifre `demo1234`. Giriş ekranındaki
/// "Demo hesabıyla dene" düğmesi bu hesabı oluşturup açar.
class DemoSeeder {
  DemoSeeder(this._db, this._hasher, this._clock);

  static const username = 'demo';
  static const password = 'demo1234';

  final AppDatabase _db;
  final PasswordHasher _hasher;
  final DateTime Function() _clock;

  Future<AppUser> ensureDemoUser() async {
    for (final json in _db.users.all()) {
      final user = AppUser.fromJson(json);
      if (user.username == username) return user;
    }

    final now = _clock();
    final salt = PasswordHasher.newSalt();
    final answerSalt = PasswordHasher.newSalt();
    final user = AppUser(
      id: newId(),
      fullName: 'Hakan Demir',
      username: username,
      email: 'demo@avucluhoca.app',
      passwordHash: _hasher.hash(password, salt),
      salt: salt,
      iterations: _hasher.iterations,
      securityQuestion: 'Doğduğun şehir neresi?',
      securityAnswerHash: '$answerSalt:${_hasher.hash('istanbul', answerSalt)}',
      createdAt: now.subtract(const Duration(days: 30)),
      lastLoginAt: now,
      school: 'Avuçlu Hoca Üniversitesi',
      department: 'Bilgisayar Mühendisliği',
    );
    await _db.users.put(user.id, user.toJson());
    await _seedData(user.id, now);
    return user;
  }

  Future<void> _seedData(String ownerId, DateTime now) async {
    final today = dateOnly(now);
    DateTime at(int dayOffset, int hour, [int minute = 0]) =>
        DateTime(today.year, today.month, today.day + dayOffset, hour, minute);

    Assessment a(String name, double weight, [double? score, DateTime? date]) =>
        Assessment(id: newId(), name: name, weight: weight, score: score, date: date);

    // Farklı oluşturma anları: ders listesi her açılışta aynı sırada görünsün.
    final courses = [
      Course(
        id: newId(),
        ownerId: ownerId,
        name: 'Mobil Programlama',
        code: 'BİL304',
        instructor: 'Dr. Öğr. Üyesi Selin Kaya',
        credits: 6,
        colorIndex: 0,
        weeklyGoalMinutes: 300,
        createdAt: now.add(const Duration(seconds: 0)),
        assessments: [a('Vize', 30, 88), a('Proje', 30, 95), a('Final', 40, null, at(12, 10))],
      ),
      Course(
        id: newId(),
        ownerId: ownerId,
        name: 'Veri Yapıları',
        code: 'BİL203',
        instructor: 'Prof. Dr. Murat Aydın',
        credits: 5,
        colorIndex: 2,
        weeklyGoalMinutes: 240,
        createdAt: now.add(const Duration(seconds: 1)),
        assessments: [a('Vize', 40, 72), a('Ödev', 10, 100), a('Final', 50, null, at(15, 13, 30))],
      ),
      Course(
        id: newId(),
        ownerId: ownerId,
        name: 'Olasılık ve İstatistik',
        code: 'MAT221',
        instructor: 'Doç. Dr. Ayşe Yıldız',
        credits: 4,
        colorIndex: 3,
        weeklyGoalMinutes: 180,
        createdAt: now.add(const Duration(seconds: 2)),
        assessments: [a('Vize', 40, 58), a('Final', 60, null, at(9, 9))],
      ),
      Course(
        id: newId(),
        ownerId: ownerId,
        name: 'Veritabanı Sistemleri',
        code: 'BİL305',
        instructor: 'Dr. Can Öztürk',
        credits: 5,
        colorIndex: 1,
        createdAt: now.add(const Duration(seconds: 3)),
        assessments: [a('Vize', 30, 81), a('Laboratuvar', 20, 90), a('Final', 50, 77)],
      ),
      Course(
        id: newId(),
        ownerId: ownerId,
        name: 'Teknik İngilizce',
        code: 'İNG201',
        instructor: 'Okt. Emily Clark',
        credits: 3,
        colorIndex: 5,
        createdAt: now.add(const Duration(seconds: 4)),
        assessments: [a('Vize', 40, 92), a('Sunum', 20, 85), a('Final', 40, 90)],
      ),
    ];
    for (final c in courses) {
      await _db.courses.put(c.id, c.toJson());
    }

    final mobile = courses[0].id;
    final ds = courses[1].id;
    final stats = courses[2].id;
    final dbCourse = courses[3].id;

    final tasks = [
      StudyTask(
        id: newId(),
        ownerId: ownerId,
        title: 'Login ve register ekranlarını bitir',
        note: 'Giriş yapınca "Merhaba <ad>" yazsın. Form doğrulamaları unutulmasın.',
        courseId: mobile,
        kind: TaskKind.homework,
        priority: TaskPriority.high,
        dueDate: at(1, 23, 59),
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      StudyTask(
        id: newId(),
        ownerId: ownerId,
        title: 'Olasılık 5. hafta problem seti',
        courseId: stats,
        kind: TaskKind.homework,
        dueDate: at(0, 17),
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      StudyTask(
        id: newId(),
        ownerId: ownerId,
        title: 'AVL ağacı dönüşlerini tekrar et',
        courseId: ds,
        kind: TaskKind.reading,
        priority: TaskPriority.low,
        dueDate: at(0, 21),
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      StudyTask(
        id: newId(),
        ownerId: ownerId,
        title: 'Olasılık finali',
        note: 'Konular: koşullu olasılık, Bayes, binom ve normal dağılım.',
        courseId: stats,
        kind: TaskKind.exam,
        priority: TaskPriority.high,
        dueDate: at(9, 9),
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      StudyTask(
        id: newId(),
        ownerId: ownerId,
        title: 'Veri Yapıları finali',
        courseId: ds,
        kind: TaskKind.exam,
        priority: TaskPriority.high,
        dueDate: at(15, 13, 30),
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      StudyTask(
        id: newId(),
        ownerId: ownerId,
        title: 'Flutter proje raporu',
        courseId: mobile,
        kind: TaskKind.project,
        dueDate: at(5, 12),
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      StudyTask(
        id: newId(),
        ownerId: ownerId,
        title: 'SQL normalizasyon ödevi',
        courseId: dbCourse,
        kind: TaskKind.homework,
        dueDate: at(-1, 23, 59),
        createdAt: now.subtract(const Duration(days: 8)),
      ),
      StudyTask(
        id: newId(),
        ownerId: ownerId,
        title: 'Hash tablosu uygulaması',
        courseId: ds,
        kind: TaskKind.homework,
        dueDate: at(-3, 23, 59),
        createdAt: now.subtract(const Duration(days: 12)),
        completedAt: at(-4, 20),
      ),
      StudyTask(
        id: newId(),
        ownerId: ownerId,
        title: 'Kütüphaneden kitap iadesi',
        kind: TaskKind.other,
        priority: TaskPriority.low,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    for (final t in tasks) {
      await _db.tasks.put(t.id, t.toJson());
    }

    // Son 4 haftaya dağılmış, gerçekçi görünen çalışma oturumları.
    final random = Random(42);
    final courseIds = [mobile, mobile, ds, ds, stats, dbCourse, courses[4].id];
    for (var day = -27; day <= 0; day++) {
      // Arada çalışılmayan günler olsun; son 6 gün kesintisiz (seri görünsün).
      if (day < -6 && random.nextInt(4) == 0) continue;
      final count = day == 0 ? 2 : 2 + random.nextInt(3);
      var hour = 9 + random.nextInt(3);
      for (var i = 0; i < count; i++) {
        final minutes = [25, 25, 50, 45, 30, 60][random.nextInt(6)];
        final start = at(day, hour, random.nextInt(4) * 15);
        if (day == 0 && start.isAfter(now)) break;
        final session = StudySession(
          id: newId(),
          ownerId: ownerId,
          courseId: courseIds[random.nextInt(courseIds.length)],
          start: start,
          minutes: minutes,
          source: random.nextInt(5) == 0 ? SessionSource.manual : SessionSource.focus,
        );
        await _db.sessions.put(session.id, session.toJson());
        hour += 2 + random.nextInt(2);
      }
    }
  }
}
