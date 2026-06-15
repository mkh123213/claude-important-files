import 'package:flutter/material.dart';

/// Central brand palette. Derived from the TaxiDZ design (green primary,
/// taxi-gold accent, navy surfaces).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF16A34A);
  static const Color primaryDark = Color(0xFF15803D);
  static const Color accent = Color(0xFFF5B820);
  static const Color danger = Color(0xFFE53935);
  static const Color success = Color(0xFF22C55E);

  // Light surfaces
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightMutedBg = Color(0xFFF1F5F9);
  static const Color lightForeground = Color(0xFF0F172A);
  static const Color lightMutedFg = Color(0xFF64748B);

  // Dark surfaces
  static const Color darkBg = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF24243B);
  static const Color darkMutedBg = Color(0xFF2D2D4A);
  static const Color darkForeground = Color(0xFFF8FAFC);
  static const Color darkMutedFg = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE2E8F0);
}
