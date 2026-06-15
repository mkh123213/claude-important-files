import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_preferences_state.dart';
import 'preferences_repo.dart';

/// Owns theme mode and locale, persisting changes through [PreferencesRepo].
class AppPreferencesCubit extends Cubit<AppPreferencesState> {
  AppPreferencesCubit(this._repo) : super(const AppPreferencesState()) {
    _restore();
  }

  final PreferencesRepo _repo;

  void _restore() {
    final theme = _repo.getThemeMode();
    final locale = _repo.getLocale();
    emit(state.copyWith(
      themeMode: _themeFromString(theme),
      locale: locale != null ? Locale(locale) : null,
    ));
  }

  void toggleTheme() {
    final next =
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(next);
  }

  void setThemeMode(ThemeMode mode) {
    _repo.setThemeMode(mode.name);
    emit(state.copyWith(themeMode: mode));
  }

  void setLocale(Locale locale) {
    _repo.setLocale(locale.languageCode);
    emit(state.copyWith(locale: locale));
  }

  ThemeMode _themeFromString(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
