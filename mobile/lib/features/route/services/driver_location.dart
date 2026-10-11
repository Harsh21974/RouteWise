import 'package:geolocator/geolocator.dart' as g;
import 'package:latlong2/latlong.dart';

/// Resolves the driver's current position, used as the route start point.
abstract class DriverLocationSource {
  Future<LatLng> current();
}

/// A fixed start point, configured through `--dart-define=DRIVER_LAT/DRIVER_LNG`
/// (defaults to Bengaluru for the local demo / emulator).
class FixedDriverLocationSource implements DriverLocationSource {
  static const String _latEnv =
      String.fromEnvironment('DRIVER_LAT', defaultValue: '12.9716');
  static const String _lngEnv =
      String.fromEnvironment('DRIVER_LNG', defaultValue: '77.5946');

  FixedDriverLocationSource({double? latitude, double? longitude})
      : _latitude = latitude ?? double.parse(_latEnv),
        _longitude = longitude ?? double.parse(_lngEnv);

  final double _latitude;
  final double _longitude;

  @override
  Future<LatLng> current() async => LatLng(_latitude, _longitude);
}

/// Live GPS via the geolocator plugin, degrading gracefully to a fixed point
/// when the device has no location service / permission / fix.
class DeviceDriverLocationSource implements DriverLocationSource {
  DeviceDriverLocationSource({DriverLocationSource? fallback})
      : _fallback = fallback ?? FixedDriverLocationSource();

  final DriverLocationSource _fallback;

  @override
  Future<LatLng> current() async {
    try {
      if (!await g.Geolocator.isLocationServiceEnabled()) {
        return _fallback.current();
      }
      var permission = await g.Geolocator.checkPermission();
      if (permission == g.LocationPermission.denied) {
        permission = await g.Geolocator.requestPermission();
      }
      if (permission == g.LocationPermission.denied ||
          permission == g.LocationPermission.deniedForever) {
        return _fallback.current();
      }
      final position = await g.Geolocator.getCurrentPosition(
        locationSettings:
            const g.LocationSettings(accuracy: g.LocationAccuracy.high),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return _fallback.current();
    }
  }
}