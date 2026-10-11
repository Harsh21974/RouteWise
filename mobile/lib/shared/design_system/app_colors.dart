import 'package:flutter/material.dart';

/// Single source of truth for the RouteWise palette.
///
/// Both the dark (default) and light color sets share a brand electric-lime
/// accent on intentionally dark-warm neutrals, tuned for high sunlight
/// legibility and quick glances while driving.
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.error,
  });

  /// Root scaffold background.
  final Color background;

  /// Card / navigation chrome surface.
  final Color surface;

  /// Raised surface (elevated cards, popovers).
  final Color surfaceHigh;

  /// Hairline borders on dark-arm glass surfaces.
  final Color outline;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Brand accent (electric lime).
  final Color accent;

  /// A readable shade of the accent on this theme's background (used for
  /// icon/eyebrow accents rather than filled buttons).
  final Color accentText;

  /// Ink placed on top of the accent (buttons).
  final Color onAccent;

  /// Translucent accent for soft glows / indicators.
  final Color accentSoft;

  final Color success;
  final Color warning;
  final Color error;

  /// Brand electric lime, shared by both themes.
  static const Color brandLime = Color(0xFFC5F517);

  static const AppColors dark = AppColors(
    background: Color(0xFF0B0C10),
    surface: Color(0xFF14161D),
    surfaceHigh: Color(0xFF1C1F29),
    outline: Color(0x1FFFFFFF),
    textPrimary: Color(0xFFF3F5EF),
    textSecondary: Color(0xFFA4AAB5),
    textMuted: Color(0xFF6F7582),
    accent: brandLime,
    accentText: brandLime,
    onAccent: Color(0xFF171A0A),
    accentSoft: Color(0x33C5F517),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFFB020),
    error: Color(0xFFFF5C5C),
  );

  static const AppColors light = AppColors(
    background: Color(0xFFF5F6F1),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFECEEE7),
    outline: Color(0x14161D14),
    textPrimary: Color(0xFF14161B),
    textSecondary: Color(0xFF5B616C),
    textMuted: Color(0xFF8B909B),
    accent: brandLime,
    accentText: Color(0xFF3F5B00),
    onAccent: Color(0xFF171A0A),
    accentSoft: Color(0x33C5F517),
    success: Color(0xFF16A34A),
    warning: Color(0xFFB45309),
    error: Color(0xFFDC2626),
  );
}

/// Convenience accessor for the palette matching the current brightness.
extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
}