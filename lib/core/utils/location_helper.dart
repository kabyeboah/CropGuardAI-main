import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outbreak_alert_service.dart';

/// A geographic coordinate used across the app for weather, spray advisory and
/// outbreak reporting.
class GeoPoint {
  final double latitude;
  final double longitude;

  /// True when the coordinate came from a real device fix (current or last
  /// known) rather than the regional default fallback.
  final bool isPrecise;

  const GeoPoint(this.latitude, this.longitude, {this.isPrecise = false});
}

/// Centralised location acquisition so screens/providers don't each re-implement
/// permission handling and fallbacks. Resolution order:
///   1. fresh GPS fix (if permission granted and a fix is obtained in time)
///   2. last-known device position
///   3. cached coordinates persisted by [OutbreakAlertService]
///   4. regional default (Kumasi, Ghana)
class LocationHelper {
  /// Regional default — central Ghana (Kumasi). Used only when no real fix or
  /// cached coordinate is available so weather/advisory still renders.
  static const double defaultLat = 6.6666;
  static const double defaultLon = -1.6163;
  static const GeoPoint defaultPoint =
      GeoPoint(defaultLat, defaultLon, isPrecise: false);

  /// Acquires the best available coordinate without throwing. Never returns
  /// null so callers always have something to query weather/advisory with.
  static Future<GeoPoint> currentOrFallback({
    SharedPreferences? prefs,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.low),
          ).timeout(timeout);
          if (prefs != null) {
            await OutbreakAlertService.saveLastKnownLocation(
                prefs, position.latitude, position.longitude);
          }
          return GeoPoint(position.latitude, position.longitude,
              isPrecise: true);
        }
      }
    } catch (_) {
      // Fall through to cached / default below.
    }

    // Last-known device fix.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return GeoPoint(last.latitude, last.longitude, isPrecise: true);
      }
    } catch (_) {/* ignore */}

    // Coordinates cached by a previous successful fix.
    if (prefs != null) {
      final lat = prefs.getDouble('last_known_lat');
      final lon = prefs.getDouble('last_known_lon');
      if (lat != null && lon != null) {
        return GeoPoint(lat, lon, isPrecise: true);
      }
    }

    return defaultPoint;
  }

  /// Coarsens a geographic coordinate (latitude or longitude) to [precision] decimal
  /// places to protect farmer privacy and prevent exact plot/homestead identification.
  ///
  /// Precision reference (at equator):
  /// - 1 decimal place: ~11.1 km
  /// - 2 decimal places: ~1.11 km (default: protects farm plot while preserving community accuracy)
  /// - 3 decimal places: ~111 m
  static double coarsen(double coordinate, {int precision = 2}) {
    return double.parse(coordinate.toStringAsFixed(precision));
  }

  /// Coarsens a [GeoPoint] coordinate pair to [precision] decimal places.
  static GeoPoint coarsenPoint(GeoPoint point, {int precision = 2}) {
    return GeoPoint(
      coarsen(point.latitude, precision: precision),
      coarsen(point.longitude, precision: precision),
      isPrecise: point.isPrecise,
    );
  }

  /// Coarsens a latitude/longitude pair and returns a tuple.
  static (double, double) coarsenCoordinates(
    double lat,
    double lon, {
    int precision = 2,
  }) {
    return (
      coarsen(lat, precision: precision),
      coarsen(lon, precision: precision),
    );
  }
}
