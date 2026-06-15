import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over [SharedPreferences] for simple key/value caching.
class AppCacheService {
  AppCacheService(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppCacheService> init() async =>
      AppCacheService(await SharedPreferences.getInstance());

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);
  Future<void> clear() => _prefs.clear();
}
