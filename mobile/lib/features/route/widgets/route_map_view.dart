import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../shared/design_system/app_colors.dart';
import '../data/route_plan.dart';

/// OSM map of the solved route: the driving polyline, numbered stop markers
/// in visiting order and a "you are here" start dot.
///
/// Tapping a stop marker (or the stop list) sets [activeStopId]; the camera
/// then glides to that stop and its pin highlights.
class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.plan,
    required this.stops,
    this.activeStopId,
    this.onStopTap,
  });

  final RoutePlan plan;

  /// Live stops (with delivered/skipped state) for marker styling.
  final List<OrderedStop> stops;
  final int? activeStopId;
  final ValueChanged<int>? onStopTap;

  @override
  State<RouteMapView> createState() => RouteMapViewState();
}

class RouteMapViewState extends State<RouteMapView> {
  final MapController _mapCtrl = MapController();
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    _refitAfterLayout();
  }

  @override
  void didUpdateWidget(covariant RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.plan, widget.plan)) {
      _fitted = false;
      _refitAfterLayout();
    } else if (oldWidget.activeStopId != widget.activeStopId &&
        widget.activeStopId != null) {
      final seen = widget.stops.any((s) => s.deliveryId == widget.activeStopId);
      if (!seen) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final stop = widget.stops.firstWhere(
          (s) => s.deliveryId == widget.activeStopId,
        );
        _mapCtrl.move(stop.latLng, 16);
      });
    }
  }

  void _refitAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _fitted) return;
      _fitted = true;
      final points = [widget.plan.start, ...widget.stops.map((s) => s.latLng)];
      _mapCtrl.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(56),
          maxZoom: 16,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: widget.plan.start,
        initialZoom: 13,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag |
              InteractiveFlag.flingAnimation |
              InteractiveFlag.pinchMove |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.routewise.routewise_mobile',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: widget.plan.polylinePoints,
              color: c.accent.withValues(alpha: 0.85),
              strokeWidth: 5,
              borderColor: Colors.black.withValues(alpha: 0.28),
              borderStrokeWidth: 2,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            _startMarker(c),
            ...widget.stops.map((s) => _stopMarker(s, c)),
          ],
        ),
      ],
    );
  }

  Marker _startMarker(AppColors c) {
    return Marker(
      key: const ValueKey('route-start'),
      point: widget.plan.start,
      width: 26,
      height: 26,
      child: Container(
        decoration: BoxDecoration(
          color: c.accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black87, width: 3),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.45),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  Marker _stopMarker(OrderedStop stop, AppColors c) {
    final active = stop.deliveryId == widget.activeStopId;
    return Marker(
      key: ValueKey('mapStop-${stop.deliveryId}'),
      point: stop.latLng,
      width: 44,
      height: 52,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onStopTap?.call(stop.deliveryId),
        child: _RoutePin(
          number: stop.order,
          active: active,
          done: stop.isDone,
          colors: c,
        ),
      ),
    );
  }
}

/// Numbered map pin; the tail tip sits on the marker point (widget is aligned
/// above the point), the head carries the visiting-order number.
class _RoutePin extends StatelessWidget {
  const _RoutePin({
    required this.number,
    required this.active,
    required this.done,
    required this.colors,
  });

  final int number;
  final bool active;
  final bool done;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final fill = done ? colors.surfaceHigh : colors.accent;
    final numberColor =
        done ? colors.textMuted : (active ? colors.onAccent : colors.onAccent);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        CustomPaint(
          size: const Size(44, 52),
          painter: _PinPainter(
            fill: fill,
            ring: active ? Colors.white : null,
            glow: active ? colors.accent : null,
          ),
        ),
        Positioned(
          top: 24,
          left: 0,
          right: 0,
          child: Text(
            '$number',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: numberColor,
                  fontSize: 15,
                  height: 1.0,
                ),
          ),
        ),
      ],
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter({required this.fill, this.ring, this.glow});

  final Color fill;
  final Color? ring;
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final radius = size.width * 0.28;
    final cy = size.height * 0.62;

    if (glow != null) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius + 9,
        Paint()..color = glow!.withValues(alpha: 0.32),
      );
    }

    final head = Paint()..color = fill;
    canvas.drawCircle(Offset(cx, cy), radius, head);

    final tail = ui.Path()
      ..moveTo(cx - radius * 0.62, cy + radius * 0.6)
      ..lineTo(cx + radius * 0.62, cy + radius * 0.6)
      ..lineTo(cx, size.height)
      ..close();
    canvas.drawPath(tail, head);

    if (ring != null) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius + 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ring!,
      );
    }
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.ring != ring ||
      oldDelegate.glow != glow;
}