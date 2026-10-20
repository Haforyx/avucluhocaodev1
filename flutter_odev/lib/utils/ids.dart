import 'dart:math';

final _random = Random.secure();

/// Kısa, çakışma olasılığı çok düşük kimlik: zaman damgası + rastgele ek.
String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = List.generate(6, (_) => _random.nextInt(36).toRadixString(36)).join();
  return '$time$rand';
}
