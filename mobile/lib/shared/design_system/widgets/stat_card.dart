import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';

/// Soft glass card for a headline number (e.g. "12" delivered).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceHigh.withValues(alpha: 0.92),
            colors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.30 : 0.08,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.sectionLabel(colors).copyWith(fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(value, style: AppTextStyles.statValue(colors)),
                if (caption != null) ...[
                  const SizedBox(height: 4),
                  Text(caption!, style: AppTextStyles.caption(colors)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}