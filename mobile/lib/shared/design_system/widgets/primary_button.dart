import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_haptics.dart';

enum PrimaryButtonVariant { filled, outlined, ghost }

/// Large, thumb-friendly call-to-action button.
///
/// Generous 60px height and a subtle press-scale + haptic tick make it usable
/// one-handed outdoors. A null [onPressed] renders a disabled state.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.width = double.infinity,
    this.height = 60,
    this.variant = PrimaryButtonVariant.filled,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double width;
  final double height;
  final PrimaryButtonVariant variant;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = widget.onPressed != null;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTapDown: enabled
              ? (_) {
                  setState(() => _pressed = true);
                  Haptics.light();
                }
              : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled
              ? () {
                  setState(() => _pressed = false);
                  widget.onPressed!();
                }
              : null,
          child: Container(
            width: widget.width,
            height: widget.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: _decoration(colors, enabled),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 22,
                    color: enabled
                        ? (widget.variant == PrimaryButtonVariant.filled
                            ? colors.onAccent
                            : colors.accent)
                        : colors.textMuted,
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: enabled
                              ? (widget.variant == PrimaryButtonVariant.filled
                                  ? colors.onAccent
                                  : colors.accent)
                              : colors.textMuted,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration(AppColors colors, bool enabled) {
    final base = BorderRadius.circular(22);
    switch (widget.variant) {
      case PrimaryButtonVariant.filled:
        return BoxDecoration(
          color: enabled ? colors.accent : colors.surfaceHigh,
          borderRadius: base,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        );
      case PrimaryButtonVariant.outlined:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: base,
          border: Border.all(
            color: enabled ? colors.accent.withValues(alpha: 0.9) : colors.outline,
            width: 2,
          ),
        );
      case PrimaryButtonVariant.ghost:
        return BoxDecoration(
          color: enabled ? colors.accentSoft : Colors.transparent,
          borderRadius: base,
        );
    }
  }
}