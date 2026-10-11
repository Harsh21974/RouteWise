/// Compact human-readable distance, e.g. `430 m` / `12.3 km`.
String formatMeters(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// Compact human-readable drive time, e.g. `34 min` / `1h 12m`.
String formatEta(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '${hours}h ${rest}m';
}