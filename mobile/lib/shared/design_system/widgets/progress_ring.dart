import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';

/// Animated progress ring (0..1). Used for the "X of Y delivered" readout.
///
/// The arc fills in with a short ease-out and flashes to the success color at
/// 100% so completing a route gets a satisfying micro-moment.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 12,
    this.label,
  });

  /// 0..1 (values outside are clamped).
  final double progress;
  final double size;
  final double strokeWidth;

  /// Optional centered text (e.g. "12"); defaults to a percentage readout.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              colors: colors,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Text(
                label ?? '${(value * 100).round()}%',
                style: AppTextStyles.statValue(colors, fontSize: size * 0.22),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.colors,
    required this.strokeWidth,
  });

  final double progress;
  final AppColors colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = colors.outline;
    canvas.drawCircle(center, radius, track);

    final isComplete = progress >= 0.999;
    final arcColor = isComplete ? colors.success : colors.accent;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.7
      ..color = arcColor.withValues(alpha: 0.18);
    canvas.drawArc(
      rect,
      -_halfPi,
      _tau * progress,
      false,
      glow,
    );

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    canvas.drawArc(rect, -_halfPi, _tau * progress, false, arc);
  }

  static const double _tau = 3.141592653589793 * 2;
  static const double _halfPi = 3.141592653589793 / 2;

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.colors != colors ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}