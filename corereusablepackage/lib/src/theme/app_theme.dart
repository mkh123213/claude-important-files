import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the app's light/dark [ThemeData]. Primary color and font family are
/// configurable so each app can brand the shared theme.
class AppTheme {
  AppTheme._();

  static ThemeData light({
    Color primary = AppColors.primary,
    String? fontFamily,
  }) =>
      _build(Brightness.light, primary, fontFamily);

  static ThemeData dark({
    Color primary = AppColors.primary,
    String? fontFamily,
  }) =>
      _build(Brightness.dark, primary, fontFamily);

  static ThemeData _build(
    Brightness brightness,
    Color primary,
    String? fontFamily,
  ) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      secondary: AppColors.accent,
      error: AppColors.danger,
    );

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final fg = isDark ? AppColors.darkForeground : AppColors.lightForeground;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: fontFamily,
      cardColor: card,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkMutedBg : AppColors.lightMutedBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }
}
