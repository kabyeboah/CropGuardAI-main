import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/database_helper.dart';
import '../../data/remote/firestore_service.dart';
import '../../domain/models/app_notification.dart';
import 'notification_helper.dart';

/// Community early-warning: notifies a farmer when a disease outbreak is
/// reported close to their farm. Runs from a periodic background task and is
/// idempotent — every report is alerted on at most once per device.
class OutbreakAlertService {
  /// A report is "near" when it falls within this many kilometres.
  static const double radiusKm = 25.0;

  /// Reports older than this are ignored (an outbreak from months ago is not
  /// actionable and would spam the farmer on first run).
  static const int recentDays = 14;

  static const _kAlertedIds = 'outbreak_alerted_ids_v1';
  static const _kLastLat = 'last_known_lat';
  static const _kLastLon = 'last_known_lon';

  /// Persist the user's most recent coordinates so the background task has a
  /// location to compare against without acquiring a fresh GPS fix.
  static Future<void> saveLastKnownLocation(
      SharedPreferences prefs, double lat, double lon) async {
    await prefs.setDouble(_kLastLat, lat);
    await prefs.setDouble(_kLastLon, lon);
  }

  static DateTime? _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    return null;
  }

  static num? _coord(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v is num) return v;
    }
    return null;
  }

  /// Scans recent outbreak reports and fires a single grouped notification for
  /// any not-yet-alerted reports within [radiusKm]. Returns true on success
  /// (including the no-op cases) so the WorkManager task is not retried.
  static Future<bool> checkAndNotify({
    required FirestoreService firestore,
    required SharedPreferences prefs,
    required DatabaseHelper db,
  }) async {
    try {
      double? lat = prefs.getDouble(_kLastLat);
      double? lon = prefs.getDouble(_kLastLon);
      if (lat == null || lon == null) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) {
            lat = last.latitude;
            lon = last.longitude;
          }
        } catch (e) {
          dev.log('Failed to fetch last known position in background: $e');
        }
      }
      // Without a location we can't measure proximity — skip quietly.
      if (lat == null || lon == null) return true;

      final reports = await firestore.getOutbreakReports();
      final alerted = prefs.getStringList(_kAlertedIds)?.toSet() ?? <String>{};
      final now = DateTime.now();

      final newlyAlerted = <String>[];
      var nearbyCount = 0;
      String? nearestDisease;
      var nearestDist = double.infinity;

      for (final r in reports) {
        final id = r['id'] as String?;
        if (id == null || alerted.contains(id)) continue;

        final rLat = _coord(r, const ['latitude', 'lat']);
        final rLon = _coord(r, const ['longitude', 'lng', 'lon']);
        if (rLat == null || rLon == null) continue;

        final dt = _toDate(r['timestamp'] ?? r['date']);
        if (dt != null && now.difference(dt).inDays > recentDays) continue;

        final distKm = Geolocator.distanceBetween(
              lat, lon, rLat.toDouble(), rLon.toDouble(),
            ) /
            1000.0;
        if (distKm > radiusKm) continue;

        nearbyCount++;
        newlyAlerted.add(id);
        if (distKm < nearestDist) {
          nearestDist = distKm;
          nearestDisease = (r['disease'] ?? r['diseaseName']) as String? ??
              'A crop disease';
        }
      }

      if (nearbyCount == 0 || nearestDisease == null) return true;

      const title = 'Disease outbreak near you';
      final dist = nearestDist.toStringAsFixed(0);
      final body = nearbyCount == 1
          ? '$nearestDisease reported about $dist km away. Inspect your crops.'
          : '$nearbyCount outbreaks within ${radiusKm.toInt()} km — '
              'nearest: $nearestDisease (~$dist km). Inspect your crops.';

      await NotificationHelper.showRiskAlert(title: title, message: body);
      await db.insertNotification(
        AppNotification(
          id: '',
          title: title,
          body: body,
          type: 'outbreak',
          isRead: false,
          createdAt: now,
        ),
      );

      alerted.addAll(newlyAlerted);
      await prefs.setStringList(_kAlertedIds, alerted.toList());
      return true;
    } catch (e) {
      dev.log('OutbreakAlertService failed: $e');
      return false;
    }
  }
}
