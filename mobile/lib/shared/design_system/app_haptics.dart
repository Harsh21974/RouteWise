import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback] so feature code can express intent
/// ("light tap", "task completed") without knowing the platform constants.
abstract final class Haptics {
  /// Subtle tick, e.g. when a button is pressed.
  static void light() => HapticFeedback.lightImpact();

  /// Neutral select tick.
  static void selection() => HapticFeedback.selectionClick();

  /// Punchy confirm, e.g. when a drop is marked delivered.
  static void success() => HapticFeedback.heavyImpact();
}