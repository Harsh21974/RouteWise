import 'package:flutter/material.dart';

import '../app_colors.dart';

enum StatusTone { neutral, accent, success, warning, error }

/// Compact pill for a status (delivered / skipped / auto / confirmed).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = _foreground(colors);
    final background = _background(colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }

  Color _foreground(AppColors colors) {
    switch (tone) {
      case StatusTone.neutral:
        return colors.textSecondary;
      case StatusTone.accent:
        return colors.accent;
      case StatusTone.success:
        return colors.success;
      case StatusTone.warning:
        return colors.warning;
      case StatusTone.error:
        return colors.error;
    }
  }

  Color _background(AppColors colors) {
    final tint = _foreground(colors);
    return tint.withValues(alpha: 0.14);
  }
}