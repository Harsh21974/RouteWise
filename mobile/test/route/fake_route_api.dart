import 'package:latlong2/latlong.dart';
import 'package:routewise_mobile/features/route/data/route_plan.dart';
import 'package:routewise_mobile/features/route/services/driver_location.dart';
import 'package:routewise_mobile/features/route/services/route_api.dart';

/// Scriptable [RouteApi] for controller/screen tests.
class FakeRouteApi implements RouteApi {
  FakeRouteApi({this.result, this.error, this.delay = Duration.zero});

  RoutePlan? result;
  Exception? error;
  Duration delay;

  /// (deliveryIds, start) captured from every call.
  final List<(List<int>, LatLng)> calls = [];

  @override
  Future<RoutePlan> optimize({
    required List<int> deliveryIds,
    required LatLng start,
  }) async {
    calls.add((List.unmodifiable(deliveryIds), start));
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (error != null) throw error!;
    if (result == null) {
      throw RoutePlanException(message: 'no result configured on FakeRouteApi');
    }
    return result!;
  }

  @override
  void dispose() {}
}

/// Deterministic driver location for tests (no geolocator channel).
class FakeLocation implements DriverLocationSource {
  FakeLocation([this.point = const LatLng(12.9716, 77.5946)]);

  final LatLng point;

  @override
  Future<LatLng> current() async => point;
}

/// Builds a small solved plan: [count] stops laid out along a north-going line
/// starting from [start], each 2 km further on.
RoutePlan buildTestPlan({
  int count = 3,
  LatLng start = const LatLng(12.9716, 77.5946),
}) {
  final stops = <OrderedStop>[
    for (var i = 0; i < count; i++)
      OrderedStop(
        deliveryId: i + 1,
        order: i + 1,
        rawAddress: 'Test Stop ${i + 1}, Main Rd',
        latitude: start.latitude + 0.02 * (i + 1), // ~2.2 km per step
        longitude: start.longitude,
        cumulativeMeters: 2220.0 * (i + 1),
        etaSeconds: 300.0 * (i + 1),
        orderId: 'ORD-${i + 1}',
      ),
  ];
  return RoutePlan(
    routeId: 7,
    start: start,
    stops: stops,
    totalDistanceMeters: 2220.0 * count,
    totalDurationSeconds: 300.0 * count,
    geometryPoints: <LatLng>[],
  );
}