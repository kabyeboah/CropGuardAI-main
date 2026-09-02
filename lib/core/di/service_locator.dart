import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Data sources
import '../../data/local/database_helper.dart';
import '../../data/remote/supabase_auth_service.dart';
import '../../data/remote/supabase_database_service.dart';
import '../../data/remote/supabase_storage_service.dart';
import '../../data/remote/cloud_functions_service.dart';
import '../../data/remote/cloudinary_service.dart';
import '../../data/remote/image_upload_service.dart';
import '../../data/remote/gemini_cloud_ai_service.dart';
import '../../data/remote/ghana_nlp_service.dart';

// Repositories
import '../../data/ml/crop_disease_classifier.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/classifier_repository_impl.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../data/repositories/detection_repository_impl.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_classifier_repository.dart';
import '../../domain/repositories/i_community_repository.dart';
import '../../domain/repositories/i_detection_repository.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../data/repositories/weather_repository_impl.dart';
import '../../domain/repositories/i_weather_repository.dart';
import '../../data/repositories/risk_repository_impl.dart';
import '../../domain/repositories/i_risk_repository.dart';

// Use Cases
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../domain/usecases/auth/register_usecase.dart';
import '../../domain/usecases/auth/signin_with_google_usecase.dart';
import '../../domain/usecases/auth/signin_anonymously_usecase.dart';
import '../../domain/usecases/auth/send_password_reset_usecase.dart';
import '../../domain/usecases/history/get_history_usecase.dart';
import '../../domain/usecases/history/delete_detection_usecase.dart';
import '../../domain/usecases/history/restore_detection_usecase.dart';
import '../../domain/usecases/home/get_home_data_usecase.dart';
import '../../domain/usecases/risk/get_risk_assessment_usecase.dart';
import '../../domain/usecases/scanner/scan_crop_usecase.dart';
import '../../domain/usecases/weather/get_weather_usecase.dart';

// Providers
import '../../presentation/screens/home/home_provider.dart';
import '../../presentation/screens/login/login_provider.dart';
import '../../presentation/screens/register/register_provider.dart';
import '../../presentation/screens/history/history_provider.dart';
import '../../presentation/screens/profile/profile_provider.dart';
import '../../presentation/screens/scanner/scanner_provider.dart';
import '../../presentation/screens/settings/settings_provider.dart';
import '../../presentation/screens/result/batch_result_provider.dart';
import '../utils/streak_manager.dart';
import '../utils/connectivity_service.dart';
import '../utils/analytics_service.dart';
import '../utils/deep_link_service.dart';
import '../utils/biometric_service.dart';
import '../utils/app_lock_controller.dart';
import '../utils/auth_state_notifier.dart';
import '../utils/classifier_health_service.dart';
import '../utils/push_notification_service.dart';
import '../utils/nominatim_service.dart';
import '../utils/user_block_service.dart';
import '../utils/rate_limiter.dart';
import '../../domain/usecases/scanner/scan_batch_usecase.dart';

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (sl.isRegistered<SharedPreferences>()) return;

  // SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // 1. Data Sources (Low level)
  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());
  sl.registerLazySingleton<SupabaseAuthService>(() => SupabaseAuthService());
  sl.registerLazySingleton<SupabaseDatabaseService>(() => SupabaseDatabaseService());
  sl.registerLazySingleton<SupabaseStorageService>(() => SupabaseStorageService());
  sl.registerLazySingleton<CloudFunctionsService>(
      () => CloudFunctionsService());
  sl.registerLazySingleton<CloudinaryService>(() => CloudinaryService());
  sl.registerLazySingleton<ImageUploadService>(() => ImageUploadService(
      sl<CloudinaryService>(), sl<SupabaseStorageService>()));
  sl.registerLazySingleton<GeminiCloudAiService>(
      () => GeminiCloudAiService(functions: sl<CloudFunctionsService>()));
  GhanaNlpService(functions: sl<CloudFunctionsService>());
  sl.registerSingleton<StreakManager>(StreakManager(prefs));
  sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
  sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  sl.registerLazySingleton<DeepLinkService>(() => DeepLinkService());
  sl.registerLazySingleton<BiometricService>(() => BiometricService());
  sl.registerLazySingleton<NominatimService>(
      () => NominatimService(prefs: prefs));
  sl.registerSingleton<ClassifierHealthService>(ClassifierHealthService());
  sl.registerSingleton<AuthStateNotifier>(AuthStateNotifier());
  sl.registerSingleton<UserBlockService>(UserBlockService(prefs));
  sl.registerLazySingleton<RateLimiter>(() => RateLimiter());
  // Singleton (not lazy): the router uses it as refreshListenable and reads
  // isLocked synchronously in redirect, so it must exist before the router.
  sl.registerSingleton<AppLockController>(
      AppLockController(prefs, analytics: sl<AnalyticsService>()));

  // 2. Repositories (Implementation details)
  sl.registerLazySingleton<IAuthRepository>(
      () => AuthRepositoryImpl(sl<SupabaseAuthService>()));
  sl.registerLazySingleton<IDetectionRepository>(
      () => DetectionRepositoryImpl(sl<DatabaseHelper>()));
  sl.registerLazySingleton<ICommunityRepository>(() => CommunityRepositoryImpl(
        sl<SupabaseDatabaseService>(),
        sl<DatabaseHelper>(),
        sl<ImageUploadService>(),
      ));
  sl.registerLazySingleton<IClassifierRepository>(
      () => ClassifierRepositoryImpl(CropDiseaseClassifier()));
  sl.registerLazySingleton<IProfileRepository>(() => ProfileRepositoryImpl(
        sl<SupabaseAuthService>(),
        sl<DatabaseHelper>(),
        sl<SharedPreferences>(),
      ));
  sl.registerLazySingleton<IWeatherRepository>(() => WeatherRepositoryImpl());
  sl.registerLazySingleton<IRiskRepository>(() => RiskRepositoryImpl(
        sl<ICommunityRepository>(),
        sl<IWeatherRepository>(),
      ));

  // 3. Use Cases (Business logic)
  sl.registerLazySingleton<LoginUseCase>(
      () => LoginUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<RegisterUseCase>(
      () => RegisterUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<LogoutUseCase>(
      () => LogoutUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<SignInWithGoogleUseCase>(
      () => SignInWithGoogleUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<SignInAnonymouslyUseCase>(
      () => SignInAnonymouslyUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<SendPasswordResetUseCase>(
      () => SendPasswordResetUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<GetHistoryUseCase>(
      () => GetHistoryUseCase(sl<IDetectionRepository>()));
  sl.registerLazySingleton<DeleteDetectionUseCase>(
      () => DeleteDetectionUseCase(sl<IDetectionRepository>()));
  sl.registerLazySingleton<RestoreDetectionUseCase>(
      () => RestoreDetectionUseCase(sl<IDetectionRepository>()));
  sl.registerLazySingleton<GetHomeDataUseCase>(
      () => GetHomeDataUseCase(sl<IDetectionRepository>()));
  sl.registerLazySingleton<ScanCropUseCase>(() => ScanCropUseCase(
        sl<IClassifierRepository>(),
        sl<IDetectionRepository>(),
        sl<StreakManager>(),
        sl<ICommunityRepository>(),
      ));
  sl.registerLazySingleton<ScanBatchUseCase>(
      () => ScanBatchUseCase(sl<ScanCropUseCase>()));
  sl.registerLazySingleton<GetWeatherUseCase>(
      () => GetWeatherUseCase(sl<IWeatherRepository>()));
  sl.registerLazySingleton<GetRiskAssessmentUseCase>(
      () => GetRiskAssessmentUseCase(sl<IRiskRepository>()));

  // Wire offline → online drain: whenever connectivity is restored, replay
  // any community/feedback operations that were queued while offline.
  sl<ConnectivityService>().statusStream.listen((status) {
    if (status == ConnectionStatus.online || status == ConnectionStatus.poor) {
      final repo = sl<ICommunityRepository>();
      if (repo is CommunityRepositoryImpl) {
        repo.drainPendingSync();
      }
    }
  });

  // Re-sync FCM push token whenever a user logs in / registers / restores auth state.
  sl<IAuthRepository>().authStateChanges.listen((user) {
    if (user != null) {
      PushNotificationService.syncFcmToken(user.id);
    }
  });
}

/// Builds the list of top-level providers so they're accessible anywhere
List<SingleChildWidget> buildProviders() {
  return [
    ChangeNotifierProvider(
        create: (_) => LoginProvider(
              sl<LoginUseCase>(),
              sl<SignInWithGoogleUseCase>(),
              sl<SignInAnonymouslyUseCase>(),
              sl<DatabaseHelper>(),
              sl<SupabaseAuthService>(),
              sl<AnalyticsService>(),
            )),
    ChangeNotifierProvider(
        create: (_) => RegisterProvider(
              sl<RegisterUseCase>(),
              sl<DatabaseHelper>(),
              sl<SupabaseAuthService>(),
              sl<SignInWithGoogleUseCase>(),
              sl<AnalyticsService>(),
            )),
    ChangeNotifierProvider(
        create: (_) => HomeProvider(
              sl<GetHomeDataUseCase>(),
              sl<GetWeatherUseCase>(),
              sl<IAuthRepository>(),
              sl<SharedPreferences>(),
              sl<ConnectivityService>(),
              sl<ICommunityRepository>(),
              nominatimService: sl<NominatimService>(),
            )),
    ChangeNotifierProvider(
        create: (_) => HistoryProvider(
              sl<GetHistoryUseCase>(),
              sl<DeleteDetectionUseCase>(),
              sl<RestoreDetectionUseCase>(),
              sl<IAuthRepository>(),
            )),
    ChangeNotifierProvider(
        create: (_) => ProfileProvider(
            sl<IProfileRepository>(),
            sl<IAuthRepository>(),
            sl<ConnectivityService>(),
            sl<ImageUploadService>())),
    ChangeNotifierProvider(
        create: (_) => ScannerProvider(sl<ScanCropUseCase>(),
            sl<IAuthRepository>(), sl<AnalyticsService>())),
    ChangeNotifierProvider(
        create: (_) => SettingsProvider(
            sl<SharedPreferences>(),
            sl<SupabaseAuthService>(),
            sl<DatabaseHelper>(),
            sl<AnalyticsService>(),
            sl<BiometricService>(),
            sl<AppLockController>())),
    ChangeNotifierProvider(create: (_) => BatchResultProvider()),
  ];
}
