import 'package:latlong2/latlong.dart';

/// Lifecycle of a single stop while the driver works the route.
enum StopState { pending, delivered, skipped }

/// One stop of an optimized route, in visiting order.
///
/// [cumulativeMeters] / [etaSeconds] are cumulative from the route start so the
/// driver sees "how far / how long since departing" when reaching this stop.
class OrderedStop {
  const OrderedStop({
    required this.deliveryId,
    required this.order,
    required this.rawAddress,
    required this.latitude,
    required this.longitude,
    required this.cumulativeMeters,
    required this.etaSeconds,
    this.orderId,
    this.requiresPinConfirmation = false,
    this.state = StopState.pending,
  });

  final int deliveryId;
  final int order;
  final String rawAddress;
  final String? orderId;
  final double latitude;
  final double longitude;
  final double cumulativeMeters;
  final double etaSeconds;
  final bool requiresPinConfirmation;
  final StopState state;

  LatLng get latLng => LatLng(latitude, longitude);
  bool get isDone => state != StopState.pending;

  OrderedStop copyWith({StopState? state}) {
    return OrderedStop(
      deliveryId: deliveryId,
      order: order,
      rawAddress: rawAddress,
      latitude: latitude,
      longitude: longitude,
      cumulativeMeters: cumulativeMeters,
      etaSeconds: etaSeconds,
      orderId: orderId,
      requiresPinConfirmation: requiresPinConfirmation,
      state: state ?? this.state,
    );
  }
}

/// A solved route: visiting order, driving geometry and aggregate totals.
class RoutePlan {
  const RoutePlan({
    required this.routeId,
    required this.start,
    required this.stops,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.geometryPoints,
  });

  final int? routeId;

  /// Driver start point the route was planned from.
  final LatLng start;

  /// Deliveries in optimal visiting order with cumulative distance/ETA.
  final List<OrderedStop> stops;

  final double totalDistanceMeters;
  final double totalDurationSeconds;

  /// Decoded driving path (starts at [start]); empty when the backend returned
  /// no geometry (e.g. a single stop).
  final List<LatLng> geometryPoints;

  bool get isEmpty => stops.isEmpty;

  /// Points used to draw the route line: the road geometry when available,
  /// otherwise straight hops from the start through every stop.
  List<LatLng> get polylinePoints =>
      geometryPoints.isNotEmpty ? geometryPoints : [start, ...stops.map((s) => s.latLng)];
}