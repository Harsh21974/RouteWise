import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Decodes an OSRM / Google encoded polyline string (precision 5, the default
/// for the `geometries=polyline` request the backend uses) into [LatLng]s.
///
/// Implemented locally (the `polyline` package is unmaintained/pre-null-safety)
/// from the public algorithm spec.
List<LatLng> decodeEncodedPolyline(String encoded, {int precision = 5}) {
  final out = <LatLng>[];
  if (encoded.isEmpty) return out;

  final factor = math.pow(10, precision).toDouble();
  final codes = encoded.codeUnits;
  var index = 0;
  var lat = 0.0;
  var lng = 0.0;

  while (index < codes.length) {
    var result = 0;
    var shift = 0;
    int b;
    do {
      b = codes[index++] - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dLat / factor;

    result = 0;
    shift = 0;
    do {
      b = codes[index++] - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dLng / factor;

    out.add(LatLng(lat, lng));
  }
  return out;
}