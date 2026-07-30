/// Offline resolver mapping a GPS coordinate to one of Ghana's 16 administrative
/// regions. Used by outbreak reporting so reports carry a human-readable region
/// without a network round-trip — aligning with the app's offline-first design
/// (cached map tiles, [LocationHelper] regional fallbacks).
///
/// Resolution is nearest-centroid against each region's capital. Coordinates
/// outside Ghana's bounding box resolve to the generic label [outsideGhana] so
/// stray fixes aren't mislabelled as a real region.
class GhanaRegion {
  GhanaRegion._();

  /// Label used when a coordinate falls outside Ghana's bounding box.
  static const String outsideGhana = 'Ghana';

  // Ghana's approximate bounding box (with a small margin).
  static const double _minLat = 4.5;
  static const double _maxLat = 11.2;
  static const double _minLng = -3.3;
  static const double _maxLng = 1.3;

  /// Region name → capital coordinate (lat, lng). Sixteen regions as of the
  /// 2019 reorganisation.
  static const Map<String, (double, double)> _regionCentroids = {
    'Greater Accra': (5.6037, -0.1870),
    'Ashanti': (6.6885, -1.6244),
    'Western': (4.9344, -1.7133),
    'Western North': (6.2086, -2.4853),
    'Central': (5.1053, -1.2466),
    'Eastern': (6.0941, -0.2591),
    'Volta': (6.6110, 0.4710),
    'Oti': (8.0667, 0.1833),
    'Northern': (9.4008, -0.8393),
    'Savannah': (9.0833, -1.8194),
    'North East': (10.5269, -0.3686),
    'Upper East': (10.7856, -0.8514),
    'Upper West': (10.0601, -2.5099),
    'Bono': (7.3349, -2.3123),
    'Bono East': (7.5907, -1.9390),
    'Ahafo': (6.8000, -2.5167),
  };

  /// List of all 16 administrative regions in Ghana.
  static List<String> get allRegions => _regionCentroids.keys.toList();

  /// Returns the nearest Ghana region for [lat]/[lng], or [outsideGhana] when
  /// the coordinate is outside the country's bounding box.
  static String forCoordinates(double lat, double lng) {
    if (lat < _minLat || lat > _maxLat || lng < _minLng || lng > _maxLng) {
      return outsideGhana;
    }
    String nearest = outsideGhana;
    double best = double.infinity;
    _regionCentroids.forEach((name, c) {
      final d = _squaredDistance(lat, lng, c.$1, c.$2);
      if (d < best) {
        best = d;
        nearest = name;
      }
    });
    return nearest;
  }

  /// Returns the centroid (lat, lng) for a known region name, or `null` if
  /// the name is not found. Used by [HomeProvider] to look up the weather
  /// location for the user's saved onboarding region.
  static (double, double)? regionCentroid(String name) =>
      _regionCentroids[name];

  // Squared planar distance is enough for nearest-neighbour ranking over a
  // country-sized area; no need for haversine here.
  static double _squaredDistance(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat1 - lat2;
    final dLng = lng1 - lng2;
    return (dLat * dLat) + (dLng * dLng);
  }
}
