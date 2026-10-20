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

  /// Kimlik (küçük harf) -> hatalı deneme bilgisi.
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
    if (_findByUsername(name) != null) return 'Bu kullanıcı adı zaten alınmış.';
    if (_findByEmail(mail) != null) return 'Bu e-posta adresiyle zaten bir hesap var.';
    if (securityAnswer.trim().isEmpty) return 'Güvenlik sorusunun cevabını gir.';

    // Yükleniyor göstergesi çizilebilsin diye hesaplamadan önce bir kare bekle.
    await Future<void>.delayed(Duration.zero);
    final salt = PasswordHasher.newSalt();
    final now = _clock();
    final user = AppUser(
      id: newId(),
      fullName: trTitleCase(fullName),
      username: name,
      email: mail,
      passwordHash: hasher.hash(password, salt),
      salt: salt,
      iterations: hasher.iterations,
      securityQuestion: securityQuestion,
      securityAnswerHash: _hashAnswer(securityAnswer),
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
    final lock = _lockMessage(id);
    if (lock != null) return lock;

    await Future<void>.delayed(Duration.zero);
    final user = _findByIdentifier(id);
    if (user == null || !hasher.verify(password, user.salt, user.passwordHash, iterations: user.iterations)) {
      final left = _registerFailure(id);
      // Hangi bilginin yanlış olduğu söylenmez; hesap varlığı dışarı sızmasın.
      if (left <= 0) return _lockMessage(id);
      return 'Kullanıcı adı/e-posta veya şifre hatalı. ($left deneme hakkın kaldı)';
    }
    _attempts.remove(id);
    final updated = user.copyWith(lastLoginAt: _clock());
    await _db.users.put(updated.id, updated.toJson());
    await _startSession(updated, remember: rememberMe, identifier: identifier.trim());
    return null;
  }

  /// Örnek verili demo hesabıyla giriş (ilk seferde hesap ve veriler oluşturulur).
  Future<void> loginDemo() async {
    await Future<void>.delayed(Duration.zero);
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
    if (!_verifyAnswer(answer, user.securityAnswerHash)) return 'Güvenlik sorusunun cevabı yanlış.';
    await _setPassword(user, newPassword);
    _attempts.remove(user.username.toLowerCase());
    _attempts.remove(user.email);
    return null;
  }

  // ------------------------------------------------------------- hesabım

  Future<String?> changePassword({required String current, required String newPassword}) async {
    final user = _user;
    if (user == null) return 'Oturum bulunamadı.';
    if (!hasher.verify(current, user.salt, user.passwordHash, iterations: user.iterations)) {
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
    _user = updated;
    notifyListeners();
    return null;
  }

  /// Hesabı ve bütün verilerini kalıcı olarak siler.
  Future<String?> deleteAccount(String password) async {
    final user = _user;
    if (user == null) return 'Oturum bulunamadı.';
    if (!hasher.verify(password, user.salt, user.passwordHash, iterations: user.iterations)) {
      return 'Şifre hatalı.';
    }
    await _db.deleteUserData(user.id);
    if (_db.meta.read(_lastIdentifierKey)?.toLowerCase() == user.username.toLowerCase()) {
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
      passwordHash: hasher.hash(password, salt),
      iterations: hasher.iterations,
    );
    await _db.users.put(updated.id, updated.toJson());
    if (_user?.id == updated.id) _user = updated;
  }

  String _hashAnswer(String answer) {
    final salt = PasswordHasher.newSalt();
    return '$salt:${hasher.hash(_normalizeAnswer(answer), salt)}';
  }

  bool _verifyAnswer(String answer, String stored) {
    final i = stored.indexOf(':');
    if (i < 0) return false;
    return hasher.verify(_normalizeAnswer(answer), stored.substring(0, i), stored.substring(i + 1));
  }

  /// Cevaplar büyük/küçük harf ve boşluk farkı gözetmeden karşılaştırılır.
  static String _normalizeAnswer(String s) => trLower(s.trim()).replaceAll(RegExp(r'\s+'), ' ');

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
  int _registerFailure(String id) {
    final now = _clock();
    final a = _attempts.putIfAbsent(id, _Attempts.new);
    a.count++;
    if (a.count >= maxFailedAttempts) {
      a.lockedUntil = now.add(lockDuration);
      a.count = 0;
      return 0;
    }
    return maxFailedAttempts - a.count;
  }

  String? _lockMessage(String id) {
    final until = _attempts[id]?.lockedUntil;
    if (until == null) return null;
    final left = until.difference(_clock());
    if (left <= Duration.zero) {
      _attempts[id]!.lockedUntil = null;
      return null;
    }
    final seconds = (left.inMilliseconds / 1000).ceil();
    return 'Çok fazla hatalı deneme yapıldı. $seconds sn sonra tekrar dene.';
  }
}

class _Attempts {
  int count = 0;
  DateTime? lockedUntil;
}
