import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'key_value_store.dart';

/// Hive kutusunu [KeyValueStore] olarak kullanan kalıcı depo.
class HiveStore implements KeyValueStore {
  HiveStore(this._box);

  final Box<String> _box;

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> remove(String key) => _box.delete(key);

  @override
  Iterable<String> get keys => _box.keys.cast<String>().toList(growable: false);
}

/// Uygulamanın bütün koleksiyonları.
class AppDatabase {
  AppDatabase({
    required KeyValueStore users,
    required KeyValueStore courses,
    required KeyValueStore tasks,
    required KeyValueStore sessions,
    required KeyValueStore settings,
    required this.meta,
  })  : users = JsonCollection(users),
        courses = JsonCollection(courses),
        tasks = JsonCollection(tasks),
        sessions = JsonCollection(sessions),
        settings = JsonCollection(settings);

  /// anahtar: kullanıcı id, değer: AppUser
  final JsonCollection users;

  /// anahtar: ders id, değer: Course
  final JsonCollection courses;

  /// anahtar: görev id, değer: StudyTask
  final JsonCollection tasks;

  /// anahtar: çalışma oturumu id, değer: StudySession
  final JsonCollection sessions;

  /// anahtar: kullanıcı id, değer: UserSettings
  final JsonCollection settings;

  /// Oturum gibi tekil değerler ('current_user' -> kullanıcı id).
  final KeyValueStore meta;

  /// Testlerde kullanılan, tamamen bellekte çalışan veritabanı.
  factory AppDatabase.inMemory() => AppDatabase(
        users: MemoryStore(),
        courses: MemoryStore(),
        tasks: MemoryStore(),
        sessions: MemoryStore(),
        settings: MemoryStore(),
        meta: MemoryStore(),
      );

  /// Cihazda kalıcı veritabanını açar (Android/iOS: dosya, web: IndexedDB).
  static Future<AppDatabase> open() async {
    await Hive.initFlutter('avuclu_hoca');
    Future<HiveStore> box(String name) async => HiveStore(await Hive.openBox<String>(name));
    return AppDatabase(
      users: await box('users'),
      courses: await box('courses'),
      tasks: await box('tasks'),
      sessions: await box('sessions'),
      settings: await box('settings'),
      meta: await box('meta'),
    );
  }

  /// Bir kullanıcıya ait bütün verileri siler (hesap silme).
  Future<void> deleteUserData(String userId) async {
    bool owned(Map<String, dynamic> v) => v['ownerId'] == userId;
    await courses.deleteWhere(owned);
    await tasks.deleteWhere(owned);
    await sessions.deleteWhere(owned);
    await settings.delete(userId);
    await users.delete(userId);
  }
}
