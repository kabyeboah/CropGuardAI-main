import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:latlong2/latlong.dart';

import '../../../core/config/app_secrets.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/analytics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/cached_tile_provider.dart';
import '../../../core/utils/ghana_region.dart';
import '../../../core/utils/location_helper.dart';
import '../../../core/utils/locale_formatter.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../core/utils/content_moderation_helper.dart';
import '../../../core/utils/rate_limiter.dart';
import '../../../core/utils/user_block_service.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../../domain/repositories/i_community_repository.dart';
import '../../components/cropguard_card.dart';
import '../../components/voice_dictation_button.dart';

/// Seed outbreak reports across major farming regions of Ghana when Firestore is empty.
final List<Map<String, dynamic>> _kSeedOutbreakReports = [
  {
    'id': 'seed_ob_1',
    'isSeed': true,
    'source': 'seed',
    'disease': 'Cocoa Black Pod Rot',
    'diseaseName': 'Cocoa Black Pod Rot',
    'cropType': 'Cocoa',
    'region': 'Western North',
    'severity': 'high',
    'cases': 31,
    'latitude': 6.2001,
    'longitude': -2.4842,
    'reportedAt':
        DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
    'verifiedBy': ['u1', 'u2', 'u3', 'u4', 'u5'],
    'refutedBy': [],
    'notes':
        'Widespread pods showing dark lesions following continuous rainfall in Sefwi Wiawso.',
  },
  {
    'id': 'seed_ob_2',
    'isSeed': true,
    'source': 'seed',
    'disease': 'Cassava Mosaic Disease',
    'diseaseName': 'Cassava Mosaic Disease',
    'cropType': 'Cassava',
    'region': 'Bono',
    'severity': 'high',
    'cases': 22,
    'latitude': 7.5828,
    'longitude': -1.9394,
    'reportedAt':
        DateTime.now().subtract(const Duration(hours: 11)).toIso8601String(),
    'verifiedBy': ['u1', 'u2', 'u3', 'u4'],
    'refutedBy': [],
    'notes':
        'Whitefly activity high. Severe leaf curling and mosaic mottling in Techiman.',
  },
  {
    'id': 'seed_ob_3',
    'isSeed': true,
    'source': 'seed',
    'disease': 'Maize Common Rust',
    'diseaseName': 'Maize Common Rust',
    'cropType': 'Maize',
    'region': 'Ashanti',
    'severity': 'medium',
    'cases': 14,
    'latitude': 7.3756,
    'longitude': -1.3562,
    'reportedAt':
        DateTime.now().subtract(const Duration(hours: 18)).toIso8601String(),
    'verifiedBy': ['u1', 'u2'],
    'refutedBy': [],
    'notes': 'Pustules appearing on leaves in Ejura farming belt.',
  },
  {
    'id': 'seed_ob_4',
    'isSeed': true,
    'source': 'seed',
    'disease': 'Tomato Late Blight',
    'diseaseName': 'Tomato Late Blight',
    'cropType': 'Tomato',
    'region': 'Ashanti',
    'severity': 'high',
    'cases': 16,
    'latitude': 7.4042,
    'longitude': -1.9491,
    'reportedAt':
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    'verifiedBy': ['u1', 'u2', 'u3'],
    'refutedBy': [],
    'notes': 'Water-soaked spots on foliage in Akomadan tomato district.',
  },
  {
    'id': 'seed_ob_5',
    'isSeed': true,
    'source': 'seed',
    'disease': 'Cocoa Swollen Shoot Virus',
    'diseaseName': 'Cocoa Swollen Shoot Virus',
    'cropType': 'Cocoa',
    'region': 'Eastern',
    'severity': 'high',
    'cases': 18,
    'latitude': 6.0406,
    'longitude': -0.4503,
    'reportedAt': DateTime.now()
        .subtract(const Duration(days: 1, hours: 6))
        .toIso8601String(),
    'verifiedBy': ['u1', 'u2', 'u3', 'u4'],
    'refutedBy': [],
    'notes': 'Swollen stems and red vein banding observed near Suhum.',
  },
  {
    'id': 'seed_ob_6',
    'isSeed': true,
    'source': 'seed',
    'disease': 'Rice Blast',
    'diseaseName': 'Rice Blast',
    'cropType': 'Rice',
    'region': 'Northern',
    'severity': 'medium',
    'cases': 15,
    'latitude': 9.4075,
    'longitude': -0.8532,
    'reportedAt':
        DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    'verifiedBy': ['u1', 'u2'],
    'refutedBy': [],
    'notes': 'Spindle-shaped lesions on rice leaves around Tamale lowlands.',
  },
  {
    'id': 'seed_ob_7',
    'isSeed': true,
    'source': 'seed',
    'disease': 'Banana Black Sigatoka',
    'diseaseName': 'Banana Black Sigatoka',
    'cropType': 'Banana',
    'region': 'Volta',
    'severity': 'medium',
    'cases': 11,
    'latitude': 6.9954,
    'longitude': 0.2917,
    'reportedAt':
        DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    'verifiedBy': ['u1'],
    'refutedBy': [],
    'notes': 'Dark streaks on plantain leaves in Kpando district.',
  },
];

// Curated disease list drawn from labels.txt — most relevant for Ghana.
const _kDiseases = [
  'Cassava Mosaic Disease',
  'Cassava Brown Streak Disease',
  'Cassava Bacterial Blight',
  'Cocoa Black Pod Rot',
  'Cocoa Swollen Shoot Virus',
  'Cocoa Mirid Bugs',
  'Maize Common Rust',
  'Maize Northern Leaf Blight',
  'Tomato Late Blight',
  'Tomato Early Blight',
  'Tomato Yellow Leaf Curl Virus',
  'Rice Blast',
  'Rice Brown Spot',
  'Banana Fusarium Wilt',
  'Banana Black Sigatoka',
  'Yam Mosaic Virus',
  'Yam Anthracnose',
  'Groundnut Early Leaf Spot',
  'Cowpea Mosaic Virus',
  'Oil Palm Ganoderma Rot',
  'Sorghum Downy Mildew',
  'Millet Smut',
  'Other',
];

/// Ghana centre — default map viewport when reports lack coordinates.
const _kGhanaCenter = LatLng(7.9465, -1.0232);

/// Crops the app tracks; used to derive a report's [_cropOfDisease] and to
/// populate the crop filter bar. Order matters only for the filter chips.
const _kCrops = [
  'Cassava',
  'Cocoa',
  'Maize',
  'Tomato',
  'Rice',
  'Banana',
  'Yam',
  'Groundnut',
  'Cowpea',
  'Oil Palm',
  'Sorghum',
  'Millet',
];

/// Best-effort crop for a disease label (e.g. "Cassava Mosaic Disease" →
/// "Cassava"). Falls back to "Other" so the crop filter still works for
/// free-typed diseases.
String _cropOfDisease(String disease) {
  final d = disease.toLowerCase();
  for (final c in _kCrops) {
    if (d.startsWith(c.toLowerCase())) return c;
  }
  return 'Other';
}

/// Severity ordering so a hotspot can take the *worst* severity of its members.
int _sevRank(String s) => const {'low': 0, 'medium': 1, 'high': 2}[s] ?? 1;

/// An aggregated outbreak: all reports of one [disease] in one [region] rolled
/// into a single hotspot with a real [count], the [latest] sighting date, a
/// [center] (centroid of member coordinates) for map placement, and the worst
/// [severity] observed among its member reports.
class _Hotspot {
  final String disease;
  final String region;
  final int count;
  final DateTime? latest;
  final LatLng? center;
  final String severity;

  const _Hotspot({
    required this.disease,
    required this.region,
    required this.count,
    required this.latest,
    required this.center,
    required this.severity,
  });
}

/// Free OpenStreetMap raster tile server. No API key or billing required;
/// the User-Agent (set via [TileLayer.userAgentPackageName]) identifies the app
/// per OSM's tile usage policy. For custom enterprise/commercial tile servers
/// (e.g. Mapbox/Stadia), configure via [AppSecrets.osmTileUrl].
String get _kOsmTileUrl => AppSecrets.osmTileUrl;

/// Data carried from a scan result into the outbreak report sheet so a farmer
/// can file an outbreak straight from a CNN diagnosis. Passed as the route's
/// `extra`; all fields optional so manual entry still works.
class OutbreakReportPrefill {
  /// Detected disease display name (e.g. "Cassava Mosaic Disease").
  final String disease;

  /// CNN confidence for the detection, 0..1.
  final double? confidence;

  /// Outbreak severity ('low' | 'medium' | 'high'), already mapped from the
  /// scanner's [ScanSeverity] vocabulary.
  final String? severity;

  const OutbreakReportPrefill({
    required this.disease,
    this.confidence,
    this.severity,
  });
}

class OutbreakMapScreen extends StatefulWidget {
  /// When non-null, the report sheet opens automatically on first load with
  /// these values filled in (the scan → report flow).
  final OutbreakReportPrefill? prefill;
  final String? initialCrop;
  final String? initialRegion;

  const OutbreakMapScreen({
    super.key,
    this.prefill,
    this.initialCrop,
    this.initialRegion,
  });

  @override
  State<OutbreakMapScreen> createState() => _OutbreakMapScreenState();
}

class _OutbreakMapScreenState extends State<OutbreakMapScreen> {
  final _communityRepo = sl<ICommunityRepository>();
  final _auth = sl<FirebaseAuthService>();
  // Raw reports as fetched, kept so filters can re-aggregate without re-querying.
  List<Map<String, dynamic>> _allReports = [];
  List<_Hotspot> _hotspots = [];
  bool _loading = true;
  // True when we are displaying seed/demo data rather than real Firestore reports.
  bool _isShowingSeedData = false;
  bool _submitting = false;
  String? _error;
  final MapController _mapController = MapController();
  bool _mapReady = false;
  List<Marker> _markers = [];
  // Resolves a tapped marker back to its report for the detail sheet.
  final Map<Key, Map<String, dynamic>> _markerReports = {};
  // Active filters; 'All' means no filtering on that dimension.
  // Tile load failure tracking for graceful degradation.
  bool _mapTilesFailed = false;
  int _tileFailureCount = 0;
  String _cropFilter = 'All';
  String _severityFilter = 'All';
  String _timeframeFilter = 'Last 30 Days';
  String _sortBy = 'Most Cases';
  Position? _userPosition;
  // Density heatmap overlay toggle.
  bool _showHeatmap = false;
  // Outbreak Risk Overlay toggle.
  final bool _showRiskOverlay = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialCrop != null && widget.initialCrop!.isNotEmpty) {
      _cropFilter = widget.initialCrop!;
    }
    _load();
    _getUserLocation();
    // Arriving from a scan result: open the report sheet pre-filled once the
    // first frame is up so the map context is visible behind it.
    if (widget.prefill != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showReportSheet(prefill: widget.prefill);
      });
    }
  }

  Future<void> _getUserLocation({bool requestIfMissing = false}) async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() {
          _userPosition = pos;
        });
        return;
      }
      if (requestIfMissing && mounted) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.gpsDisabledWarning),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        if (!mounted) return;
        final granted =
            await PermissionHelper.requestLocationWithRecovery(context);
        if (granted && mounted) {
          final fresh = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.medium),
          ).timeout(const Duration(seconds: 6));
          if (mounted) {
            setState(() {
              _userPosition = fresh;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng? _parseLatLng(Map<String, dynamic> r, [int duplicateOffsetIndex = 0]) {
    final lat = (r['latitude'] ?? r['lat']) as num?;
    final lng = (r['longitude'] ?? r['lng'] ?? r['lon']) as num?;
    if (lat == null || lng == null) return null;
    if (duplicateOffsetIndex > 0) {
      final angle = (duplicateOffsetIndex * 137.5) * (math.pi / 180.0);
      final radius = 0.003 * (1 + (duplicateOffsetIndex % 3) * 0.5);
      return LatLng(
        lat.toDouble() + (radius * math.cos(angle)),
        lng.toDouble() + (radius * math.sin(angle)),
      );
    }
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  String _diseaseOf(Map<String, dynamic> r) =>
      r['disease'] as String? ?? r['diseaseName'] as String? ?? 'Outbreak';

  /// Severity of a single report, defaulting to 'medium' for legacy reports
  /// filed before severity was captured.
  String _severityOf(Map<String, dynamic> r) {
    final s = (r['severity'] as String?)?.toLowerCase();
    return (s == 'low' || s == 'medium' || s == 'high') ? s! : 'medium';
  }

  DateTime? _dateOf(Map<String, dynamic> r) {
    final ts = r['reportedAt'] ?? r['timestamp'] ?? r['date'];
    if (ts is String) return DateTime.tryParse(ts);
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    return null;
  }

  /// Region for a report: the stored value if present, otherwise derived offline
  /// from its coordinates so legacy reports still group correctly.
  String _regionOf(Map<String, dynamic> r) {
    final stored = (r['region'] as String?) ?? (r['location'] as String?);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    final p = _parseLatLng(r);
    if (p != null) return GhanaRegion.forCoordinates(p.latitude, p.longitude);
    return GhanaRegion.outsideGhana;
  }

  /// Rolls raw reports into one [_Hotspot] per disease+region, summing case
  /// counts, tracking the latest sighting and averaging coordinates so the map
  /// shows hotspots rather than a pin per duplicate report. Sorted by count
  /// (then recency) so the worst outbreaks surface first.
  List<_Hotspot> _aggregate(List<Map<String, dynamic>> reports) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in reports) {
      final diseaseKey = _diseaseOf(r).trim().toLowerCase();
      final regionKey = _regionOf(r).trim();
      final key = '$diseaseKey|$regionKey';
      groups.putIfAbsent(key, () => []).add(r);
    }

    final hotspots = <_Hotspot>[];
    groups.forEach((_, members) {
      var count = 0;
      DateTime? latest;
      var sumLat = 0.0, sumLng = 0.0, coordCount = 0;

      double weightedSum = 0;
      double totalWeight = 0;

      for (final r in members) {
        count += (r['cases'] as num?)?.toInt() ??
            (r['reportCount'] as num?)?.toInt() ??
            1;
        final dt = _dateOf(r);
        if (dt != null && (latest == null || dt.isAfter(latest))) latest = dt;

        final verifiedBy = (r['verifiedBy'] as List?) ?? [];
        final refutedBy = (r['refutedBy'] as List?) ?? [];
        final weight =
            (1 + verifiedBy.length - refutedBy.length).clamp(1, 100).toDouble();

        final sev = _severityOf(r);
        weightedSum += _sevRank(sev) * weight;
        totalWeight += weight;

        final p = _parseLatLng(r);
        if (p != null) {
          sumLat += p.latitude;
          sumLng += p.longitude;
          coordCount++;
        }
      }

      final avgRank = totalWeight > 0 ? (weightedSum / totalWeight).round() : 1;
      final finalSeverity =
          const {0: 'low', 1: 'medium', 2: 'high'}[avgRank] ?? 'medium';

      hotspots.add(_Hotspot(
        disease: _diseaseOf(members.first),
        region: _regionOf(members.first),
        count: count,
        latest: latest,
        center: coordCount > 0
            ? LatLng(sumLat / coordCount, sumLng / coordCount)
            : null,
        severity: finalSeverity,
      ));
    });

    hotspots.sort((a, b) {
      if (_sortBy == 'Most Recent') {
        final ad = a.latest ?? DateTime(1970);
        final bd = b.latest ?? DateTime(1970);
        final byDate = bd.compareTo(ad);
        if (byDate != 0) return byDate;
        return b.count.compareTo(a.count);
      } else if (_sortBy == 'Closest' && _userPosition != null) {
        final distA = a.center != null
            ? Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                a.center!.latitude,
                a.center!.longitude)
            : double.infinity;
        final distB = b.center != null
            ? Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                b.center!.latitude,
                b.center!.longitude)
            : double.infinity;
        final byDist = distA.compareTo(distB);
        if (byDist != 0) return byDist;
        return b.count.compareTo(a.count);
      } else {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        final ad = a.latest ?? DateTime(1970);
        final bd = b.latest ?? DateTime(1970);
        return bd.compareTo(ad);
      }
    });
    return hotspots;
  }

  /// Marker / legend colour for a severity level. High = red (your disease
  /// token), medium = amber, low = green.
  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
        return context.colors.diseaseRed;
      case 'low':
        return const Color(0xFF16A34A);
      case 'medium':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  void _buildMarkers() {
    final markers = <Marker>[];
    _markerReports.clear();
    final reports = _filteredIndividualReports();
    final Map<String, int> coordCounts = {};

    for (var i = 0; i < reports.length; i++) {
      final r = reports[i];
      final rawLat = (r['latitude'] ?? r['lat']) as num?;
      final rawLng = (r['longitude'] ?? r['lng'] ?? r['lon']) as num?;
      if (rawLat == null || rawLng == null) continue;

      final coordKey =
          '${rawLat.toStringAsFixed(4)}_${rawLng.toStringAsFixed(4)}';
      final dupIndex = coordCounts[coordKey] ?? 0;
      coordCounts[coordKey] = dupIndex + 1;

      final position = _parseLatLng(r, dupIndex);
      if (position == null) continue;

      final key = ValueKey('report_${r['id'] ?? i}');
      _markerReports[key] = r;

      final severity = _severityOf(r);
      final cases = (r['cases'] as num?)?.toInt() ?? 1;

      markers.add(
        Marker(
          key: key,
          point: position,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: _severityColor(severity),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Center(
              child: cases > 1
                  ? Text(
                      '$cases',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Icon(Icons.warning_amber,
                      color: Colors.white, size: 20),
            ),
          ),
        ),
      );
    }
    _markers = markers;
  }

  /// Human-friendly relative time ("2d ago"), falling back to an absolute date
  /// for anything older than a month.
  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    if (d.inDays < 30) return '${(d.inDays / 7).floor()}w ago';
    return LocaleFormatter.formatMonthDayYear(context, dt);
  }

  /// Builds density "heatmap" circles from the current hotspots. Each hotspot
  /// is a soft, translucent severity-coloured disc whose radius grows with its
  /// report [count]; overlapping discs in dense areas visually intensify —
  /// approximating a heatmap without an incompatible extra dependency.
  List<CircleMarker> _heatCircles() {
    return _hotspots
        .where((h) => h.center != null)
        .map((h) => CircleMarker(
              point: h.center!,
              // Pixel radius scaled by count and capped so a single big hotspot
              // can't swallow the 220px map.
              radius: (18 + h.count * 6).clamp(18, 70).toDouble(),
              useRadiusInMeter: false,
              color: _severityColor(h.severity).withValues(alpha: 0.25),
              borderColor: _severityColor(h.severity).withValues(alpha: 0.4),
              borderStrokeWidth: 1,
            ))
        .toList();
  }

  /// Regional Outbreak Risk Overlay: rendering geographic circles (in meters)
  /// highlighting active risk zones around outbreak hotspots.
  List<CircleMarker> _riskOverlayCircles() {
    return _hotspots.where((h) => h.center != null).map((h) {
      final color = _severityColor(h.severity);
      return CircleMarker(
        point: h.center!,
        radius: 30000, // 30 km radius
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.18),
        borderColor: color.withValues(alpha: 0.5),
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  void _showMarkerInfo(Marker marker) {
    if (!mounted) return;
    final r = marker.key == null ? null : _markerReports[marker.key];
    if (r == null) return;
    final colors = context.colors;

    final disease = _diseaseOf(r);
    final region = _regionOf(r);
    final severity = _severityOf(r);
    final cases = (r['cases'] as num?)?.toInt() ?? 1;
    final timestamp = _dateOf(r);
    final reportId = r['id'] as String?;
    final position = _parseLatLng(r);

    final verified = (r['verifiedBy'] as List?) ?? [];
    final refuted = (r['refutedBy'] as List?) ?? [];
    final totalVerified = verified.length;
    final totalRefuted = refuted.length;

    final currentUserId = _auth.currentUserIdOrNull ?? '';
    bool isUserVerified =
        currentUserId.isNotEmpty && verified.contains(currentUserId);
    bool isUserRefuted =
        currentUserId.isNotEmpty && refuted.contains(currentUserId);

    bool loading = false;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 14, color: _severityColor(severity)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    disease,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _detailRow(Icons.place_outlined, region),
            _detailRow(Icons.warning_amber_outlined,
                '${severity[0].toUpperCase()}${severity.substring(1)} severity'),
            _detailRow(Icons.assessment_outlined,
                '$cases case${cases == 1 ? '' : 's'}'),
            _detailRow(
              Icons.schedule_outlined,
              timestamp != null
                  ? 'Seen ${_timeAgo(timestamp)}'
                  : 'Date unknown',
            ),
            if (totalVerified > 0)
              _detailRow(Icons.verified_outlined,
                  'Confirmed by $totalVerified local farmer${totalVerified == 1 ? '' : 's'}'),
            if (totalRefuted > 0)
              _detailRow(Icons.report_problem_outlined,
                  'Flagged incorrect by $totalRefuted user${totalRefuted == 1 ? '' : 's'}'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (ctx, setSheetState) {
                if (isUserVerified) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Color(0xFF16A34A), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'You verified this outbreak',
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (isUserRefuted) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Color(0xFFDC2626), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'You flagged this outbreak',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: loading ||
                                reportId == null ||
                                currentUserId.isEmpty
                            ? null
                            : () async {
                                setSheetState(() => loading = true);
                                final res =
                                    await _communityRepo.verifyOutbreakReport(
                                  reportId: reportId,
                                  userId: currentUserId,
                                  confirm: true,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  if (res.isSuccess) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(context
                                              .l10n.outbreakVerifiedSuccess)),
                                    );
                                    unawaited(_load());
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(context
                                              .l10n.outbreakVerifyFailed)),
                                    );
                                  }
                                }
                              },
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: Text(context.l10n.outbreakConfirm,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: loading ||
                                reportId == null ||
                                currentUserId.isEmpty
                            ? null
                            : () async {
                                setSheetState(() => loading = true);
                                final res =
                                    await _communityRepo.verifyOutbreakReport(
                                  reportId: reportId,
                                  userId: currentUserId,
                                  confirm: false,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  if (res.isSuccess) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(context
                                              .l10n.outbreakFlaggedSuccess)),
                                    );
                                    unawaited(_load());
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              context.l10n.outbreakFlagFailed)),
                                    );
                                  }
                                }
                              },
                        icon: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFFDC2626)),
                              )
                            : const Icon(Icons.close, size: 16),
                        label: Text(context.l10n.outbreakFlagIncorrect,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (position != null) _mapController.move(position, 11);
                },
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(context.l10n.outbreakZoomToOutbreak),
                style:
                    OutlinedButton.styleFrom(foregroundColor: colors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tappable legend entry that doubles as a severity filter: tap to show only
  /// that severity, tap again to clear.
  Widget _legendDot(String label, String severity) {
    final selected = _severityFilter == severity;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        _severityFilter = selected ? 'All' : severity;
        _applyFilters();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _severityColor(severity),
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: context.colors.primary, width: 2)
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.muted,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.colors.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _mapTilesFailed = false;
      _tileFailureCount = 0;
      _isShowingSeedData = false;
    });
    try {
      final result = await _communityRepo.getOutbreakReports();
      if (mounted) {
        // Strip any seed entries that leaked into Firestore before this fix,
        // and filter out contributions from blocked users.
        final blockedIds = sl.isRegistered<UserBlockService>()
            ? sl<UserBlockService>().blockedUserIds
            : <String>{};

        final fetched =
            (result.isSuccess ? (result.data ?? []) : <Map<String, dynamic>>[])
                .where((r) =>
                    r['isSeed'] != true &&
                    r['source'] != 'seed' &&
                    !blockedIds.contains(r['userId'] as String? ?? ''))
                .toList();
        final useSeed = fetched.isEmpty;
        _allReports = useSeed ? _kSeedOutbreakReports : fetched;
        _isShowingSeedData = useSeed;
        setState(() {
          var aggregated = _aggregate(_filteredReports());
          if (_severityFilter != 'All') {
            aggregated =
                aggregated.where((h) => h.severity == _severityFilter).toList();
          }
          _hotspots = aggregated;
          _buildMarkers();
          _loading = false;
        });
        if (_markers.isNotEmpty && _mapReady) {
          _fitMarkers();
        }
      }
    } catch (e) {
      if (mounted) {
        _allReports = _kSeedOutbreakReports;
        _isShowingSeedData = true;
        setState(() {
          var aggregated = _aggregate(_filteredReports());
          if (_severityFilter != 'All') {
            aggregated =
                aggregated.where((h) => h.severity == _severityFilter).toList();
          }
          _hotspots = aggregated;
          _buildMarkers();
          _loading = false;
        });
      }
    }
  }

  /// Applies the active crop / severity / timeframe filters to the raw reports.
  /// Returns reports that pass the active crop/timeframe filters.
  /// Seed/demo entries are always excluded from real filter/aggregation —
  /// they only appear in full via [_allReports] when [_isShowingSeedData] is true.
  List<Map<String, dynamic>> _filteredReports() {
    final now = DateTime.now();
    return _allReports.where((r) {
      // Never mix seed data into real computations.
      if (r['isSeed'] == true || r['source'] == 'seed') {
        return _isShowingSeedData;
      }
      if (_cropFilter != 'All' &&
          _cropOfDisease(_diseaseOf(r)) != _cropFilter) {
        return false;
      }

      final dt = _dateOf(r);
      if (dt != null) {
        final diffDays = now.difference(dt).inDays;
        if (_timeframeFilter == 'Last 14 Days' && diffDays > 14) return false;
        if (_timeframeFilter == 'Last 30 Days' && diffDays > 30) return false;
      } else {
        if (_timeframeFilter != 'All Time') return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _filteredIndividualReports() {
    final filtered = _filteredReports();
    // Seed entries are included only when we are in seed-fallback mode.
    final real = _isShowingSeedData
        ? filtered
        : filtered.where((r) => r['isSeed'] != true).toList();
    if (_severityFilter == 'All') return real;
    return real.where((r) => _severityOf(r) == _severityFilter).toList();
  }

  /// Re-aggregates from the cached raw reports when a filter changes — no
  /// network round-trip.
  void _applyFilters() {
    setState(() {
      var aggregated = _aggregate(_filteredReports());
      if (_severityFilter != 'All') {
        aggregated =
            aggregated.where((h) => h.severity == _severityFilter).toList();
      }
      _hotspots = aggregated;
      _buildMarkers();
    });
    if (_mapReady && _markers.isNotEmpty) _fitMarkers();
  }

  void _fitMarkers() {
    if (!_mapReady || _markers.isEmpty) return;
    if (_markers.length == 1) {
      _mapController.move(_markers.first.point, 9);
      return;
    }
    final bounds = LatLngBounds.fromPoints(
      _markers.map((m) => m.point).toList(),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  Future<void> _showReportSheet({OutbreakReportPrefill? prefill}) async {
    if (!_auth.isSignedIn || _auth.currentUserIdOrNull == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.signInRequiredToReport),
            action: SnackBarAction(
              label: context.l10n.signIn,
              onPressed: () => context.push('/login'),
            ),
          ),
        );
      }
      return;
    }

    // Use cached user position or fast last-known position so the sheet opens immediately.
    Position? position = _userPosition;
    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    if (!mounted) return;

    // Apply prefill from a scan: pick the matching disease if it's in the
    // curated list, otherwise route it through "Other" with the name filled in.
    final prefillKnown =
        prefill != null && _kDiseases.contains(prefill.disease);
    String? selectedDisease = prefill == null
        ? _kDiseases.first
        : (prefillKnown ? prefill.disease : 'Other');
    String selectedSeverity = prefill?.severity ?? 'medium';
    final double? prefillConfidence = prefill?.confidence;
    final notesController = TextEditingController();
    final otherDiseaseController = TextEditingController(
      text: (prefill != null && !prefillKnown) ? prefill.disease : '',
    );
    String? otherDiseaseError;
    String? manualRegion;
    String? manualRegionError;

    // Background location fetch if position wasn't cached yet.
    void tryFetchLocation(void Function(void Function()) setSheetState) async {
      if (position != null) return;
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.medium),
          ).timeout(const Duration(seconds: 3));
          if (mounted) {
            _userPosition = pos;
            position = pos;
            setSheetState(() {});
          }
        }
      } catch (_) {}
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (position == null) {
            tryFetchLocation(setSheetState);
          }
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.reportDiseaseHere,
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                  const SizedBox(height: 4),
                  Text(
                    position != null
                        ? 'Location: ${position!.latitude.toStringAsFixed(4)}, '
                            '${position!.longitude.toStringAsFixed(4)}'
                        : 'Location unavailable — please select region manually.',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        fontSize: 12),
                  ),
                  if (position == null) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: manualRegion,
                      decoration: InputDecoration(
                        labelText: 'Region (Required)',
                        hintText: 'Select region where outbreak was observed',
                        border: const OutlineInputBorder(),
                        errorText: manualRegionError,
                      ),
                      items: GhanaRegion.allRegions
                          .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setSheetState(() {
                        manualRegion = v;
                        manualRegionError = null;
                      }),
                    ),
                  ],
                  if (prefillConfidence != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 16, color: context.colors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'From your scan • ${(prefillConfidence * 100).round()}% confidence',
                            style: TextStyle(
                                color: context.colors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDisease,
                    decoration: InputDecoration(
                      labelText: context.l10n.diseaseLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: _kDiseases
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => selectedDisease = v),
                  ),
                  if (selectedDisease == 'Other') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: otherDiseaseController,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: context.l10n.diseaseNameLabel,
                        hintText: context.l10n.diseaseNameHint,
                        border: const OutlineInputBorder(),
                        errorText: otherDiseaseError,
                      ),
                      onChanged: (_) {
                        if (otherDiseaseError != null) {
                          setSheetState(() => otherDiseaseError = null);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSeverity,
                    decoration: const InputDecoration(
                      labelText: 'Severity',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'low', child: Text('Low — a few plants')),
                      DropdownMenuItem(
                          value: 'medium', child: Text('Medium — spreading')),
                      DropdownMenuItem(
                          value: 'high', child: Text('High — widespread')),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => selectedSeverity = v ?? 'medium'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: notesController,
                          maxLines: 2,
                          maxLength: 200,
                          decoration: InputDecoration(
                            labelText: context.l10n.additionalNotes,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      VoiceDictationButton(controller: notesController),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _submitting
                          ? null
                          : () async {
                              // Capture messenger and l10n strings before any
                              // async gap so they remain valid even if the widget
                              // tree changes (e.g. sheet closes mid-flight).
                              final messenger = ScaffoldMessenger.of(context);
                              const signInMsg =
                                  'You must be signed in to submit a report.';
                              const signInLabel = 'Sign In';

                              final currentUserId = _auth.currentUserIdOrNull;
                              if (currentUserId == null ||
                                  currentUserId.isEmpty) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text(signInMsg),
                                    action: SnackBarAction(
                                      label: signInLabel,
                                      onPressed: () {
                                        if (mounted) context.push('/login');
                                      },
                                    ),
                                  ),
                                );
                                return;
                              }

                              final diseaseName = selectedDisease == 'Other'
                                  ? otherDiseaseController.text.trim()
                                  : selectedDisease;
                              if (diseaseName == null || diseaseName.isEmpty) {
                                setSheetState(() => otherDiseaseError =
                                    context.l10n.diseaseNameRequired);
                                return;
                              }

                              if (diseaseName.length >
                                  InputSanitizer.diseaseNameMax) {
                                setSheetState(() => otherDiseaseError =
                                    'Disease name exceeds maximum limit of ${InputSanitizer.diseaseNameMax} characters.');
                                return;
                              }

                              // Validate outbreak notes
                              final notesValidation =
                                  ContentModerationHelper.validateOutbreakNotes(
                                      notesController.text);
                              if (!notesValidation.isValid) {
                                messenger.showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          notesValidation.flaggedReason ??
                                              'Invalid notes content.')),
                                );
                                return;
                              }

                              // Rate limit outbreak report submissions: 60s cooldown, max 5 per hour
                              if (sl.isRegistered<RateLimiter>()) {
                                final rateCheck = sl<RateLimiter>().checkLimit(
                                  'outbreak_$currentUserId',
                                  cooldown: const Duration(seconds: 60),
                                  maxPerWindow: 5,
                                  windowDuration: const Duration(hours: 1),
                                );
                                if (!rateCheck.isAllowed) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                        content: Text(rateCheck.message ??
                                            'Submission rate limit reached. Please wait.')),
                                  );
                                  return;
                                }
                              }

                              if (position == null &&
                                  (manualRegion == null ||
                                      manualRegion!.isEmpty)) {
                                setSheetState(() => manualRegionError =
                                    'Please select a region for your report');
                                return;
                              }

                              // Capture all localized strings before any await.
                              final outbreakReportedMsg =
                                  context.l10n.outbreakReported;
                              final failedMsg =
                                  context.l10n.failedToSubmitReport;

                              Map<String, dynamic>? duplicate;
                              if (position != null) {
                                final now = DateTime.now();
                                for (final r in _allReports) {
                                  if (_diseaseOf(r).toLowerCase() ==
                                      diseaseName.toLowerCase()) {
                                    final lat =
                                        (r['latitude'] ?? r['lat']) as num?;
                                    final lng = (r['longitude'] ??
                                        r['lng'] ??
                                        r['lon']) as num?;
                                    final ts = _dateOf(r);
                                    if (lat != null &&
                                        lng != null &&
                                        ts != null) {
                                      final dist = Geolocator.distanceBetween(
                                        position!.latitude,
                                        position!.longitude,
                                        lat.toDouble(),
                                        lng.toDouble(),
                                      );
                                      final diffDays =
                                          now.difference(ts).inDays;
                                      if (dist <= 1000.0 && diffDays <= 7) {
                                        duplicate = r;
                                        break;
                                      }
                                    }
                                  }
                                }
                              }

                              if (duplicate != null) {
                                final duplicateId = duplicate['id'] as String?;
                                // Capture primary colour before async gap.
                                final primaryColor = context.colors.primary;
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: Text(context
                                        .l10n.outbreakNearbyDetectedTitle),
                                    content: Text(
                                      'An outbreak of $diseaseName was recently reported within 1 km of your location. '
                                      'Would you like to confirm (verify) that existing report instead of submitting a new duplicate?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, false),
                                        child: Text(
                                            context.l10n.outbreakSubmitAnyway),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, true),
                                        child: Text(context
                                            .l10n.outbreakConfirmExisting),
                                      ),
                                    ],
                                  ),
                                );

                                if (!mounted) return;

                                if (confirmed == null) {
                                  return;
                                }

                                if (confirmed == true && duplicateId != null) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  setState(() => _submitting = true);
                                  try {
                                    final res = await _communityRepo
                                        .verifyOutbreakReport(
                                      reportId: duplicateId,
                                      userId: currentUserId,
                                      confirm: true,
                                    );
                                    if (mounted) {
                                      if (res.isSuccess) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                              content: Text(context.l10n
                                                  .outbreakVerifiedSuccess)),
                                        );
                                        await _load();
                                      } else {
                                        messenger.showSnackBar(
                                          SnackBar(
                                              content: Text(res
                                                      .failure?.message ??
                                                  context.l10n
                                                      .outbreakVerifyFailed)),
                                        );
                                      }
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                            content: Text(context
                                                .l10n.outbreakVerifyFailed)),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _submitting = false);
                                    }
                                  }
                                  return;
                                }
                                // confirmed == false → submit anyway.
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!mounted) return;
                                setState(() => _submitting = true);
                              } else {
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!mounted) return;
                                setState(() => _submitting = true);
                              }

                              try {
                                final now = DateTime.now();
                                final reportRegion = position != null
                                    ? GhanaRegion.forCoordinates(
                                        position!.latitude, position!.longitude)
                                    : manualRegion!;

                                final reportPayload = <String, dynamic>{
                                  'userId': currentUserId,
                                  'disease': diseaseName,
                                  'diseaseName': diseaseName,
                                  'cropType': _cropOfDisease(diseaseName),
                                  'severity': selectedSeverity,
                                  'source': prefill != null ? 'scan' : 'manual',
                                  'reportedAt': now.toIso8601String(),
                                  'region': reportRegion,
                                  if (prefillConfidence != null)
                                    'confidence': prefillConfidence,
                                  if (position != null) ...{
                                    // Coarsen GPS coordinates to 2 decimal places (~1.1 km)
                                    // to protect exact farm boundaries and private property.
                                    'latitude': LocationHelper.coarsen(
                                        position!.latitude,
                                        precision: 2),
                                    'longitude': LocationHelper.coarsen(
                                        position!.longitude,
                                        precision: 2),
                                  },
                                  'notes': notesController.text.trim(),
                                  'timestamp': FieldValue.serverTimestamp(),
                                };

                                final res = await _communityRepo
                                    .submitOutbreakReport(reportPayload);
                                if (res.isSuccess) {
                                  try {
                                    if (sl.isRegistered<AnalyticsService>()) {
                                      unawaited(sl<AnalyticsService>()
                                          .logOutbreakReported());
                                    }
                                  } catch (_) {}
                                }
                                if (mounted) {
                                  if (res.isSuccess) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                          content: Text(outbreakReportedMsg)),
                                    );
                                    unawaited(_load());
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                          content: Text(res.failure?.message ??
                                              failedMsg)),
                                    );
                                  }
                                }
                              } catch (_) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(failedMsg)),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _submitting = false);
                                }
                              }
                            },
                      child: Text(context.l10n.submitReport,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          title: Text(context.l10n.outbreakMap,
              style: Theme.of(context).textTheme.titleLarge),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          actions: [
            IconButton(
              tooltip: _showHeatmap ? 'Hide heatmap' : 'Show heatmap',
              icon: Icon(_showHeatmap ? Icons.layers_clear : Icons.layers),
              onPressed: () => setState(() => _showHeatmap = !_showHeatmap),
            ),
            IconButton(
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _submitting ? null : _showReportSheet,
          backgroundColor: colors.diseaseRed,
          foregroundColor: Colors.white,
          icon: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.add_location_alt),
          label: Text(context.l10n.reportDiseaseHere),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: _mapTilesFailed
                  ? Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off, size: 40, color: colors.muted),
                          const SizedBox(height: 8),
                          Text(
                            'Map unavailable offline',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Using static list view below',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _mapTilesFailed = false;
                                _tileFailureCount = 0;
                              });
                              _load();
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: Text(context.l10n.outbreakRetryMap,
                                style: const TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 36),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _kGhanaCenter,
                            initialZoom: 6.5,
                            minZoom: 3,
                            maxZoom: 18,
                            onMapReady: () {
                              _mapReady = true;
                              if (_markers.isNotEmpty) _fitMarkers();
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: _kOsmTileUrl,
                              userAgentPackageName: 'com.crop.guard.app',
                              maxZoom: 19,
                              // Persistent disk cache: tiles stay available offline.
                              tileProvider: CachedTileProvider(),
                              errorTileCallback: (tile, error, stackTrace) {
                                _tileFailureCount++;
                                if (_tileFailureCount >= 3 &&
                                    !_mapTilesFailed) {
                                  setState(() {
                                    _mapTilesFailed = true;
                                  });
                                }
                              },
                            ),
                            // Risk overlay & density heatmap sit below the markers so pins stay tappable.
                            if (_showRiskOverlay)
                              CircleLayer(circles: _riskOverlayCircles()),
                            if (_showHeatmap)
                              CircleLayer(circles: _heatCircles()),
                            MarkerClusterLayerWidget(
                              options: MarkerClusterLayerOptions(
                                markers: _markers,
                                maxClusterRadius: 45,
                                size: const Size(40, 40),
                                padding: const EdgeInsets.all(48),
                                maxZoom: 15,
                                onMarkerTap: _showMarkerInfo,
                                builder: (context, markers) => Container(
                                  decoration: BoxDecoration(
                                    color: colors.diseaseRed,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${markers.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution(
                                    '© OpenStreetMap contributors'),
                              ],
                            ),
                          ],
                        ),
                        if (_loading)
                          Container(
                            color: colors.surfaceVariant.withValues(alpha: 0.7),
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.small(
                            heroTag: 'my_location_btn',
                            backgroundColor: colors.surface,
                            foregroundColor: colors.primary,
                            elevation: 3,
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final unavailableMsg =
                                  context.l10n.locationUnavailable;
                              if (_userPosition != null && _mapReady) {
                                _mapController.move(
                                  LatLng(_userPosition!.latitude,
                                      _userPosition!.longitude),
                                  12,
                                );
                              } else {
                                await _getUserLocation(requestIfMissing: true);
                                if (_userPosition != null && _mapReady) {
                                  _mapController.move(
                                    LatLng(_userPosition!.latitude,
                                        _userPosition!.longitude),
                                    12,
                                  );
                                } else if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(unavailableMsg)),
                                  );
                                }
                              }
                            },
                            child: const Icon(Icons.my_location, size: 20),
                          ),
                        ),
                      ],
                    ),
            ),
            // Severity legend.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _legendDot(context.l10n.riskLevelHigh, 'high'),
                  _legendDot(context.l10n.riskLevelModerate, 'medium'),
                  _legendDot(context.l10n.riskLevelLow, 'low'),
                ],
              ),
            ),
            // Crop filter chip bar.
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: ['All', ..._kCrops, 'Other'].map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c == 'All'
                          ? context.l10n.all
                          : (c == 'Other' ? context.l10n.diseaseOther : c)),
                      selected: _cropFilter == c,
                      onSelected: (_) {
                        if (_cropFilter == c) return;
                        _cropFilter = c;
                        _applyFilters();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            // Timeframe filter chip bar.
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: ['Last 14 Days', 'Last 30 Days', 'All Time'].map((t) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: _timeframeFilter == t,
                      onSelected: (_) {
                        if (_timeframeFilter == t) return;
                        _timeframeFilter = t;
                        _applyFilters();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            if (!_loading && _markers.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Reports without map coordinates appear in the list below.',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.l10n.recentDiseaseReports,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  DropdownButton<String>(
                    value: _sortBy,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(
                        color: colors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    items: [
                      DropdownMenuItem(
                          value: 'Most Cases',
                          child: Text(context.l10n.sortMostCases)),
                      DropdownMenuItem(
                          value: 'Most Recent',
                          child: Text(context.l10n.sortMostRecent)),
                      DropdownMenuItem(
                          value: 'Closest',
                          child: Text(context.l10n.sortClosest)),
                    ],
                    onChanged: (v) {
                      if (v != null && v != _sortBy) {
                        setState(() {
                          _sortBy = v;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  style: TextStyle(color: colors.muted)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _load,
                                child: Text(context.l10n.retry),
                              ),
                            ],
                          ),
                        )
                      : _hotspots.isEmpty
                          ? Center(
                              child: Text(
                                context.l10n.noOutbreakReports,
                                style: TextStyle(color: colors.muted),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                // Bottom inset so the last card clears the
                                // "Report Disease Here" extended FAB.
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 88),
                                itemCount: _hotspots.length +
                                    (_isShowingSeedData ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  // Banner for seed/example data — shown as the first list item.
                                  if (_isShowingSeedData && i == 0) {
                                    return Semantics(
                                      label:
                                          'Example data banner: no real outbreak reports yet',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBEB),
                                          border: Border.all(
                                              color: const Color(0xFFF59E0B)),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.info_outline,
                                                color: Color(0xFFF59E0B),
                                                size: 18),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Example data — no real reports yet. '
                                                'These are illustrative outbreaks for demonstration.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF92400E),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  final h =
                                      _hotspots[_isShowingSeedData ? i - 1 : i];
                                  final disease = h.disease;
                                  final region = h.region;
                                  final cases = h.count;
                                  final date = h.latest != null
                                      ? _timeAgo(h.latest!)
                                      : 'Unknown date';
                                  final sevColor = _severityColor(h.severity);

                                  String distanceText = '';
                                  if (_userPosition != null &&
                                      h.center != null) {
                                    final dist = Geolocator.distanceBetween(
                                          _userPosition!.latitude,
                                          _userPosition!.longitude,
                                          h.center!.latitude,
                                          h.center!.longitude,
                                        ) /
                                        1000.0;
                                    distanceText =
                                        ' • ~${LocaleFormatter.formatNumber(context, dist.round())} km away';
                                  }

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      if (h.center != null && _mapReady) {
                                        _mapController.move(h.center!, 10);
                                      }
                                    },
                                    child: CropGuardCard(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: sevColor.withValues(
                                                  alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(Icons.warning_amber,
                                                color: sevColor, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(disease,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                Text(
                                                    '$region • $date$distanceText',
                                                    style: TextStyle(
                                                        color: colors.muted,
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: colors.diseaseBg,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                                context.l10n
                                                    .reportsCount(cases),
                                                style: TextStyle(
                                                    color: colors.diseaseRed,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
