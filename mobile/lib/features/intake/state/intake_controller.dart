import 'package:flutter/foundation.dart';

import '../data/parsed_address.dart';
import '../data/parcel.dart';
import '../services/parcel_api.dart';

/// Manages the running list of today's added parcels and orchestrates every
/// intake flow (scan, OCR, manual) including automatic geocoding.
class IntakeController extends ChangeNotifier {
  IntakeController([ParcelApi? api]) : _api = api ?? ParcelApi();

  final ParcelApi _api;
  final List<Parcel> _parcels = [];

  List<Parcel> get parcels => List.unmodifiable(_parcels);
  int get addedCount => _parcels.length;

  // -- Scan -----------------------------------------------------------------

  Future<Parcel> scanBarcode(String orderId) async {
    final parcel = await _api.scan(orderId);
    _add(parcel);
    return parcel;
  }

  // -- OCR ------------------------------------------------------------------

  /// Call the OCR endpoint; the created [OcrResult] is shown for review but
  /// not yet added to the running list.
  Future<OcrResult> ocrRawText(String rawText) => _api.ocr(rawText);

  /// Driver confirms the OCR result as-is.
  Future<Parcel> commitOcr(OcrResult result) async {
    final parcel = await _geocodeIfPossible(result.parcel);
    _add(parcel);
    return parcel;
  }

  /// Driver edited the parsed address → create a new parcel via the manual
  /// endpoint so the backend stores the corrected address.
  Future<Parcel> commitEditedOcr(ManualAddress address) async {
    final parcel = await _api.manual(address);
    final geocoded = await _geocodeIfPossible(parcel);
    _add(geocoded);
    return geocoded;
  }

  // -- Manual ---------------------------------------------------------------

  Future<Parcel> manualSave(ManualAddress address) async {
    final parcel = await _api.manual(address);
    final geocoded = await _geocodeIfPossible(parcel);
    _add(geocoded);
    return geocoded;
  }

  // -- Pin confirm ----------------------------------------------------------

  Future<Parcel> confirmPin(int id, double latitude, double longitude) async {
    final updated = await _api.updateCoordinates(id, latitude, longitude);
    _replace(updated);
    return updated;
  }

  // -- internal -------------------------------------------------------------

  Future<Parcel> _geocodeIfPossible(Parcel parcel) async {
    if (parcel.geocodeStatus == ParcelGeocodeStatus.notGeocoded ||
        parcel.geocodeStatus == ParcelGeocodeStatus.failed) {
      try {
        return await _api.geocode(parcel.id);
      } catch (_) {
        return parcel;
      }
    }
    return parcel;
  }

  void _add(Parcel p) {
    _parcels.insert(0, p);
    notifyListeners();
  }

  void _replace(Parcel updated) {
    final idx = _parcels.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _parcels[idx] = updated;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
