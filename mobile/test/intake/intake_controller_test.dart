import 'package:flutter_test/flutter_test.dart';
import 'package:routewise_mobile/features/intake/data/parcel.dart';
import 'package:routewise_mobile/features/intake/data/parsed_address.dart';
import 'package:routewise_mobile/features/intake/services/parcel_api.dart';
import 'package:routewise_mobile/features/intake/state/intake_controller.dart';

import 'fake_parcel_api.dart';

void main() {
  group('IntakeController', () {
    test('scanBarcode adds a parcel and increments the count', () async {
      final ctrl = IntakeController(FakeParcelApi());
      expect(ctrl.addedCount, 0);

      final p = await ctrl.scanBarcode('ORD-1');
      expect(p.geocodeStatus, ParcelGeocodeStatus.geocoded);
      expect(ctrl.addedCount, 1);
      expect(ctrl.parcels.single.id, p.id);
      ctrl.dispose();
    });

    test('scanBarcode rethrows OrderNotFoundException without counting',
        () async {
      final ctrl = IntakeController(FakeParcelApi()..scanThrowsNotFound = true);

      await expectLater(
        ctrl.scanBarcode('MISSING'),
        throwsA(isA<OrderNotFoundException>()),
      );
      expect(ctrl.addedCount, 0);
      ctrl.dispose();
    });

    test('manualSave auto-geocodes to the amber state', () async {
      final ctrl = IntakeController(FakeParcelApi());

      final p = await ctrl.manualSave(
        const ManualAddress(street: '42 Indiranagar', city: 'Bangalore'),
      );
      expect(p.geocodeStatus, ParcelGeocodeStatus.autoGeocoded);
      expect(p.requiresPinConfirmation, isTrue);
      expect(ctrl.addedCount, 1);
      ctrl.dispose();
    });

    test('OCR stays unlisted until the driver commits it', () async {
      final ctrl = IntakeController(FakeParcelApi());

      final ocr = await ctrl.ocrRawText('12 MG Road Bengaluru 560001');
      expect(ocr.parsedAddress.city, 'Bengaluru');
      expect(ctrl.addedCount, 0);

      final p = await ctrl.commitOcr(ocr);
      expect(p.geocodeStatus, ParcelGeocodeStatus.autoGeocoded);
      expect(ctrl.addedCount, 1);
      ctrl.dispose();
    });

    test('confirmPin replaces the parcel with the CONFIRMED state', () async {
      final ctrl = IntakeController(FakeParcelApi());
      final p = await ctrl.manualSave(const ManualAddress(street: 'x'));
      expect(p.geocodeStatus, ParcelGeocodeStatus.autoGeocoded);

      final updated = await ctrl.confirmPin(p.id, 13.0012, 77.0012);
      expect(updated.geocodeStatus, ParcelGeocodeStatus.confirmed);
      expect(updated.latitude, 13.0012);
      expect(ctrl.parcels.single.geocodeStatus, ParcelGeocodeStatus.confirmed);
      ctrl.dispose();
    });
  });
}