import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:routewise_mobile/features/route/services/route_api.dart';
import 'package:routewise_mobile/features/route/state/route_planner.dart';

import 'fake_route_api.dart';

void main() {
  group('RoutePlanner.optimize', () {
    test('no ids → error phase, no API call', () async {
      final api = FakeRouteApi(result: buildTestPlan());
      final planner = RoutePlanner(api: api, location: FakeLocation());

      await planner.optimize(deliveryIds: const []);

      expect(planner.phase, RoutePhase.error);
      expect(planner.errorMessage, contains('Nothing to optimize'));
      expect(planner.hasPlan, isFalse);
      expect(api.calls, isEmpty);
      planner.dispose();
    });

    test('solving phase is observable while the request is in flight', () async {
      final api = FakeRouteApi(
        result: buildTestPlan(),
        delay: const Duration(milliseconds: 50),
      );
      final planner = RoutePlanner(api: api, location: FakeLocation());

      final future = planner.optimize(deliveryIds: const [1, 2]);
      expect(planner.phase, RoutePhase.solving);

      await future;
      expect(planner.phase, RoutePhase.solved);
      planner.dispose();
    });

    test('sends delivery ids and the driver location to the API', () async {
      final api = FakeRouteApi(result: buildTestPlan());
      final planner = RoutePlanner(
        api: api,
        location: FakeLocation(const LatLng(12.5, 77.5)),
      );

      await planner.optimize(deliveryIds: const [3, 1]);

      final call = api.calls.single;
      expect(call.$1, [3, 1]);
      expect(call.$2, const LatLng(12.5, 77.5));
      planner.dispose();
    });

    test('errors surface and clear any previous plan', () async {
      final api = FakeRouteApi(error: RoutePlanException(message: 'boom'));
      final planner = RoutePlanner(api: api, location: FakeLocation());

      await planner.optimize(deliveryIds: const [1]);

      expect(planner.phase, RoutePhase.error);
      expect(planner.errorMessage, 'boom');
      expect(planner.hasPlan, isFalse);
      planner.dispose();
    });
  });

  group('RoutePlanner driving', () {
    late FakeRouteApi api;
    late RoutePlanner planner;

    setUp(() async {
      api = FakeRouteApi(result: buildTestPlan(count: 3));
      planner = RoutePlanner(api: api, location: FakeLocation());
      final future = planner.optimize(deliveryIds: const [1, 2, 3]);
      await expectLater(future, completes);
    });

    tearDown(() => planner.dispose());

    test('initial day stats are empty', () {
      expect(planner.totalCount, 3);
      expect(planner.deliveredCount, 0);
      expect(planner.skippedCount, 0);
      expect(planner.remainingCount, 3);
      expect(planner.coveredMeters, 0);
      expect(planner.progress, 0);
      expect(planner.isAllComplete, isFalse);
    });

    test('markDelivered bumps delivered stats and covered distance', () {
      planner.markDelivered(1);

      expect(planner.deliveredCount, 1);
      expect(planner.remainingCount, 2);
      expect(planner.progress, closeTo(1 / 3, 1e-9));
      // Covered follows the cumulative distance of the furthest completed stop.
      expect(planner.coveredMeters, closeTo(2220.0, 1e-9));
    });

    test('skip tracks separately and pushes covered distance onward', () {
      planner.markDelivered(1);
      planner.skip(2);

      expect(planner.deliveredCount, 1);
      expect(planner.skippedCount, 1);
      expect(planner.remainingCount, 1);
      expect(planner.coveredMeters, closeTo(4440.0, 1e-9));
    });

    test('ignores unknown and already-completed stops', () {
      planner.markDelivered(99);
      planner.markDelivered(1);
      planner.markDelivered(1); // second call is a no-op

      expect(planner.deliveredCount, 1);
      expect(planner.remainingCount, 2);
    });

    test('isAllComplete when every stop is handled', () {
      planner.markDelivered(1);
      planner.skip(2);
      planner.markDelivered(3);

      expect(planner.progress, 1.0);
      expect(planner.isAllComplete, isTrue);
      expect(planner.remainingCount, 0);
      expect(planner.coveredMeters, closeTo(6660.0, 1e-9));
    });

    test('reset returns to idle and drops the day stats', () {
      planner.markDelivered(1);
      planner.reset();

      expect(planner.phase, RoutePhase.idle);
      expect(planner.hasPlan, isFalse);
      expect(planner.totalCount, 0);
      expect(planner.errorMessage, isNull);
    });
  });
}