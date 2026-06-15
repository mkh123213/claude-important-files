import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Convenience accessors for theme-aware colors and sizing.
extension BuildContextExt on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cardBg => isDark ? AppColors.darkCard : AppColors.lightCard;
  Color get mutedBg => isDark ? AppColors.darkMutedBg : AppColors.lightMutedBg;
  Color get foreground =>
      isDark ? AppColors.darkForeground : AppColors.lightForeground;
  Color get mutedFg => isDark ? AppColors.darkMutedFg : AppColors.lightMutedFg;

  Size get screenSize => MediaQuery.sizeOf(this);
  double get width => MediaQuery.sizeOf(this).width;
  double get height => MediaQuery.sizeOf(this).height;
}
