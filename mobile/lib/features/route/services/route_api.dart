import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/route_plan.dart';
import 'geometry_codec.dart';
import 'route_metrics.dart';

class RoutePlanException implements Exception {
  RoutePlanException({required this.message, this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// HTTP client for the route planning APIs.
class RouteApi {
  RouteApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8080',
            );

  final http.Client _client;
  final String _baseUrl;

  /// POST /api/routes/optimize with the given pending delivery ids and the
  /// driver's start point; returns the solved route with visiting order,
  /// geometry and per-stop cumulative distance/ETA.
  Future<RoutePlan> optimize({
    required List<int> deliveryIds,
    required LatLng start,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/api/routes/optimize'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'deliveryIds': deliveryIds,
        'startLatitude': start.latitude,
        'startLongitude': start.longitude,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw RoutePlanException(
        message: _extractMessage(res),
        statusCode: res.statusCode,
      );
    }
    return _parseRoutePlan(jsonDecode(res.body) as Map<String, dynamic>);
  }

  void dispose() => _client.close();

  // -- internals ------------------------------------------------------------

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  String _extractMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        final message = body['message']?.toString() ?? body['error']?.toString();
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {
      // fall through to the generic message
    }
    return 'Optimization failed (${res.statusCode})';
  }

  RoutePlan _parseRoutePlan(Map<String, dynamic> json) {
    final startJson = json['startLocation'] as Map<String, dynamic>? ?? const {};
    final start = LatLng(
      (startJson['latitude'] as num? ?? 0).toDouble(),
      (startJson['longitude'] as num? ?? 0).toDouble(),
    );

    final rawDeliveries = (json['orderedDeliveries'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    final totalMeters = (json['totalDistanceMeters'] as num?)?.toDouble() ?? 0;
    final totalSeconds = (json['totalDurationSeconds'] as num?)?.toDouble() ?? 0;
    final geometry = decodeEncodedPolyline(json['geometry'] as String? ?? '');

    final stopPoints = [
      for (final d in rawDeliveries)
        LatLng(
          (d['latitude'] as num).toDouble(),
          (d['longitude'] as num).toDouble(),
        ),
    ];
    final metrics = computeStopMetrics(
      start: start,
      geometry: geometry,
      stops: stopPoints,
      totalDistanceMeters: totalMeters,
      totalDurationSeconds: totalSeconds,
    );

    final stops = <OrderedStop>[
      for (var i = 0; i < rawDeliveries.length; i++)
        OrderedStop(
          deliveryId: (rawDeliveries[i]['id'] as num).toInt(),
          order: i + 1,
          rawAddress: (rawDeliveries[i]['rawAddress'] as String?) ?? '',
          orderId: rawDeliveries[i]['orderId'] as String?,
          latitude: (rawDeliveries[i]['latitude'] as num).toDouble(),
          longitude: (rawDeliveries[i]['longitude'] as num).toDouble(),
          cumulativeMeters: metrics[i].cumulativeMeters,
          etaSeconds: metrics[i].etaSeconds,
          requiresPinConfirmation:
              rawDeliveries[i]['requiresPinConfirmation'] as bool? ?? false,
        ),
    ];

    return RoutePlan(
      routeId: (json['routeId'] as num?)?.toInt(),
      start: start,
      stops: stops,
      totalDistanceMeters: totalMeters,
      totalDurationSeconds: totalSeconds,
      geometryPoints: geometry,
    );
  }
}