import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cropguard_flutter/core/utils/result.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/core/utils/connectivity_service.dart';
import 'package:cropguard_flutter/domain/models/app_user.dart';
import 'package:cropguard_flutter/domain/models/weather_forecast.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/domain/repositories/i_community_repository.dart';
import 'package:cropguard_flutter/domain/usecases/home/get_home_data_usecase.dart';
import 'package:cropguard_flutter/domain/usecases/weather/get_weather_usecase.dart';
import 'package:cropguard_flutter/presentation/screens/home/home_provider.dart';

class _MockGetHomeDataUseCase extends Mock implements GetHomeDataUseCase {}
class _MockGetWeatherUseCase extends Mock implements GetWeatherUseCase {}
class _MockAuthRepo extends Mock implements IAuthRepository {}
class _MockConnectivity extends Mock implements ConnectivityService {}
class _MockCommunityRepo extends Mock implements ICommunityRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockGetHomeDataUseCase mockGetHomeData;
  late _MockGetWeatherUseCase mockGetWeather;
  late _MockAuthRepo mockAuthRepo;
  late _MockConnectivity mockConnectivity;
  late _MockCommunityRepo mockCommunity;
  late SharedPreferences prefs;
  late HomeProvider provider;

  setUp(() async {
    mockGetHomeData = _MockGetHomeDataUseCase();
    mockGetWeather = _MockGetWeatherUseCase();
    mockAuthRepo = _MockAuthRepo();
    mockConnectivity = _MockConnectivity();
    mockCommunity = _MockCommunityRepo();

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    when(() => mockConnectivity.statusStream).thenAnswer((_) => Stream.value(ConnectionStatus.online));
    when(() => mockConnectivity.checkStatus()).thenAnswer((_) async => ConnectionStatus.online);
    when(() => mockAuthRepo.currentUser).thenReturn(AppUser(id: 'user_1', email: 'e@mail.com', displayName: 'Farmer', isAnonymous: false));

    when(() => mockGetHomeData(userId: any(named: 'userId'))).thenAnswer(
      (_) async => Result.success(HomeData(
        stats: {'total': 10, 'healthy': 8, 'diseased': 2},
        recentScans: [],
        trend: [],
      )),
    );

    when(() => mockCommunity.getOutbreakReports()).thenAnswer((_) async => Result.success([]));

    when(() => mockGetWeather.execute(latitude: any(named: 'latitude'), longitude: any(named: 'longitude'))).thenAnswer(
      (_) async => WeatherForecast(
        latitude: 6.6,
        longitude: -1.6,
        daily: [
          DailyForecast(
            date: DateTime.now(),
            maxTemp: 31.0,
            minTemp: 23.0,
            precipitationProbability: 10.0,
            humidity: 60.0,
            weatherCode: 1,
          )
        ],
      ),
    );

    provider = HomeProvider(
      mockGetHomeData,
      mockGetWeather,
      mockAuthRepo,
      prefs,
      mockConnectivity,
      mockCommunity,
    );
  });

  group('HomeProvider - data loading', () {
    test('load sets statistics, tip, and status', () async {
      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(provider.hasError, isFalse);
      expect(provider.stats.totalScans, 10);
      expect(provider.stats.healthyScans, 8);
      expect(provider.stats.diseasedScans, 2);
      expect(provider.stats.healthScore, 0.8);
      expect(provider.dailyTip, isNotEmpty);
    });

    test('sets hasError to true on failure', () async {
      when(() => mockGetHomeData(userId: any(named: 'userId'))).thenAnswer(
        (_) async => Result.error(const ServerFailure('Fail')),
      );

      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(provider.hasError, isTrue);
    });
  });
}
