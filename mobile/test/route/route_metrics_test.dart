import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:routewise_mobile/features/route/services/geometry_codec.dart';
import 'package:routewise_mobile/features/route/services/route_metrics.dart';

/// Test-side encoder for round-trip checks of the decoder.
String encodePolyline(List<LatLng> points, {int precision = 5}) {
  final factor = math.pow(10, precision).toInt();
  final buffer = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;
  for (final p in points) {
    final lat = (p.latitude * factor).round();
    final lng = (p.longitude * factor).round();
    _writeValue(lat - prevLat, buffer);
    _writeValue(lng - prevLng, buffer);
    prevLat = lat;
    prevLng = lng;
  }
  return buffer.toString();
}

void _writeValue(int value, StringBuffer buffer) {
  var v = (value << 1) ^ (value >> 31);
  while (v >= 0x20) {
    buffer.writeCharCode((0x20 | (v & 0x1F)) + 63);
    v >>= 5;
  }
  buffer.writeCharCode(v + 63);
}

void main() {
  group('decodeEncodedPolyline', () {
    test('decodes the canonical example (San Francisco example path)', () {
      final points = decodeEncodedPolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points.length, 3);
      expect(points[0].latitude, closeTo(38.5, 1e-9));
      expect(points[0].longitude, closeTo(-120.2, 1e-9));
      expect(points[1].latitude, closeTo(40.7, 1e-9));
      expect(points[1].longitude, closeTo(-120.95, 1e-9));
      expect(points[2].latitude, closeTo(43.252, 1e-9));
      expect(points[2].longitude, closeTo(-126.453, 1e-9));
    });

    test('returns empty for an empty string', () {
      expect(decodeEncodedPolyline(''), isEmpty);
    });

    test('round-trips a path with negative deltas exactly', () {
      final path = [
        const LatLng(12.9716, 77.5946),
        const LatLng(12.9845, 77.5901),
        const LatLng(12.9752, 77.6012),
        const LatLng(12.9688, 77.6128),
      ];
      final decoded = decodeEncodedPolyline(encodePolyline(path));
      expect(decoded.length, path.length);
      for (var i = 0; i < path.length; i++) {
        expect(decoded[i].latitude, closeTo(path[i].latitude, 1e-6));
        expect(decoded[i].longitude, closeTo(path[i].longitude, 1e-6));
      }
    });
  });

  group('computeStopMetrics', () {
    test('falls back to straight-line hops without geometry', () {
      const start = LatLng(12.9716, 77.5946);
      const stopA = LatLng(12.98, 77.5946);
      const stopB = LatLng(12.99, 77.5946);

      final metrics = computeStopMetrics(
        start: start,
        geometry: const [],
        stops: const [stopA, stopB],
        totalDistanceMeters: 4200,
        totalDurationSeconds: 420, // 10 m/s average
      );

      expect(metrics.length, 2);
      final a = _haversine(start, stopA);
      expect(metrics[0].cumulativeMeters, closeTo(a, 5));
      expect(metrics[0].etaSeconds, closeTo(a / 10.0, 1));
      expect(
        metrics[1].cumulativeMeters,
        closeTo(a + _haversine(stopA, stopB), 5),
      );
      expect(
        metrics[1].etaSeconds,
        closeTo(metrics[1].cumulativeMeters / 10.0, 1),
      );
    });

    test('cumulative distances and ETAs stay monotonic along a geometry', () {
      const start = LatLng(12.97, 77.59);
      final geometry = <LatLng>[
        start,
        const LatLng(12.98, 77.59),
        const LatLng(12.985, 77.585),
        const LatLng(12.975, 77.58),
      ];
      final stops = [
        const LatLng(12.9785, 77.5895),
        const LatLng(12.976, 77.5808),
      ];

      final metrics = computeStopMetrics(
        start: start,
        geometry: geometry,
        stops: stops,
        totalDistanceMeters: 4000,
        totalDurationSeconds: 400, // 10 m/s
      );

      expect(metrics.length, 2);
      expect(metrics[0].cumulativeMeters, greaterThan(0));
      expect(
        metrics[1].cumulativeMeters,
        greaterThan(metrics[0].cumulativeMeters),
      );
      expect(metrics[1].etaSeconds,
          closeTo(metrics[1].cumulativeMeters / 10.0, 1));
    });

    test('empty stops yields no metrics', () {
      final metrics = computeStopMetrics(
        start: const LatLng(0, 0),
        geometry: const [],
        stops: const [],
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
      );
      expect(metrics, isEmpty);
    });

    test('missing totals fall back to a 10 m/s city cruise', () {
      final metrics = computeStopMetrics(
        start: const LatLng(12.97, 77.59),
        geometry: const [],
        stops: const [LatLng(12.985, 77.59)],
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
      );
      final meters = metrics.single.cumulativeMeters;
      expect(meters, greaterThan(0));
      expect(metrics.single.etaSeconds, closeTo(meters / 10.0, 1));
    });
  });
}

double _haversine(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final sinLat = math.sin(dLat / 2);
  final sinLng = math.sin(dLng / 2);
  final h = sinLat * sinLat +
      math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * sinLng * sinLng;
  return 2 * earthRadius * math.asin(math.sqrt(h));
}