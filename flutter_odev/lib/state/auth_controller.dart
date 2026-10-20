import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/demo_seed.dart';
import '../models/app_user.dart';
import '../services/password_hasher.dart';
import '../utils/ids.dart';
import '../utils/text_utils.dart';

/// Kayıtta seçilebilecek güvenlik soruları (şifre sıfırlamada sorulur).
const securityQuestions = [
  'İlk evcil hayvanının adı neydi?',
  'İlkokul öğretmeninin soyadı neydi?',
  'Doğduğun şehir neresi?',
  'En sevdiğin kitap hangisi?',
  'Çocukluk lakabın neydi?',
];

/// Kayıt, giriş, oturum ve hesap işlemleri.
///
/// İşlemler başarılıysa null, değilse kullanıcıya gösterilecek hata mesajını
/// döner. Veriler yalnızca cihazda saklanır.
class AuthController extends ChangeNotifier {
  AuthController(
    this._db, {
    this.hasher = const PasswordHasher(),
    DateTime Function()? clock,
    this.maxFailedAttempts = 5,
    this.lockDuration = const Duration(seconds: 30),
    this.resetLockDuration = const Duration(minutes: 5),
  }) : _clock = clock ?? DateTime.now {
    final current = _db.meta.read(_currentKey);
    final stored = current == null ? null : _db.users.get(current);
    if (stored != null) _user = AppUser.fromJson(stored);
  }

  static const _currentKey = 'current_user';
  static const _lastIdentifierKey = 'last_identifier';

  final AppDatabase _db;
  final PasswordHasher hasher;
  final DateTime Function() _clock;
  final int maxFailedAttempts;
  final Duration lockDuration;

  /// Güvenlik sorusu art arda yanlış cevaplanınca sıfırlamanın kilitli kalacağı süre.
  final Duration resetLockDuration;

  /// `login:<kullanıcı>` / `reset:<kullanıcı>` -> hatalı deneme bilgisi.
  final Map<String, _Attempts> _attempts = {};

  AppUser? _user;

  AppUser? get currentUser => _user;
  bool get isLoggedIn => _user != null;

  /// "Beni hatırla" ile son giriş yapılan kullanıcı adı (giriş formunu doldurmak için).
  String? get lastIdentifier => _db.meta.read(_lastIdentifierKey);

  // ---------------------------------------------------------------- kayıt

  Future<String?> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String securityQuestion,
    required String securityAnswer,
    String school = '',
    String department = '',
  }) async {
    final name = username.trim();
    final mail = email.trim().toLowerCase();
    if (name.toLowerCase() == DemoSeeder.username) return 'Bu kullanıcı adı demo hesabına ayrılmış.';
    if (_findByUsername(name) != null) return 'Bu kullanıcı adı zaten alınmış.';
    if (_findByEmail(mail) != null) return 'Bu e-posta adresiyle zaten bir hesap var.';
    if (securityAnswer.trim().isEmpty) return 'Güvenlik sorusunun cevabını gir.';

    final salt = PasswordHasher.newSalt();
    final passwordHash = await hasher.hashAsync(password, salt);
    final answerHash = await _hashAnswer(securityAnswer);
    // Hesaplama sürerken aynı ad/e-postayla başka bir kayıt yapılmış olabilir.
    if (_findByUsername(name) != null || _findByEmail(mail) != null) return 'Bu hesap zaten oluşturulmuş.';
    final now = _clock();
    final user = AppUser(
      id: newId(),
      fullName: trTitleCase(fullName),
      username: name,
      email: mail,
      passwordHash: passwordHash,
      salt: salt,
      iterations: hasher.iterations,
      securityQuestion: securityQuestion,
      securityAnswerHash: answerHash,
      createdAt: now,
      lastLoginAt: now,
      school: school.trim(),
      department: department.trim(),
    );
    await _db.users.put(user.id, user.toJson());
    await _startSession(user, remember: true, identifier: user.username);
    return null;
  }

  // ---------------------------------------------------------------- giriş

  Future<String?> login({
    required String identifier,
    required String password,
    bool rememberMe = true,
  }) async {
    final id = identifier.trim().toLowerCase();
    final user = _findByIdentifier(id);
    // Kullanıcı adı ve e-postayla yapılan denemeler aynı sayaca yazılır.
    final key = 'login:${user?.id ?? id}';
    final lock = _lockMessage(key);
    if (lock != null) return lock;

    final ok = user != null &&
        await hasher.verifyAsync(password, user.salt, user.passwordHash, iterations: user.iterations);
    if (!ok) {
      final left = _registerFailure(key, lockDuration);
      // Hangi bilginin yanlış olduğu söylenmez; hesap varlığı dışarı sızmasın.
      if (left <= 0) return _lockMessage(key);
      return 'Kullanıcı adı/e-posta veya şifre hatalı. ($left deneme hakkın kaldı)';
    }
    _attempts.remove(key);
    final updated = user.copyWith(lastLoginAt: _clock());
    await _db.users.put(updated.id, updated.toJson());
    await _startSession(updated, remember: rememberMe, identifier: identifier.trim());
    return null;
  }

  /// Örnek verili demo hesabıyla giriş (ilk seferde hesap ve veriler oluşturulur).
  Future<void> loginDemo() async {
    final user = await DemoSeeder(_db, hasher, _clock).ensureDemoUser();
    await _startSession(user, remember: true, identifier: user.username);
  }

  Future<void> logout() async {
    await _db.meta.remove(_currentKey);
    _user = null;
    notifyListeners();
  }

  // ------------------------------------------------------- şifre sıfırlama

  /// Kimliğe ait güvenlik sorusu; kullanıcı yoksa null.
  String? securityQuestionFor(String identifier) =>
      _findByIdentifier(identifier.trim().toLowerCase())?.securityQuestion;

  Future<String?> resetPassword({
    required String identifier,
    required String answer,
    required String newPassword,
  }) async {
    final user = _findByIdentifier(identifier.trim().toLowerCase());
    if (user == null) return 'Bu bilgilerle kayıtlı bir hesap bulunamadı.';
    // Cevap tahminle bulunamasın diye sıfırlama denemeleri de sınırlıdır.
    final key = 'reset:${user.id}';
    final lock = _lockMessage(key);
    if (lock != null) return lock;
    if (!await _verifyAnswer(answer, user.securityAnswerHash)) {
      final left = _registerFailure(key, resetLockDuration);
      if (left <= 0) return _lockMessage(key);
      return 'Güvenlik sorusunun cevabı yanlış. ($left deneme hakkın kaldı)';
    }
    await _setPassword(user, newPassword);
    _attempts.remove(key);
    _attempts.remove('login:${user.id}');
    return null;
  }

  // ------------------------------------------------------------- hesabım

  Future<String?> changePassword({required String current, required String newPassword}) async {
    final user = _user;
    if (user == null) return 'Oturum bulunamadı.';
    if (!await hasher.verifyAsync(current, user.salt, user.passwordHash, iterations: user.iterations)) {
      return 'Mevcut şifren hatalı.';
    }
    if (current == newPassword) return 'Yeni şifre eskisiyle aynı olamaz.';
    await _setPassword(user, newPassword);
    return null;
  }

  Future<String?> updateProfile({
    required String fullName,
    required String email,
    required String school,
    required String department,
  }) async {
    final user = _user;
    if (user == null) return 'Oturum bulunamadı.';
    final mail = email.trim().toLowerCase();
    final other = _findByEmail(mail);
    if (other != null && other.id != user.id) return 'Bu e-posta başka bir hesapta kullanılıyor.';
    final updated = user.copyWith(
      fullName: trTitleCase(fullName),
      email: mail,
      school: school.trim(),
      department: department.trim(),
    );
    await _db.users.put(updated.id, updated.toJson());
    // Giriş formunda eski e-posta önerilmesin.
    if (lastIdentifier?.trim().toLowerCase() == user.email && mail != user.email) {
      await _db.meta.write(_lastIdentifierKey, mail);
    }
    _user = updated;
    notifyListeners();
    return null;
  }

  /// Hesabı ve bütün verilerini kalıcı olarak siler.
  Future<String?> deleteAccount(String password) async {
    final user = _user;
    if (user == null) return 'Oturum bulunamadı.';
    if (!await hasher.verifyAsync(password, user.salt, user.passwordHash, iterations: user.iterations)) {
      return 'Şifre hatalı.';
    }
    await _db.deleteUserData(user.id);
    final remembered = lastIdentifier?.trim().toLowerCase();
    if (remembered == user.username.toLowerCase() || remembered == user.email) {
      await _db.meta.remove(_lastIdentifierKey);
    }
    await logout();
    return null;
  }

  // ------------------------------------------------------------- yardımcı

  Future<void> _startSession(AppUser user, {required bool remember, required String identifier}) async {
    if (remember) {
      await _db.meta.write(_currentKey, user.id);
      await _db.meta.write(_lastIdentifierKey, identifier);
    } else {
      // Yalnızca bu açılışta geçerli oturum; uygulama kapanınca çıkış yapılmış olur.
      await _db.meta.remove(_currentKey);
      await _db.meta.remove(_lastIdentifierKey);
    }
    _user = user;
    notifyListeners();
  }

  Future<void> _setPassword(AppUser user, String password) async {
    final salt = PasswordHasher.newSalt();
    final updated = user.copyWith(
      salt: salt,
      passwordHash: await hasher.hashAsync(password, salt),
      iterations: hasher.iterations,
    );
    await _db.users.put(updated.id, updated.toJson());
    if (_user?.id == updated.id) _user = updated;
  }

  Future<String> _hashAnswer(String answer) async {
    final salt = PasswordHasher.newSalt();
    return '$salt:${await hasher.hashAsync(normalizeAnswer(answer), salt)}';
  }

  Future<bool> _verifyAnswer(String answer, String stored) async {
    final i = stored.indexOf(':');
    if (i < 0) return false;
    return hasher.verifyAsync(normalizeAnswer(answer), stored.substring(0, i), stored.substring(i + 1));
  }


  Iterable<AppUser> get _users => _db.users.all().map(AppUser.fromJson);

  AppUser? _findByUsername(String username) {
    final key = username.toLowerCase();
    for (final u in _users) {
      if (u.username.toLowerCase() == key) return u;
    }
    return null;
  }

  AppUser? _findByEmail(String email) {
    for (final u in _users) {
      if (u.email == email) return u;
    }
    return null;
  }

  AppUser? _findByIdentifier(String id) =>
      id.contains('@') ? _findByEmail(id) : _findByUsername(id);

  /// Kalan deneme hakkını döner.
  int _registerFailure(String key, Duration lockFor) {
    final now = _clock();
    final a = _attempts.putIfAbsent(key, _Attempts.new);
    a.count++;
    if (a.count >= maxFailedAttempts) {
      a.lockedUntil = now.add(lockFor);
      a.count = 0;
      return 0;
    }
    return maxFailedAttempts - a.count;
  }

  String? _lockMessage(String key) {
    final until = _attempts[key]?.lockedUntil;
    if (until == null) return null;
    final left = until.difference(_clock());
    if (left <= Duration.zero) {
      _attempts[key]!.lockedUntil = null;
      return null;
    }
    final seconds = (left.inMilliseconds / 1000).ceil();
    final wait = seconds < 60 ? '$seconds sn' : '${(seconds / 60).ceil()} dk';
    return 'Çok fazla hatalı deneme yapıldı. $wait sonra tekrar dene.';
  }
}

class _Attempts {
  int count = 0;
  DateTime? lockedUntil;
}
