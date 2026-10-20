import 'package:flutter/material.dart';

enum PasswordStrength {
  empty('', 0, Colors.transparent),
  weak('Zayıf', 1, Color(0xFFEF4444)),
  fair('Orta', 2, Color(0xFFF59E0B)),
  good('İyi', 3, Color(0xFF0EA5E9)),
  strong('Güçlü', 4, Color(0xFF10B981));

  const PasswordStrength(this.label, this.level, this.color);

  final String label;

  /// 0-4 arası; güç çubuğunda dolu parça sayısı.
  final int level;
  final Color color;

  /// Uzunluk ve karakter çeşitliliğine göre basit bir puanlama.
  static PasswordStrength of(String password) {
    if (password.isEmpty) return empty;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[a-zçğıöşü]').hasMatch(password) && RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9ÇĞİÖŞÜçğıöşü]').hasMatch(password)) score++;
    // Tek karakterin tekrarı ("aaaaaaaa") ya da çok kısa şifre her zaman zayıftır.
    if (password.length < 8 || RegExp(r'^(.)\1*$').hasMatch(password)) return weak;
    if (_common.contains(password.toLowerCase())) return weak;
    return switch (score) {
      <= 1 => weak,
      2 => fair,
      3 => good,
      _ => strong,
    };
  }

  static const _common = {
    '12345678',
    '123456789',
    '1234567890',
    'password',
    'password1',
    'qwerty123',
    'sifre123',
    'şifre123',
    'abc12345',
    '11111111',
  };
}
