import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/connectivity_service.dart';
import '../../../core/utils/ghana_region.dart';
import '../../../core/utils/ghana_seasonal_tip.dart';
import '../../../core/utils/outbreak_alert_service.dart';
import '../../../core/utils/planting_reminder_manager.dart';
import '../../../domain/models/detection_result.dart';
import '../../../domain/repositories/i_auth_repository.dart';
import '../../../domain/repositories/i_community_repository.dart';
import '../../../domain/usecases/home/get_home_data_usecase.dart';
import '../../../domain/usecases/weather/get_weather_usecase.dart';
import '../../../domain/models/weather_forecast.dart';
import '../../../domain/models/disease_risk.dart';
import '../../../core/utils/agri_weather_utils.dart';

class FarmStats {
  final int totalScans;
  final int healthyScans;
  final int diseasedScans;

  const FarmStats({
    this.totalScans = 0,
    this.healthyScans = 0,
    this.diseasedScans = 0,
  });

  double get healthScore =>
      totalScans > 0 ? healthyScans / totalScans : 0.0;
}

class HomeProvider extends ChangeNotifier with WidgetsBindingObserver {
  final GetHomeDataUseCase _getHomeDataUseCase;
  final GetWeatherUseCase _getWeatherUseCase;
  final IAuthRepository _authRepository;
  final ConnectivityService _connectivity;
  final SharedPreferences _prefs;
  final ICommunityRepository _communityRepository;
  StreamSubscription<ConnectionStatus>? _connectivitySub;
  Timer? _weatherTimer;
  bool _disposed = false;

  // SharedPreferences keys for the weather cache.
  static const _kCacheJson = 'weather_v1_json';
  static const _kCacheTs   = 'weather_v1_ts';

  // Stale threshold — refresh when cached data is older than this.
  static const _cacheTTL = Duration(minutes: 30);

  HomeProvider(
    this._getHomeDataUseCase,
    this._getWeatherUseCase,
    this._authRepository,
    SharedPreferences prefs,
    this._connectivity,
    this._communityRepository,
  ) : _prefs = prefs {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = _connectivity.statusStream.listen((status) {
      connectionStatus = status;
      notifyListeners();
    });
    _connectivity.checkStatus().then((status) {
      connectionStatus = status;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _weatherTimer?.cancel();
    super.dispose();
  }

  // Refresh weather and farm data when the app returns to the foreground, so
  // changes made elsewhere (e.g. deleting a scan in History) aren't stale.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWeatherIfStale();
      refreshData();
    }
  }

  // ── State ──────────────────────────────────────────────────────────────────

  FarmStats stats = const FarmStats();
  List<DetectionResult> recentScans = [];
  bool isLoading = true;
  bool hasError = false;
  ConnectionStatus connectionStatus = ConnectionStatus.online;
  bool get isOffline => connectionStatus == ConnectionStatus.offline;
  bool isHighRisk = false;
  String seasonalAlert = '';
  String dailyTip = '';
  List<Map<String, dynamic>> trend = [];

  List<Map<String, dynamic>> _outbreaks = [];

  WeatherForecast? weather;
  bool isWeatherLoading = false;
  String? weatherError;
  bool hasDiseaseRisk = false;
  String diseaseRiskMessage = '';
  List<DiseaseRisk> weeklyRisks = [];
  String plantingStatus = '';
  String plantingAction = '';
  String locationName = 'Ghana';

  List<PlantingCrop> myCrops = [];

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    isLoading = true;
    hasError = false;
    notifyListeners();

    final userId = _authRepository.currentUser?.id;
    final result = await _getHomeDataUseCase(userId: userId);

    if (result.isSuccess) {
      final data = result.data!;
      stats = FarmStats(
        totalScans: data.stats['total'] ?? 0,
        healthyScans: data.stats['healthy'] ?? 0,
        diseasedScans: data.stats['diseased'] ?? 0,
      );
      recentScans = data.recentScans;
      trend = data.trend;
    } else {
      hasError = true;
    }

    try {
      final outbreaksResult = await _communityRepository.getOutbreakReports();
      if (outbreaksResult.isSuccess) {
        _outbreaks = outbreaksResult.data ?? [];
      }
    } catch (_) {
      // Robust fallback
    }

    isHighRisk = GhanaSeasonalTip.isHighRisk();
    seasonalAlert = GhanaSeasonalTip.getAlertMessage();

    final tipIdx = GhanaSeasonalTip.getDailyTipIndex(dailyTips.length);
    dailyTip = dailyTips[tipIdx];

    isLoading = false;

    // Show cached weather immediately so the UI is never blank.
    _showCachedWeather();
    notifyListeners();

    // Always attempt a live fetch: if cache is fresh it returns early,
    // otherwise it fetches and updates the UI in the background.
    if (!hasError) unawaited(_fetchWeatherAtCurrentLocation());

    // Ensure the periodic refresh is running even when the launch cache was
    // fresh (in which case _fetchWeather — which normally starts it — is
    // skipped). _startWeatherTimer cancels any existing timer, so it's safe to
    // call again later from _fetchWeather.
    _startWeatherTimer();

    myCrops = await PlantingReminderManager.loadCrops(_prefs);
    notifyListeners();
  }

  /// Re-fetch stats + recent scans + trend without toggling the loading
  /// spinner. Used on resume / when returning to Home so data stays fresh.
  Future<void> refreshData() async {
    final userId = _authRepository.currentUser?.id;
    final result = await _getHomeDataUseCase(userId: userId);
    
    try {
      final outbreaksResult = await _communityRepository.getOutbreakReports();
      if (outbreaksResult.isSuccess) {
        _outbreaks = outbreaksResult.data ?? [];
      }
    } catch (_) {}

    if (_disposed) return;
    if (result.isSuccess) {
      final data = result.data!;
      stats = FarmStats(
        totalScans: data.stats['total'] ?? 0,
        healthyScans: data.stats['healthy'] ?? 0,
        diseasedScans: data.stats['diseased'] ?? 0,
      );
      recentScans = data.recentScans;
      trend = data.trend;
      if (weather != null) {
        final region = weather!.latitude > 8.0 ? 'North' : 'South';
        _updateDerivedWeatherFields(weather!, region);
      }
      notifyListeners();
    }
  }

  Future<void> retry() => load();
  Future<void> refresh() => load();

  Future<void> addMyCrop(PlantingCrop crop) async {
    myCrops = [...myCrops, crop];
    await PlantingReminderManager.saveCrops(_prefs, myCrops);
    await PlantingReminderManager.scheduleReminders(crop);
    notifyListeners();
  }

  Future<void> removeMyCrop(String cropId) async {
    myCrops = myCrops.where((c) => c.id != cropId).toList();
    await PlantingReminderManager.saveCrops(_prefs, myCrops);
    notifyListeners();
  }

  // ── Weather cache helpers ──────────────────────────────────────────────────

  // Populate [weather] from SharedPreferences without a network call.
  // Always shows cached data if present (even stale) so the UI is never blank;
  // the background live fetch will overwrite it when it completes.
  void _showCachedWeather() {
    final jsonStr = _prefs.getString(_kCacheJson);
    if (jsonStr == null) return;
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final cached  = WeatherForecast.fromJson(decoded);
      final region  = cached.latitude > 8.0 ? 'North' : 'South';
      weather = cached;
      _updateDerivedWeatherFields(cached, region);
    } catch (_) {
      // Corrupt cache — ignore; live fetch will overwrite it.
    }
  }

  void _saveCachedWeather(WeatherForecast w) {
    _prefs.setString(_kCacheJson, jsonEncode(w.toJson()));
    _prefs.setInt(_kCacheTs, DateTime.now().millisecondsSinceEpoch);
  }

  // Returns true when the cached data is still fresh enough to skip a fetch.
  bool _isCacheFresh() {
    final ts  = _prefs.getInt(_kCacheTs) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    return age < _cacheTTL.inMilliseconds;
  }

  // Triggered by the 30-min timer and app-resume lifecycle event.
  void _refreshWeatherIfStale() {
    if (!_isCacheFresh()) _fetchWeatherAtCurrentLocation();
  }

  void _startWeatherTimer() {
    _weatherTimer?.cancel();
    _weatherTimer = Timer.periodic(_cacheTTL, (_) => _refreshWeatherIfStale());
  }

  // Compute hasDiseaseRisk / diseaseRiskMessage / plantingStatus from a
  // WeatherForecast so the logic can be reused for both live and cached data.
  void _updateDerivedWeatherFields(WeatherForecast w, String region) {
    if (w.daily.isEmpty) return;
    final today = w.daily.first;
    weeklyRisks = AgriWeatherUtils.assessWeeklyRisks(w.daily, outbreaks: _outbreaks, region: region);
    hasDiseaseRisk = AgriWeatherUtils.isFungalRisk(today);
    if (hasDiseaseRisk) {
      diseaseRiskMessage =
          'Humidity ${today.humidity.toInt()}% and ${today.maxTemp.toInt()}°C '
          'favour fungal disease. Inspect crops today.';
    } else {
      diseaseRiskMessage = '';
    }
    final advice = AgriWeatherUtils.getPlantingAdvice(region);
    plantingStatus = advice['status'] ?? '';
    plantingAction = advice['action'] ?? '';
  }

  // ── Location + fetch ───────────────────────────────────────────────────────

  static const double _kumasiLat = 6.6666;
  static const double _kumasiLon = -1.6163;

  Future<void> _fetchWeatherAtCurrentLocation() async {
    // Skip the network round-trip when cached data is still fresh.
    if (_isCacheFresh() && weather != null) return;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _fetchFallbackWeather();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 6));

      // Cache the fix so the background outbreak-alert task has a location to
      // compare reports against without its own GPS acquisition.
      unawaited(OutbreakAlertService.saveLastKnownLocation(
          _prefs, position.latitude, position.longitude));

      final region = position.latitude > 8.0 ? 'North' : 'South';
      unawaited(_reverseGeocode(position.latitude, position.longitude));
      await _fetchWeather(position.latitude, position.longitude, region);
    } catch (_) {
      await _fetchFallbackWeather();
    }
  }

  /// Falls back to the user's saved region from onboarding, or Kumasi if none.
  Future<void> _fetchFallbackWeather() async {
    final savedRegion = _prefs.getString('user_region');
    if (savedRegion != null &&
        GhanaRegion.regionCentroid(savedRegion) != null) {
      final (lat, lon) = GhanaRegion.regionCentroid(savedRegion)!;
      locationName = '$savedRegion, Ghana';
      final regionBucket = lat > 8.0 ? 'North' : 'South';
      await _fetchWeather(lat, lon, regionBucket);
    } else {
      locationName = 'Kumasi, Ghana';
      await _fetchWeather(_kumasiLat, _kumasiLon, 'South');
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
      );
      final response = await http.get(uri, headers: {
        // Nominatim's usage policy requires an identifying User-Agent with a
        // contact. Use a project address, not a personal email. Update this to
        // your real support contact before release.
        'User-Agent': 'CropGuardAI/1.0 (kwameyeboah@gmail.com)',
      }).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body) as Map<String, dynamic>;
        final address = (data['address'] as Map<String, dynamic>?) ?? {};
        locationName  = address['county'] as String? ??
            address['city']    as String? ??
            address['town']    as String? ??
            address['village'] as String? ??
            'Ghana';
        if (!_disposed) notifyListeners();
      }
    } catch (_) {
      // Keep existing locationName.
    }
  }

  Future<void> _fetchWeather(double lat, double lon, String region) async {
    if (_disposed) return;
    isWeatherLoading = true;
    weatherError = null;
    notifyListeners();

    try {
      final fetched = await _getWeatherUseCase.execute(latitude: lat, longitude: lon);
      if (_disposed) return;
      weather = fetched;
      _updateDerivedWeatherFields(fetched, region);
      _saveCachedWeather(fetched);
    } catch (e) {
      if (!_disposed) weatherError = e.toString();
    } finally {
      // Always start the timer — even on failure so retries keep firing.
      // Guards ensure we never touch a disposed provider.
      if (!_disposed) {
        isWeatherLoading = false;
        _startWeatherTimer();
        notifyListeners();
      }
    }
  }
}
