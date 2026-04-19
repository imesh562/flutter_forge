import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';

final class StorageGenerator {
  Future<void> run(ProjectConfig config) async {
    final pkg = config.projectName;
    final base = '${config.projectPath}/lib/core/storage';

    await Future.wait([
      _writePreferencesService(base, pkg),
      _writeSecureStorageService(base, pkg),
      _writeHiveService(base, pkg),
    ]);
  }

  Future<void> _writePreferencesService(String base, String pkg) async {
    await FileUtils.writeFile(
      '$base/preferences_service.dart',
      '''
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
final class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  // ── Auth ──────────────────────────────────────────────────────────────────

  String? get authToken => _prefs.getString('auth_token');
  Future<void> setAuthToken(String token) =>
      _prefs.setString('auth_token', token);
  Future<void> clearAuthToken() => _prefs.remove('auth_token');

  // ── FCM push token ────────────────────────────────────────────────────────

  String? get fcmToken => _prefs.getString('fcm_token');
  Future<void> setFcmToken(String token) =>
      _prefs.setString('fcm_token', token);

  // ── Generic typed helpers ─────────────────────────────────────────────────

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
  Future<void> clear() => _prefs.clear();
}
''',
    );
  }

  Future<void> _writeSecureStorageService(String base, String pkg) async {
    await FileUtils.writeFile(
      '$base/secure_storage_service.dart',
      '''
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
final class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
''',
    );
  }

  Future<void> _writeHiveService(String base, String pkg) async {
    await FileUtils.writeFile(
      '$base/hive_service.dart',
      '''
import 'package:hive_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
final class HiveService {
  /// Initialises Hive and opens required boxes.
  /// Call this before [configureInjection] completes.
  static Future<void> init() async {
    await Hive.initFlutter();
    // Register type adapters here as features are added.
  }

  Future<Box<T>> openBox<T>(String name) => Hive.openBox<T>(name);

  Box<T> box<T>(String name) => Hive.box<T>(name);
}
''',
    );
  }
}
