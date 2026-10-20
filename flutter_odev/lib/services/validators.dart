/// Form alanlarının doğrulama kuralları. Hata varsa mesaj, yoksa null döner.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _username = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Adını ve soyadını gir.';
    if (v.length < 2) return 'Ad en az 2 karakter olmalı.';
    if (RegExp(r'[0-9]').hasMatch(v)) return 'Ad rakam içeremez.';
    return null;
  }

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Bir kullanıcı adı seç.';
    if (v.length < 3) return 'Kullanıcı adı en az 3 karakter olmalı.';
    if (v.length > 20) return 'Kullanıcı adı en fazla 20 karakter olabilir.';
    if (!_username.hasMatch(v)) {
      return 'Yalnızca İngilizce harf, rakam, nokta ve alt çizgi kullan.';
    }
    if (v.contains('@')) return 'Kullanıcı adı @ içeremez.';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'E-posta adresini gir.';
    if (!_email.hasMatch(v)) return 'Geçerli bir e-posta adresi gir.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Bir şifre belirle.';
    if (v.length < 8) return 'Şifre en az 8 karakter olmalı.';
    if (!RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(v) || !RegExp(r'[0-9]').hasMatch(v)) {
      return 'Şifre en az bir harf ve bir rakam içermeli.';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) =>
      (value) => value != original() ? 'Şifreler eşleşmiyor.' : null;

  static String? required(String? value, [String message = 'Bu alan zorunlu.']) =>
      (value == null || value.trim().isEmpty) ? message : null;

  /// 0-100 arası not; boş bırakılabilir.
  static String? optionalScore(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null) return 'Sayı gir.';
    if (n < 0 || n > 100) return '0-100 arası olmalı.';
    return null;
  }

  static String? weight(String? value) {
    final v = value?.trim() ?? '';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null) return 'Sayı gir.';
    if (n <= 0 || n > 100) return '1-100 arası olmalı.';
    return null;
  }
}
