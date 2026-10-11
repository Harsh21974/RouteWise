import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:routewise_mobile/features/intake/data/parsed_address.dart';
import 'package:routewise_mobile/features/intake/intake_screen.dart';
import 'package:routewise_mobile/features/intake/state/intake_controller.dart';

import 'fake_parcel_api.dart';

void main() {
  Widget buildApp(IntakeController ctrl) =>
      MaterialApp(home: IntakeScreen(controller: ctrl));

  testWidgets('manual entry adds a parcel, bumps the count chip and shows the '
      'amber badge', (tester) async {
    final ctrl = IntakeController(FakeParcelApi());
    await tester.pumpWidget(buildApp(ctrl));
    await tester.pumpAndSettle();

    expect(find.text('Add a parcel'), findsOneWidget);
    expect(find.text('0 added'), findsOneWidget);

    await tester.tap(find.text('Type address manually'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '12 MG Road');
    await tester.enterText(find.byType(TextFormField).at(3), 'Bengaluru');
    await tester.enterText(find.byType(TextFormField).at(4), '560001');

    await tester.tap(find.text('Save parcel'));
    await tester.pumpAndSettle();

    expect(find.text('1 added'), findsOneWidget);
    expect(find.text('Parcel added \u2014 1 total'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);

    // Let the auto-dismissing snackbar timer fire and its exit animation run.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    ctrl.dispose();
  });

  testWidgets('tapping the amber badge opens the map; confirming the pin '
      'flags the parcel as confirmed', (tester) async {
    final api = FakeParcelApi();
    final ctrl = IntakeController(api);
    await ctrl.manualSave(const ManualAddress(street: '12 MG Road'));

    await tester.pumpWidget(buildApp(ctrl));
    await tester.pumpAndSettle();

    expect(find.text('Auto'), findsOneWidget);

    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();

    // The draggable-pin map sheet is on screen.
    expect(find.byType(FlutterMap), findsOneWidget);

    await tester.tap(find.text('Confirm pin'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Pin confirmed'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    ctrl.dispose();
  });
}