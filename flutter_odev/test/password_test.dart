import 'dart:convert';

import 'package:avuclu_hoca/services/password_hasher.dart';
import 'package:avuclu_hoca/services/password_strength.dart';
import 'package:avuclu_hoca/services/validators.dart';
import 'package:flutter_test/flutter_test.dart';

String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // RFC 7914 §11 test vektörü.
    test('RFC 7914: passwd / salt, 1 tur, 64 bayt', () {
      final key = PasswordHasher.pbkdf2(utf8.encode('passwd'), utf8.encode('salt'), 1, 64);
      expect(
        hex(key),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });

    test('password / salt, 4096 tur, 32 bayt', () {
      final key = PasswordHasher.pbkdf2(utf8.encode('password'), utf8.encode('salt'), 4096, 32);
      expect(hex(key), 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });

    test('aynı şifre farklı tuzla farklı özet verir, doğrulama çalışır', () {
      const hasher = PasswordHasher(iterations: 100);
      final salt1 = PasswordHasher.newSalt();
      final salt2 = PasswordHasher.newSalt();
      expect(salt1, isNot(salt2));
      final h1 = hasher.hash('gizli123', salt1);
      final h2 = hasher.hash('gizli123', salt2);
      expect(h1, isNot(h2));
      expect(h1, hasLength(64));
      expect(hasher.verify('gizli123', salt1, h1), isTrue);
      expect(hasher.verify('Gizli123', salt1, h1), isFalse);
    });

    test('sabit süreli karşılaştırma', () {
      expect(PasswordHasher.constantTimeEquals('abc', 'abc'), isTrue);
      expect(PasswordHasher.constantTimeEquals('abc', 'abd'), isFalse);
      expect(PasswordHasher.constantTimeEquals('abc', 'abcd'), isFalse);
    });
  });

  group('Şifre gücü', () {
    test('boş, zayıf, orta, iyi, güçlü', () {
      expect(PasswordStrength.of(''), PasswordStrength.empty);
      expect(PasswordStrength.of('abc'), PasswordStrength.weak);
      expect(PasswordStrength.of('12345678'), PasswordStrength.weak);
      expect(PasswordStrength.of('aaaaaaaaaaaa'), PasswordStrength.weak);
      expect(PasswordStrength.of('kitapokul1'), PasswordStrength.fair);
      expect(PasswordStrength.of('KitapOkul12'), PasswordStrength.good);
      expect(PasswordStrength.of('Kitap.Okul.2024'), PasswordStrength.strong);
    });
  });

  group('Form doğrulama', () {
    test('ad soyad', () {
      expect(Validators.fullName(''), isNotNull);
      expect(Validators.fullName('H'), isNotNull);
      expect(Validators.fullName('Hakan 2'), isNotNull);
      expect(Validators.fullName('Hakan Yılmaz'), isNull);
    });

    test('kullanıcı adı', () {
      expect(Validators.username('ha'), isNotNull);
      expect(Validators.username('hakan yılmaz'), isNotNull);
      expect(Validators.username('hakanş'), isNotNull);
      expect(Validators.username('a' * 21), isNotNull);
      expect(Validators.username('hakan_01'), isNull);
      expect(Validators.username('hakan.y'), isNull);
    });

    test('e-posta', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('hakan@'), isNotNull);
      expect(Validators.email('hakan@mail'), isNotNull);
      expect(Validators.email('hakan @mail.com'), isNotNull);
      expect(Validators.email('hakan@mail.com'), isNull);
      expect(Validators.email('  hakan.y@ogr.edu.tr '), isNull);
    });

    test('şifre ve tekrarı', () {
      expect(Validators.password('kisa1'), isNotNull);
      expect(Validators.password('sadeceharf'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('şifre1234'), isNull);
      final confirm = Validators.confirmPassword(() => 'abc12345');
      expect(confirm('abc1234'), isNotNull);
      expect(confirm('abc12345'), isNull);
    });

    test('not ve ağırlık', () {
      expect(Validators.optionalScore(''), isNull);
      expect(Validators.optionalScore('85,5'), isNull);
      expect(Validators.optionalScore('101'), isNotNull);
      expect(Validators.optionalScore('-1'), isNotNull);
      expect(Validators.optionalScore('abc'), isNotNull);
      expect(Validators.weight('0'), isNotNull);
      expect(Validators.weight('40'), isNull);
    });
  });
}
