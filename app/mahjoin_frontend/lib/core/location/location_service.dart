import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Wraps geolocator to provide the device's current location.
/// Falls back to Hong Kong coords if permission is denied or an error occurs.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const defaultLocation = LatLng(22.3193, 114.1694);

  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // meters — only emit when moved > 10 m
  );

  /// Returns the device location, or [defaultLocation] on any error.
  Future<LatLng> getCurrentPosition() async {
    try {
      if (!await _ensurePermission()) return defaultLocation;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return defaultLocation;
    }
  }

  /// Emits position updates. Falls back silently if permission is denied.
  Stream<LatLng> watchPosition() async* {
    try {
      if (!await _ensurePermission()) return;
      yield* Geolocator.getPositionStream(locationSettings: _settings)
          .map((p) => LatLng(p.latitude, p.longitude));
    } catch (_) {}
  }

  Future<bool> _ensurePermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }
}
