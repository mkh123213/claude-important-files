import '../services/app_cache_service.dart';

/// Persists app-wide preferences (theme mode, locale) via [AppCacheService].
class PreferencesRepo {
  PreferencesRepo(this._cache);

  final AppCacheService _cache;

  static const _kThemeMode = 'pref_theme_mode';
  static const _kLocale = 'pref_locale';

  String? getThemeMode() => _cache.getString(_kThemeMode);
  Future<void> setThemeMode(String value) => _cache.setString(_kThemeMode, value);

  String? getLocale() => _cache.getString(_kLocale);
  Future<void> setLocale(String value) => _cache.setString(_kLocale, value);
}
