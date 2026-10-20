import 'dart:convert';

/// Uygulamanın kullandığı en basit depolama arayüzü: anahtar -> metin.
///
/// Gerçek uygulamada [HiveStore] (cihazda kalıcı), testlerde [MemoryStore]
/// kullanılır. Böylece giriş/kayıt akışı dahil her şey cihaz olmadan test
/// edilebilir.
abstract class KeyValueStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Iterable<String> get keys;
}

/// Bellekte tutulan depo (testler ve "beni hatırla" kapalıyken oturum için).
class MemoryStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  String? read(String key) => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Iterable<String> get keys => _data.keys.toList(growable: false);
}

/// Bir depo üzerinde JSON nesnelerinden oluşan koleksiyon.
///
/// Değerler JSON metni olarak saklanır; Hive'ın iç içe Map/List tiplerini
/// dönüştürme derdi olmaz ve kayıt biçimi her platformda aynı kalır.
class JsonCollection {
  JsonCollection(this.store);

  final KeyValueStore store;

  Map<String, dynamic>? get(String id) {
    final raw = store.read(id);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Iterable<Map<String, dynamic>> all() sync* {
    for (final key in store.keys) {
      final value = get(key);
      if (value != null) yield value;
    }
  }

  Future<void> put(String id, Map<String, dynamic> value) => store.write(id, jsonEncode(value));

  Future<void> delete(String id) => store.remove(id);

  bool contains(String id) => store.read(id) != null;

  /// [test] ile eşleşen bütün kayıtları siler, silinen kayıt sayısını döner.
  Future<int> deleteWhere(bool Function(Map<String, dynamic> value) test) async {
    var count = 0;
    for (final key in store.keys) {
      final value = get(key);
      if (value != null && test(value)) {
        await store.remove(key);
        count++;
      }
    }
    return count;
  }
}
