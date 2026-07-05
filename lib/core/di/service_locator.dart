import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Data sources
import '../../data/local/database_helper.dart';
import '../../data/ml/crop_disease_classifier.dart';
import '../../data/remote/firebase_auth_service.dart';
import '../../data/remote/firestore_service.dart';
import '../../data/remote/cloudinary_service.dart';
import '../../data/remote/firebase_storage_service.dart';

// Repositories
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

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (sl.isRegistered<SharedPreferences>()) return;

  // SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // 1. Data Sources (Low level)
  sl.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());
  sl.registerLazySingleton<FirebaseAuthService>(() => FirebaseAuthService());
  sl.registerLazySingleton<FirestoreService>(() => FirestoreService());
  sl.registerLazySingleton<FirebaseStorageService>(() => FirebaseStorageService());
  sl.registerLazySingleton<CloudinaryService>(() => CloudinaryService());
  sl.registerLazySingleton<CropDiseaseClassifier>(() => CropDiseaseClassifier());
  sl.registerSingleton<StreakManager>(StreakManager(prefs));
  sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
  sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
  sl.registerLazySingleton<DeepLinkService>(() => DeepLinkService());
  sl.registerLazySingleton<BiometricService>(() => BiometricService());
  // Singleton (not lazy): the router uses it as refreshListenable and reads
  // isLocked synchronously in redirect, so it must exist before the router.
  sl.registerSingleton<AppLockController>(AppLockController(prefs));

  // 2. Repositories (Implementation details)
  sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl(sl<FirebaseAuthService>()));
  sl.registerLazySingleton<IDetectionRepository>(() => DetectionRepositoryImpl(sl<DatabaseHelper>()));
  sl.registerLazySingleton<ICommunityRepository>(() => CommunityRepositoryImpl(sl<FirestoreService>(), sl<DatabaseHelper>()));
  sl.registerLazySingleton<IClassifierRepository>(() => ClassifierRepositoryImpl(sl<CropDiseaseClassifier>()));
  sl.registerLazySingleton<IProfileRepository>(() => ProfileRepositoryImpl(sl<FirebaseAuthService>(), sl<DatabaseHelper>(), sl<SharedPreferences>()));
  sl.registerLazySingleton<IWeatherRepository>(() => WeatherRepositoryImpl());

  // 3. Use Cases (Business logic)
  sl.registerLazySingleton<LoginUseCase>(() => LoginUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<RegisterUseCase>(() => RegisterUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<LogoutUseCase>(() => LogoutUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<SignInWithGoogleUseCase>(() => SignInWithGoogleUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<SignInAnonymouslyUseCase>(() => SignInAnonymouslyUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<SendPasswordResetUseCase>(() => SendPasswordResetUseCase(sl<IAuthRepository>()));
  sl.registerLazySingleton<GetHistoryUseCase>(() => GetHistoryUseCase(sl<IDetectionRepository>()));
  sl.registerLazySingleton<DeleteDetectionUseCase>(() => DeleteDetectionUseCase(sl<IDetectionRepository>()));
  sl.registerLazySingleton<RestoreDetectionUseCase>(() => RestoreDetectionUseCase(sl<IDetectionRepository>()));
  sl.registerLazySingleton<GetHomeDataUseCase>(() => GetHomeDataUseCase(sl<IDetectionRepository>()));
  sl.registerLazySingleton<ScanCropUseCase>(() => ScanCropUseCase(
    sl<IClassifierRepository>(),
    sl<IDetectionRepository>(),
    sl<StreakManager>(),
  ));
  sl.registerLazySingleton<GetWeatherUseCase>(() => GetWeatherUseCase(sl<IWeatherRepository>()));

  // Wire offline → online drain: whenever connectivity is restored, replay
  // any community/feedback operations that were queued while offline.
  sl<ConnectivityService>().statusStream.listen((status) {
    if (status == ConnectionStatus.online) {
      final repo = sl<ICommunityRepository>();
      if (repo is CommunityRepositoryImpl) {
        repo.drainPendingSync();
      }
    }
  });
}

/// Builds the list of top-level providers so they're accessible anywhere
List<SingleChildWidget> buildProviders() {
  return [
    ChangeNotifierProvider(create: (_) => LoginProvider(
      sl<LoginUseCase>(),
      sl<SignInWithGoogleUseCase>(),
      sl<SignInAnonymouslyUseCase>(),
      sl<DatabaseHelper>(),
      sl<FirebaseAuthService>(),
      sl<AnalyticsService>(),
    )),
    ChangeNotifierProvider(create: (_) => RegisterProvider(
      sl<RegisterUseCase>(),
      sl<DatabaseHelper>(),
      sl<FirebaseAuthService>(),
    )),
    ChangeNotifierProvider(create: (_) => HomeProvider(
      sl<GetHomeDataUseCase>(),
      sl<GetWeatherUseCase>(),
      sl<IAuthRepository>(),
      sl<SharedPreferences>(),
      sl<ConnectivityService>(),
      sl<ICommunityRepository>(),
    )),
    ChangeNotifierProvider(create: (_) => HistoryProvider(
      sl<GetHistoryUseCase>(),
      sl<DeleteDetectionUseCase>(),
      sl<RestoreDetectionUseCase>(),
    )),
    ChangeNotifierProvider(create: (_) => ProfileProvider(sl<IProfileRepository>(), sl<IAuthRepository>(), sl<ConnectivityService>(), sl<CloudinaryService>())),
    ChangeNotifierProvider(create: (_) => ScannerProvider(sl<ScanCropUseCase>(), sl<IAuthRepository>(), sl<AnalyticsService>())),
    // ResultProvider and CommunityProvider are intentionally absent here.
    // They are provided at route level in AppRouter so they are created only
    // when the screen is navigated to and disposed when it is popped.
    ChangeNotifierProvider(create: (_) => SettingsProvider(sl<SharedPreferences>(), sl<FirebaseAuthService>(), sl<DatabaseHelper>(), sl<AnalyticsService>(), sl<BiometricService>(), sl<AppLockController>())),
    ChangeNotifierProvider(create: (_) => BatchResultProvider()),
    // TreatmentTrackerProvider is provided at route level in AppRouter so it
    // is created only when /treatment_tracker is navigated to and disposed
    // when the screen is popped.
  ];
}


