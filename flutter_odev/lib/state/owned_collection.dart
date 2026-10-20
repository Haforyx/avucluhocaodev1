import 'package:flutter/foundation.dart';

import '../data/key_value_store.dart';
import 'auth_controller.dart';

/// Giriş yapmış kullanıcıya ait kayıtları tutan ortak denetleyici.
///
/// Oturum değişince (giriş/çıkış) kendiliğinden yeni kullanıcının
/// kayıtlarını yükler; ekranlar yalnızca [items] listesini dinler.
abstract class OwnedCollection<T> extends ChangeNotifier {
  OwnedCollection(this.collection, this.auth) {
    auth.addListener(_onAuthChanged);
    _load();
  }

  final JsonCollection collection;
  final AuthController auth;

  String? _ownerId;
  List<T> _items = const [];

  String? get ownerId => _ownerId;
  List<T> get items => _items;

  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(T item);
  String idOf(T item);

  /// Listenin varsayılan sırası.
  int compare(T a, T b) => 0;

  T? byId(String? id) {
    if (id == null) return null;
    for (final item in _items) {
      if (idOf(item) == id) return item;
    }
    return null;
  }

  Future<void> save(T item) async {
    await collection.put(idOf(item), toJson(item));
    final id = idOf(item);
    final index = _items.indexWhere((e) => idOf(e) == id);
    final next = [..._items];
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    _items = next..sort(compare);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await collection.delete(id);
    _items = _items.where((e) => idOf(e) != id).toList();
    notifyListeners();
  }

  void _onAuthChanged() {
    if (auth.currentUser?.id == _ownerId) return;
    _load();
    notifyListeners();
  }

  void _load() {
    _ownerId = auth.currentUser?.id;
    final owner = _ownerId;
    _items = owner == null
        ? const []
        : (collection.all().where((j) => j['ownerId'] == owner).map(fromJson).toList()..sort(compare));
  }

  @override
  void dispose() {
    auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
