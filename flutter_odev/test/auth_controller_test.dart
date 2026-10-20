import 'package:avuclu_hoca/data/app_database.dart';
import 'package:avuclu_hoca/services/password_hasher.dart';
import 'package:avuclu_hoca/state/auth_controller.dart';
import 'package:avuclu_hoca/state/data_controllers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late AuthController auth;

  // Testler hızlı çalışsın diye düşük tur sayısı.
  const hasher = PasswordHasher(iterations: 10);

  AuthController newAuth() => AuthController(db, hasher: hasher, clock: () => now);

  Future<String?> registerHakan(AuthController a) => a.register(
        fullName: 'hakan yılmaz',
        username: 'Hakan',
        email: 'Hakan@Mail.com',
        password: 'gizli1234',
        securityQuestion: securityQuestions[2],
        securityAnswer: '  İstanbul ',
      );

  setUp(() {
    db = AppDatabase.inMemory();
    now = DateTime(2026, 10, 20, 12);
    auth = newAuth();
  });

  test('kayıt olunca oturum açılır ve ad düzgün yazılır', () async {
    expect(await registerHakan(auth), isNull);
    final user = auth.currentUser!;
    expect(user.fullName, 'Hakan Yılmaz');
    expect(user.firstName, 'Hakan');
    expect(user.initials, 'HY');
    expect(user.email, 'hakan@mail.com');
    // Şifre açık metin olarak saklanmaz.
    expect(db.users.get(user.id).toString(), isNot(contains('gizli1234')));
  });

  test('aynı kullanıcı adı veya e-posta ile ikinci kayıt reddedilir', () async {
    await registerHakan(auth);
    await auth.logout();
    expect(
      await auth.register(
        fullName: 'Başka',
        username: 'hakan',
        email: 'baska@mail.com',
        password: 'gizli1234',
        securityQuestion: securityQuestions.first,
        securityAnswer: 'x',
      ),
      contains('kullanıcı adı'),
    );
    expect(
      await auth.register(
        fullName: 'Başka',
        username: 'baska',
        email: 'HAKAN@mail.com',
        password: 'gizli1234',
        securityQuestion: securityQuestions.first,
        securityAnswer: 'x',
      ),
      contains('e-posta'),
    );
  });

  test('kullanıcı adı ya da e-posta ile giriş', () async {
    await registerHakan(auth);
    await auth.logout();
    expect(auth.isLoggedIn, isFalse);

    expect(await auth.login(identifier: 'HAKAN', password: 'gizli1234'), isNull);
    expect(auth.currentUser!.firstName, 'Hakan');
    await auth.logout();
    expect(await auth.login(identifier: 'hakan@mail.com', password: 'gizli1234'), isNull);
  });

  test('hatalı şifre: kalan hak söylenir, 5 denemede hesap kilitlenir', () async {
    await registerHakan(auth);
    await auth.logout();

    final first = await auth.login(identifier: 'hakan', password: 'yanlis');
    expect(first, contains('4 deneme'));
    for (var i = 0; i < 3; i++) {
      await auth.login(identifier: 'hakan', password: 'yanlis');
    }
    final locked = await auth.login(identifier: 'hakan', password: 'yanlis');
    expect(locked, contains('30 sn'));
    // Kilitliyken doğru şifre de kabul edilmez.
    expect(await auth.login(identifier: 'hakan', password: 'gizli1234'), contains('sn sonra'));

    now = now.add(const Duration(seconds: 31));
    expect(await auth.login(identifier: 'hakan', password: 'gizli1234'), isNull);
  });

  test('olmayan kullanıcıda da aynı mesaj (hesap varlığı sızmaz)', () async {
    expect(await auth.login(identifier: 'kimse', password: 'x'), startsWith('Kullanıcı adı/e-posta veya şifre hatalı'));
  });

  test('"beni hatırla" açıkken oturum yeniden açılışta korunur', () async {
    await registerHakan(auth);
    final reopened = newAuth();
    expect(reopened.currentUser?.username, 'Hakan');
    expect(reopened.lastIdentifier, 'Hakan');
  });

  test('"beni hatırla" kapalıyken oturum yeniden açılışta kapanır', () async {
    await registerHakan(auth);
    await auth.logout();
    await auth.login(identifier: 'hakan', password: 'gizli1234', rememberMe: false);
    expect(auth.isLoggedIn, isTrue);
    expect(newAuth().isLoggedIn, isFalse);
  });

  test('güvenlik sorusuyla şifre sıfırlama', () async {
    await registerHakan(auth);
    await auth.logout();
    expect(auth.securityQuestionFor('hakan'), securityQuestions[2]);
    expect(auth.securityQuestionFor('yok'), isNull);

    expect(await auth.resetPassword(identifier: 'hakan', answer: 'ankara', newPassword: 'yeni12345'), contains('yanlış'));
    // Büyük/küçük harf ve boşluk farkı önemsizdir.
    expect(await auth.resetPassword(identifier: 'hakan', answer: 'istanbul', newPassword: 'yeni12345'), isNull);
    expect(await auth.login(identifier: 'hakan', password: 'gizli1234'), isNotNull);
    expect(await auth.login(identifier: 'hakan', password: 'yeni12345'), isNull);
  });

  test('şifre değiştirme mevcut şifreyi ister', () async {
    await registerHakan(auth);
    expect(await auth.changePassword(current: 'yanlis', newPassword: 'yeni12345'), isNotNull);
    expect(await auth.changePassword(current: 'gizli1234', newPassword: 'gizli1234'), isNotNull);
    expect(await auth.changePassword(current: 'gizli1234', newPassword: 'yeni12345'), isNull);
    await auth.logout();
    expect(await auth.login(identifier: 'hakan', password: 'yeni12345'), isNull);
  });

  test('profil güncelleme', () async {
    await registerHakan(auth);
    expect(
      await auth.updateProfile(fullName: 'hakan can yılmaz', email: 'yeni@mail.com', school: 'ODTÜ', department: 'Bilgisayar'),
      isNull,
    );
    expect(auth.currentUser!.fullName, 'Hakan Can Yılmaz');
    expect(auth.currentUser!.initials, 'HY');
    expect(newAuth().currentUser!.school, 'ODTÜ');
  });

  test('her kullanıcı yalnızca kendi verisini görür; hesap silinince verisi de silinir', () async {
    final courses = CourseController(db, auth);
    await registerHakan(auth);
    await courses.create(name: 'Fizik', code: 'FİZ101', instructor: '', credits: 5, colorIndex: 0, assessments: const []);
    expect(courses.courses, hasLength(1));

    await auth.logout();
    expect(courses.courses, isEmpty);
    await auth.register(
      fullName: 'Ayşe Kaya',
      username: 'ayse',
      email: 'ayse@mail.com',
      password: 'gizli1234',
      securityQuestion: securityQuestions.first,
      securityAnswer: 'tekir',
    );
    expect(courses.courses, isEmpty);

    await auth.logout();
    await auth.login(identifier: 'hakan', password: 'gizli1234');
    expect(courses.courses.single.name, 'Fizik');

    expect(await auth.deleteAccount('yanlis'), isNotNull);
    expect(await auth.deleteAccount('gizli1234'), isNull);
    expect(auth.isLoggedIn, isFalse);
    expect(db.courses.all(), isEmpty);
    expect(await auth.login(identifier: 'hakan', password: 'gizli1234'), isNotNull);
    expect(await auth.login(identifier: 'ayse', password: 'gizli1234'), isNull);
    courses.dispose();
  });

  test('demo hesabı bir kez oluşturulur ve örnek veri içerir', () async {
    final courses = CourseController(db, auth);
    final tasks = TaskController(db, auth);
    await auth.loginDemo();
    expect(auth.currentUser!.firstName, 'Hakan');
    expect(courses.courses, isNotEmpty);
    expect(tasks.tasks, isNotEmpty);
    final count = db.courses.all().length;

    await auth.logout();
    await auth.loginDemo();
    expect(db.courses.all().length, count);
    courses.dispose();
    tasks.dispose();
  });
}
