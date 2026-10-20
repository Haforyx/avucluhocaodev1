import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// PBKDF2-HMAC-SHA256 ile şifre özeti.
///
/// Şifre hiçbir zaman açık olarak saklanmaz. Her kullanıcı için rastgele bir
/// "tuz" (salt) üretilir ve şifre bu tuzla binlerce kez özetlenir; böylece
/// aynı şifreye sahip iki kullanıcının özeti farklı olur ve kaba kuvvet
/// denemeleri yavaşlar.
class PasswordHasher {
  const PasswordHasher({this.iterations = 10000, this.keyLength = 32, this.runInBackground = true});

  final int iterations;
  final int keyLength;

  /// Özet ayrı bir isolate'te hesaplansın mı? Binlerce tur arayüzü
  /// dondurmasın diye uygulamada açıktır; sahte zamanla çalışan widget
  /// testlerinde kapatılır. (Web'de isolate olmadığı için `compute` aynı
  /// iş parçacığında çalışır.)
  final bool runInBackground;

  static String newSalt([int length = 16]) {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(length, (_) => random.nextInt(256)));
  }

  /// Özeti onaltılık metin olarak döner.
  String hash(String password, String salt, {int? iterations}) => _hex(
        pbkdf2(
          utf8.encode(password),
          utf8.encode(salt),
          iterations ?? this.iterations,
          keyLength,
        ),
      );

  bool verify(String password, String salt, String expectedHash, {int? iterations}) =>
      constantTimeEquals(hash(password, salt, iterations: iterations), expectedHash);

  /// [hash]'in arayüzü bekletmeyen sürümü.
  Future<String> hashAsync(String password, String salt, {int? iterations}) async {
    final rounds = iterations ?? this.iterations;
    if (runInBackground && !kIsWeb) return compute(_hashTask, (password, salt, rounds, keyLength));
    // Aynı iş parçacığında hesaplanacak: yükleniyor göstergesi çizilebilsin diye önce bir kare bekle.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    return hash(password, salt, iterations: rounds);
  }

  Future<bool> verifyAsync(String password, String salt, String expectedHash, {int? iterations}) async =>
      constantTimeEquals(await hashAsync(password, salt, iterations: iterations), expectedHash);

  static String _hashTask((String, String, int, int) args) {
    final (password, salt, rounds, length) = args;
    return _hex(pbkdf2(utf8.encode(password), utf8.encode(salt), rounds, length));
  }

  /// RFC 8018 (PKCS #5) PBKDF2, PRF = HMAC-SHA256.
  static Uint8List pbkdf2(List<int> password, List<int> salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    const blockSize = 32; // SHA-256 çıktısı
    final blocks = (keyLength + blockSize - 1) ~/ blockSize;
    final out = BytesBuilder(copy: false);

    for (var i = 1; i <= blocks; i++) {
      final first = [...salt, (i >> 24) & 0xff, (i >> 16) & 0xff, (i >> 8) & 0xff, i & 0xff];
      var u = hmac.convert(first).bytes;
      final t = Uint8List.fromList(u);
      for (var j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      out.add(t);
    }
    return Uint8List.sublistView(out.toBytes(), 0, keyLength);
  }

  /// Zamanlama saldırılarına karşı sabit sürede karşılaştırma.
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
