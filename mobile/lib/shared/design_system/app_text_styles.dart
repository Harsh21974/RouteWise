import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// RouteWise typography.
///
/// Headlines / numbers / labels use Space Grotesk (geo-condensed, bold, very
/// legible on a car mount); body copy uses Inter. Both come from Google Fonts
/// and gracefully fall back to system fonts when offline.
abstract final class AppTextStyles {
  /// Builds the app-wide [TextTheme] for one palette.
  static TextTheme of(AppColors colors) {
    final space = GoogleFonts.spaceGroteskTextTheme();
    final inter = GoogleFonts.interTextTheme();

    final theme = space.copyWith(
      bodyLarge: inter.bodyLarge,
      bodyMedium: inter.bodyMedium,
      bodySmall: inter.bodySmall,
      labelLarge: space.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      labelMedium: space.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );

    return theme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );
  }

  /// Oversized stat numbers (e.g. "12" of a "12 / 60" progress readout).
  static TextStyle statValue(AppColors colors, {double fontSize = 34}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.0,
      color: colors.textPrimary,
    );
  }

  /// Small, spaced section eyebrows.
  static TextStyle sectionLabel(AppColors colors) {
    return GoogleFonts.spaceGrotesk(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: colors.textSecondary,
    );
  }

  /// Tiny captions / hints.
  static TextStyle caption(AppColors colors) {
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: colors.textMuted,
    );
  }
}