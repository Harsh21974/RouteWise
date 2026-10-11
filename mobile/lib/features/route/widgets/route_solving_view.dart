import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_text_styles.dart';

/// On-brand "the solver is working" moment shown while the backend runs the
/// optimization: a radar sweep of expanding rings around a lime route pin.
class RouteSolvingView extends StatefulWidget {
  const RouteSolvingView({super.key, this.stopCount});

  final int? stopCount;

  @override
  State<RouteSolvingView> createState() => _RouteSolvingViewState();
}

class _RouteSolvingViewState extends State<RouteSolvingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ticker,
              builder: (context, _) => CustomPaint(
                size: const Size(220, 220),
                painter: _RadarSweepPainter(c, _ticker.value),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Solving your route',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.stopCount != null
                  ? 'Picking the best order for ${widget.stopCount} stops…'
                  : 'Picking the best order for your stops…',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(c).copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  _RadarSweepPainter(this.colors, this.t);

  final AppColors colors;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;

    // Two staggered, fading ping rings radiating outward.
    for (var i = 0; i < 2; i++) {
      final phase = (t + i / 2) % 1.0;
      final ringRadius = maxRadius * (0.35 + 0.55 * phase);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = colors.accent.withValues(alpha: (1 - phase) * 0.5);
      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // Radar sweep beam.
    final beam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = colors.accent.withValues(alpha: 0.9);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius * 0.62),
      t * 3.14159 * 2,
      0.9,
      false,
      beam,
    );

    // Route pin at the center: dark head + lime core.
    final headRadius = maxRadius * 0.20;
    canvas.drawCircle(center, headRadius + 6, Paint()..color = colors.surfaceHigh);
    canvas.drawCircle(center, headRadius, Paint()..color = colors.accent);
    canvas.drawCircle(
      center,
      headRadius * 0.4,
      Paint()..color = colors.onAccent,
    );
  }

  @override
  bool shouldRepaint(_RadarSweepPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.colors != colors;
}