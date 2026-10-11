import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:routewise_mobile/features/delivery/delivery_screen.dart';
import 'package:routewise_mobile/features/route/state/route_planner.dart';
import 'package:routewise_mobile/shared/design_system/app_theme.dart';

import '../route/fake_route_api.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> useTallScreen(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1500);
    addTearDown(tester.view.reset);
  }

  Widget harness(RoutePlanner planner) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: DeliveryScreen(planner: planner),
    );
  }

  testWidgets('empty dashboard shows zeroed day stats', (tester) async {
    await useTallScreen(tester);
    final planner = RoutePlanner(api: FakeRouteApi(), location: FakeLocation());
    await tester.pumpWidget(harness(planner));
    await tester.pumpAndSettle();

    expect(find.text('DAY PROGRESS'), findsOneWidget);
    expect(find.text('DELIVERED'), findsOneWidget);
    expect(find.text('REMAINING'), findsOneWidget);
    expect(find.text('COVERED'), findsOneWidget);
    expect(find.text('0 of 0 delivered'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_rounded), findsNothing);
  });

  testWidgets('day stats track the shared planner', (tester) async {
    await useTallScreen(tester);
    final planner = RoutePlanner(
      api: FakeRouteApi(result: buildTestPlan(count: 3)),
      location: FakeLocation(),
    );
    await planner.optimize(deliveryIds: const [1, 2, 3]);

    await tester.pumpWidget(harness(planner));
    await tester.pumpAndSettle();

    expect(find.text('0 of 3 delivered'), findsOneWidget);

    planner.markDelivered(1);
    await tester.pump();
    expect(find.text('1 of 3 delivered'), findsOneWidget);
    expect(find.text('2 left'), findsNothing); // Progress tab has no "left" chip

    planner.markDelivered(2);
    planner.markDelivered(3);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('3 of 3 delivered'), findsOneWidget);
    expect(find.text('COVERED'), findsOneWidget);
    expect(find.text('6.7 km'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
  });
}