import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_secrets.dart';
import 'ghana_region.dart';
import 'location_helper.dart';

/// Service for reverse geocoding coordinates to human-readable place names using
/// OpenStreetMap's Nominatim service.
///
/// Complies with OpenStreetMap's Nominatim Usage Policy:
///   1. Identifies the app with a valid, contact-bearing User-Agent ([AppSecrets.osmUserAgent]).
///   2. Strictly throttles network requests to a maximum of 1 request per second.
///   3. Aggressively caches reverse geocode responses (both in-memory and persistent
///      via [SharedPreferences]) bucketed by coarsened coordinates (~1.1 km grid).
class NominatimService {
  final http.Client _httpClient;
  final SharedPreferences? _prefs;

  NominatimService({
    http.Client? httpClient,
    SharedPreferences? prefs,
  })  : _httpClient = httpClient ?? http.Client(),
        _prefs = prefs;

  /// In-memory cache for fast coordinate lookups within the same session.
  /// Key: `"$coarsenedLat,$coarsenedLon"`, Value: `(placeName, timestamp)`
  static final Map<String, (String, DateTime)> _memoryCache = {};

  /// Tracks the timestamp of the last network call to enforce 1 req/sec rate limit.
  static DateTime? _lastNetworkRequestTime;

  /// Minimum delay between successive Nominatim network requests (1.0 second).
  static const Duration minRequestInterval = Duration(milliseconds: 1000);

  /// Cache TTL for reverse geocoded place names (30 days).
  static const Duration cacheTtl = Duration(days: 30);

  /// Clears in-memory and persistent cache (useful for testing or cache resets).
  static void clearCache({SharedPreferences? prefs}) {
    _memoryCache.clear();
    _lastNetworkRequestTime = null;
    if (prefs != null) {
      final keys =
          prefs.getKeys().where((k) => k.startsWith('nominatim_cache_'));
      for (final key in keys) {
        prefs.remove(key);
      }
    }
  }

  /// Reverse geocodes [lat] and [lon] to a localized place name (e.g. "Ejisu, Ghana").
  ///
  /// Automatically rounds coordinates to 2 decimal places (~1.1 km) before lookup
  /// to protect farmer privacy and maximize cache hit rates.
  Future<String> reverseGeocode(
    double lat,
    double lon, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final coarsenedLat = LocationHelper.coarsen(lat, precision: 2);
    final coarsenedLon = LocationHelper.coarsen(lon, precision: 2);
    final cacheKey = '$coarsenedLat,$coarsenedLon';

    // 1. Check in-memory cache
    final memCached = _memoryCache[cacheKey];
    if (memCached != null) {
      if (DateTime.now().difference(memCached.$2) < cacheTtl) {
        return memCached.$1;
      }
    }

    // 2. Check persistent SharedPreferences cache
    final prefs = _prefs;
    if (prefs != null) {
      final cachedJson = prefs.getString('nominatim_cache_$cacheKey');
      if (cachedJson != null) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          final name = decoded['name'] as String?;
          final timestamp = decoded['timestamp'] as int?;
          if (name != null && timestamp != null) {
            final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            if (DateTime.now().difference(cacheTime) < cacheTtl) {
              _memoryCache[cacheKey] = (name, cacheTime);
              return name;
            }
          }
        } catch (_) {}
      }
    }

    // 3. Rate limiting: ensure at least 1.0 second since the last network request
    if (_lastNetworkRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastNetworkRequestTime!);
      if (elapsed < minRequestInterval) {
        final waitDuration = minRequestInterval - elapsed;
        await Future.delayed(waitDuration);
      }
    }

    // 4. Perform network request
    try {
      _lastNetworkRequestTime = DateTime.now();
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$coarsenedLat&lon=$coarsenedLon&format=json',
      );

      final userAgent = AppSecrets.osmUserAgent;
      final response = await _httpClient.get(uri, headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
      }).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = (data['address'] as Map<String, dynamic>?) ?? {};
        final resolvedName = address['county'] as String? ??
            address['city'] as String? ??
            address['town'] as String? ??
            address['village'] as String? ??
            address['state'] as String? ??
            address['country'] as String? ??
            GhanaRegion.forCoordinates(lat, lon);

        // Store in memory cache
        final now = DateTime.now();
        _memoryCache[cacheKey] = (resolvedName, now);

        // Store in persistent cache
        if (prefs != null) {
          unawaited(prefs.setString(
            'nominatim_cache_$cacheKey',
            jsonEncode({
              'name': resolvedName,
              'timestamp': now.millisecondsSinceEpoch,
            }),
          ));
        }

        return resolvedName;
      }
    } catch (_) {
      // Fall through to offline fallback
    }

    // 5. Fallback if network or geocoding fails
    return GhanaRegion.forCoordinates(lat, lon);
  }
}
