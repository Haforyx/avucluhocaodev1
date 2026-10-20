/// Türkçe büyük/küçük harf dönüşümleri.
///
/// Dart'ın toUpperCase/toLowerCase'i dil bağımsız çalışır: "i" -> "I" olur,
/// Türkçede ise "i" -> "İ", "ı" -> "I" olmalıdır.
String trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

String trLower(String s) => s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

/// "hAKAN" -> "Hakan", "ılgaz" -> "Ilgaz", "irem" -> "İrem".
String trCapitalize(String s) {
  if (s.isEmpty) return s;
  return trUpper(s.substring(0, 1)) + trLower(s.substring(1));
}

/// Her kelimenin ilk harfini büyütür: "hakan yılmaz" -> "Hakan Yılmaz".
String trTitleCase(String s) =>
    s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map(trCapitalize).join(' ');

/// Güvenlik sorusu cevapları büyük/küçük harf ve boşluk farkı gözetmeden
/// karşılaştırılır: "  İstanbul " -> "istanbul".
String normalizeAnswer(String s) => trLower(s.trim()).replaceAll(RegExp(r'\s+'), ' ');

/// Arama için sadeleştirme: küçük harf + Türkçe karakterleri ASCII'ye indirger.
String foldForSearch(String s) {
  const map = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u'};
  final lower = trLower(s);
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(map[ch] ?? ch);
  }
  return buffer.toString();
}
