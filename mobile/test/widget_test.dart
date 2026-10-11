import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:routewise_mobile/app.dart';

void main() {
  setUpAll(() {
    // Keep tests hermetic: fonts fall back to the system font instead of
    // being fetched from the network.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shell shows three tabs and defaults to the Scan screen',
      (tester) async {
    await tester.pumpWidget(const RouteWiseApp());
    await tester.pumpAndSettle();

    expect(find.text('Scan / Add'), findsOneWidget);
    expect(find.text('My Route'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Add a parcel'), findsOneWidget);
  });

  testWidgets('tapping a tab switches the visible screen', (tester) async {
    await tester.pumpWidget(const RouteWiseApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Route'));
    await tester.pumpAndSettle();
    expect(find.text('Your route is empty'), findsOneWidget);
    expect(find.text('Optimize My Route'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('DAY PROGRESS'), findsOneWidget);
    expect(find.text('DELIVERED'), findsOneWidget);
    expect(find.text('0 of 0 delivered'), findsOneWidget);
  });
}