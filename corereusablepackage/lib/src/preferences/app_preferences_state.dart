import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AppPreferencesState extends Equatable {
  const AppPreferencesState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('ar'),
  });

  final ThemeMode themeMode;
  final Locale locale;

  AppPreferencesState copyWith({ThemeMode? themeMode, Locale? locale}) {
    return AppPreferencesState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
    );
  }

  @override
  List<Object?> get props => [themeMode, locale];
}
