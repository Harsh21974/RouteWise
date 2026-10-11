import 'package:routewise_mobile/features/intake/data/parcel.dart';
import 'package:routewise_mobile/features/intake/data/parsed_address.dart';
import 'package:routewise_mobile/features/intake/services/parcel_api.dart';

/// In-memory double for [ParcelApi] so tests never touch the network.
class FakeParcelApi extends ParcelApi {
  FakeParcelApi();

  /// Emulates the "order not found" scan response.
  bool scanThrowsNotFound = false;

  final List<Parcel> backend = [];

  int get nextId => backend.length + 1;

  @override
  Future<Parcel> scan(String orderId) async {
    if (scanThrowsNotFound) throw OrderNotFoundException();
    final p = Parcel(
      id: nextId,
      orderId: orderId,
      rawAddress: 'Barcode parcel $orderId',
      latitude: 12.9716,
      longitude: 77.5946,
      geocodeStatus: ParcelGeocodeStatus.geocoded,
    );
    backend.add(p);
    return p;
  }

  @override
  Future<OcrResult> ocr(String rawText, {String? orderId}) async {
    final p = Parcel(
      id: nextId,
      orderId: orderId,
      rawAddress: rawText,
      latitude: 13.0358,
      longitude: 77.5970,
      geocodeStatus: ParcelGeocodeStatus.autoGeocoded,
      requiresPinConfirmation: true,
    );
    backend.add(p);
    return OcrResult(
      parcel: p,
      parsedAddress: const ParsedAddress(
        street: '12 MG Road',
        city: 'Bengaluru',
        pincode: '560001',
      ),
    );
  }

  @override
  Future<Parcel> manual(ManualAddress address) async {
    final p = Parcel(
      id: nextId,
      orderId: address.orderId,
      rawAddress: [address.street, address.city].whereType<String>().join(', '),
      geocodeStatus: ParcelGeocodeStatus.notGeocoded,
    );
    backend.add(p);
    return p;
  }

  @override
  Future<Parcel> geocode(int id) async {
    final idx = backend.indexWhere((p) => p.id == id);
    final old = backend[idx];
    final p = Parcel(
      id: old.id,
      orderId: old.orderId,
      rawAddress: old.rawAddress,
      latitude: 13.0358,
      longitude: 77.5970,
      geocodeStatus: ParcelGeocodeStatus.autoGeocoded,
      requiresPinConfirmation: true,
    );
    backend[idx] = p;
    return p;
  }

  @override
  Future<Parcel> updateCoordinates(
      int id, double latitude, double longitude) async {
    final idx = backend.indexWhere((p) => p.id == id);
    final old = backend[idx];
    final p = Parcel(
      id: old.id,
      orderId: old.orderId,
      rawAddress: old.rawAddress,
      latitude: latitude,
      longitude: longitude,
      geocodeStatus: ParcelGeocodeStatus.confirmed,
    );
    backend[idx] = p;
    return p;
  }
}