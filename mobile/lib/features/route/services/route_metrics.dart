import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Per-stop cumulative travel distance and time along the planned path.
class StopMetric {
  const StopMetric({required this.cumulativeMeters, required this.etaSeconds});

  final double cumulativeMeters;
  final double etaSeconds;
}

/// Computes, for each stop in visiting order, its cumulative distance and ETA
/// measured from the route start.
///
/// When the backend returns a driving geometry, the path is walked and every
/// stop is snapped to the nearest point on it — monotonically along the route —
/// so the figures follow roads instead of straight lines. Without geometry
/// (single-stop routes) it falls back to straight hops from [start].
///
/// ETA derives from the average speed implied by the response totals
/// ([totalDistanceMeters] over [totalDurationSeconds]), falling back to a
/// city-cruising 36 km/h when the totals are missing.
List<StopMetric> computeStopMetrics({
  required LatLng start,
  required List<LatLng> geometry,
  required List<LatLng> stops,
  required double totalDistanceMeters,
  required double totalDurationSeconds,
}) {
  if (stops.isEmpty) return const [];

  final path = geometry.isNotEmpty ? geometry : [start, ...stops];
  final prefix = _cumulativePath(path);
  final avgSpeed = _averageSpeed(totalDistanceMeters, totalDurationSeconds);

  final out = <StopMetric>[];
  var searchStart = 0;
  for (final stop in stops) {
    var best = searchStart;
    var bestDistance = _haversineMeters(path[searchStart], stop);
    for (var i = searchStart + 1; i < path.length; i++) {
      final d = _haversineMeters(path[i], stop);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    searchStart = math.max(searchStart, best);
    final cumulative = prefix[best];
    out.add(
      StopMetric(
        cumulativeMeters: cumulative,
        etaSeconds: cumulative / avgSpeed,
      ),
    );
  }
  return out;
}

/// Meters walked from `path[0]` to each `path[i]` (prefix[i]).
List<double> _cumulativePath(List<LatLng> path) {
  final prefix = List<double>.filled(path.length, 0);
  for (var i = 1; i < path.length; i++) {
    prefix[i] = prefix[i - 1] + _haversineMeters(path[i - 1], path[i]);
  }
  return prefix;
}

double _averageSpeed(double totalMeters, double totalSeconds) {
  if (totalSeconds > 0 && totalMeters > 0) return totalMeters / totalSeconds;
  return 10.0; // 36 km/h city cruising fallback.
}

double _haversineMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = _radians(b.latitude - a.latitude);
  final dLng = _radians(b.longitude - a.longitude);
  final sinLat = math.sin(dLat / 2);
  final sinLng = math.sin(dLng / 2);
  final h = sinLat * sinLat +
      math.cos(_radians(a.latitude)) * math.cos(_radians(b.latitude)) * sinLng * sinLng;
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

double _radians(double degrees) => degrees * math.pi / 180;