import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:routewise_mobile/features/intake/data/parcel.dart';
import 'package:routewise_mobile/features/intake/state/intake_controller.dart';
import 'package:routewise_mobile/features/route/screens/route_screen.dart';
import 'package:routewise_mobile/features/route/state/route_planner.dart';
import 'package:routewise_mobile/features/route/widgets/route_map_view.dart';
import 'package:routewise_mobile/shared/design_system/widgets/primary_button.dart';
import 'package:routewise_mobile/shared/design_system/app_theme.dart';

import 'fake_route_api.dart';

/// Fake intake with a fixed parcel list (no HTTP).
class FakeIntakeController extends IntakeController {
  FakeIntakeController(this.parcelList);

  final List<Parcel> parcelList;

  @override
  List<Parcel> get parcels => parcelList;
}

Parcel eligibleParcel(int id) => Parcel(
      id: id,
      orderId: 'ORD-$id',
      rawAddress: 'Parcel $id, Main Rd',
      latitude: 12.98,
      longitude: 77.59,
      geocodeStatus: ParcelGeocodeStatus.autoGeocoded,
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Tall surface so the whole map + stop list fit (lazy-list friendly).
  Future<void> useTallScreen(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1500);
    addTearDown(tester.view.reset);
  }

  Widget harness(RoutePlanner planner, {List<Parcel> parcels = const []}) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: RouteScreen(planner: planner, intake: FakeIntakeController(parcels)),
    );
  }

  RoutePlanner newPlanner({FakeRouteApi? api, int stopCount = 0}) => RoutePlanner(
        api: api ?? FakeRouteApi(result: buildTestPlan(count: stopCount)),
        location: FakeLocation(),
      );

  // The button's outer AnimatedScale transform isn't itself a hit-test target,
  // so taps on the CTA produce a (noise) warning — silenced, the tap works.
  Future<void> tapCta(WidgetTester tester) =>
      tester.tap(find.byType(PrimaryButton), warnIfMissed: false);

  testWidgets('idle shows the CTA with the eligible stop count', (tester) async {
    await useTallScreen(tester);
    final planner = newPlanner();
    await tester.pumpWidget(harness(planner, parcels: [
      eligibleParcel(1),
      eligibleParcel(2),
      Parcel(id: 3, rawAddress: 'ungated', geocodeStatus: ParcelGeocodeStatus.notGeocoded),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Your route is empty'), findsOneWidget);
    expect(find.text('Optimize My Route · 2'), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('idle disables the CTA when nothing is routeable', (tester) async {
    await useTallScreen(tester);
    final planner = newPlanner();
    await tester.pumpWidget(harness(planner));
    await tester.pumpAndSettle();

    expect(find.text('Optimize My Route'), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
  });

  testWidgets('optimizing shows the fun solver then the solved route',
      (tester) async {
    await useTallScreen(tester);
    final api = FakeRouteApi(
      result: buildTestPlan(count: 3),
      delay: const Duration(milliseconds: 300),
    );
    final planner = newPlanner(api: api);
    await tester.pumpWidget(harness(planner, parcels: [eligibleParcel(1)]));

    await tapCta(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Solving your route'), findsOneWidget);
    expect(find.textContaining('best order'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('STOPS'), findsOneWidget);
    expect(find.text('Test Stop 1, Main Rd'), findsOneWidget);
    expect(find.text('Test Stop 3, Main Rd'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Mark Delivered'), findsNWidgets(3));
    expect(find.text('3 left'), findsOneWidget);
    expect(find.byType(RouteMapView), findsOneWidget);
    expect(api.calls.single.$1, [1]);
  });

  testWidgets('tapping a stop card highlights it for the map', (tester) async {
    await useTallScreen(tester);
    final planner = newPlanner(stopCount: 3);
    await tester.pumpWidget(harness(planner, parcels: [
      eligibleParcel(1),
      eligibleParcel(2),
      eligibleParcel(3),
    ]));
    await tapCta(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Stop 2, Main Rd'));
    await tester.pump();

    final map = tester.widget<RouteMapView>(find.byType(RouteMapView));
    expect(map.activeStopId, 2);
  });

  testWidgets('Mark Delivered updates the progress chip and card', (tester) async {
    await useTallScreen(tester);
    final planner = newPlanner(stopCount: 3);
    await tester.pumpWidget(harness(planner, parcels: [
      eligibleParcel(1),
      eligibleParcel(2),
      eligibleParcel(3),
    ]));
    await tapCta(tester);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(PrimaryButton, 'Mark Delivered').first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('2 left'), findsOneWidget);
    expect(find.text('Delivered'), findsWidgets); // status chip on the card
    expect(planner.deliveredCount, 1);
  });

  testWidgets('Skip flags a stop as skipped', (tester) async {
    await useTallScreen(tester);
    final planner = newPlanner(stopCount: 2);
    await tester.pumpWidget(harness(planner, parcels: [
      eligibleParcel(1),
      eligibleParcel(2),
    ]));
    await tapCta(tester);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(PrimaryButton, 'Skip').first,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Skipped'), findsOneWidget);
    expect(planner.skippedCount, 1);
    expect(planner.remainingCount, 1);
  });

  testWidgets('delivering the final stop announces the completed route',
      (tester) async {
    await useTallScreen(tester);
    final planner = newPlanner(stopCount: 1);
    await tester.pumpWidget(harness(planner, parcels: [eligibleParcel(1)]));
    await tapCta(tester);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(PrimaryButton, 'Mark Delivered'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.text('0 left'), findsOneWidget);
    expect(
      find.text('Route complete — all 1 stops done!'),
      findsOneWidget, // snackbar surfaced on the route scaffold
    );
    expect(planner.isAllComplete, isTrue);
    await tester.pumpAndSettle();
  });
}