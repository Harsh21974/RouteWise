import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/parsed_address.dart';
import '../data/parcel.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class OrderNotFoundException implements Exception {
  OrderNotFoundException();
  @override
  String toString() => 'Order not found';
}

class ParcelApiException implements Exception {
  ParcelApiException({required this.message, this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// OCR result bundle
// ---------------------------------------------------------------------------

class OcrResult {
  const OcrResult({required this.parcel, required this.parsedAddress});
  final Parcel parcel;
  final ParsedAddress parsedAddress;
}

// ---------------------------------------------------------------------------
// HTTP client
// ---------------------------------------------------------------------------

class ParcelApi {
  ParcelApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8080',
            );

  final http.Client _client;
  final String _baseUrl;

  // -- Scan -----------------------------------------------------------------

  Future<Parcel> scan(String orderId) async {
    final res = await _post('/api/deliveries/scan', {'orderId': orderId});
    if (res.statusCode == 404) throw OrderNotFoundException();
    _check(res);
    return _unwrapDelivery(res);
  }

  // -- OCR ------------------------------------------------------------------

  Future<OcrResult> ocr(String rawText, {String? orderId}) async {
    final res = await _post('/api/deliveries/ocr', {
      'rawText': rawText,
      'orderId': ?orderId,
    });
    _check(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final parsed = data['parsedAddress'] is Map<String, dynamic>
        ? ParsedAddress.fromJson(data['parsedAddress'] as Map<String, dynamic>)
        : const ParsedAddress();
    return OcrResult(
      parcel: _unwrapDeliveryData(data),
      parsedAddress: parsed,
    );
  }

  // -- Manual ---------------------------------------------------------------

  Future<Parcel> manual(ManualAddress address) async {
    final res = await _post('/api/deliveries/manual', address.toJson());
    _check(res);
    return _unwrapDelivery(res);
  }

  // -- Geocode --------------------------------------------------------------

  Future<Parcel> geocode(int id) async {
    final res = await _post('/api/deliveries/$id/geocode', null);
    _check(res);
    return Parcel.fromJson(jsonDecode(res.body));
  }

  // -- PATCH coordinates (CONFIRMED) ----------------------------------------

  Future<Parcel> updateCoordinates(
      int id, double latitude, double longitude) async {
    final url = Uri.parse('$_baseUrl/api/deliveries/$id/coordinates');
    final res = await _guarded(() => _client.patch(
          url,
          headers: _jsonHeaders,
          body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
        ));
    _check(res);
    return Parcel.fromJson(jsonDecode(res.body));
  }

  void dispose() => _client.close();

  // -- internals ------------------------------------------------------------

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  Future<http.Response> _post(String path, Map<String, dynamic>? body) {
    return _guarded(() => _client.post(
          Uri.parse('$_baseUrl$path'),
          headers: _jsonHeaders,
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  /// Runs a request, converting transport-level failures (network down,
  /// refused connection, timeout) into a [ParcelApiException] so UI handlers
  /// that catch that type can show a real error instead of swallowing it.
  Future<T> _guarded<T>(Future<T> Function() send) async {
    try {
      return await send();
    } on SocketException catch (e) {
      throw ParcelApiException(message: 'Cannot reach the server: ${e.message}');
    } on http.ClientException catch (e) {
      throw ParcelApiException(message: 'Cannot reach the server: ${e.message}');
    } on TimeoutException {
      throw ParcelApiException(message: 'The server did not respond in time.');
    }
  }

  void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String msg;
    try {
      msg = (jsonDecode(res.body) as Map<String, dynamic>)['message'] as String? ??
          'Request failed';
    } catch (_) {
      msg = 'Request failed (${res.statusCode})';
    }
    throw ParcelApiException(message: msg, statusCode: res.statusCode);
  }

  /// Intake endpoints wrap the delivery in a `{delivery, source, parsedAddress}`
  /// envelope; extract the `DeliveryDto` before parsing.
  Parcel _unwrapDelivery(http.Response res) {
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return _unwrapDeliveryData(data);
  }

  Parcel _unwrapDeliveryData(Map<String, dynamic> data) {
    final delivery = data['delivery'] as Map<String, dynamic>;
    return Parcel.fromJson(delivery);
  }
}
