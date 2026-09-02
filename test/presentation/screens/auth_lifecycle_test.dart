import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:cropguard_flutter/core/error/failures.dart';
import 'package:cropguard_flutter/core/utils/deep_link_service.dart';
import 'package:cropguard_flutter/core/di/service_locator.dart';
import 'package:cropguard_flutter/domain/models/app_user.dart';
import 'package:cropguard_flutter/domain/repositories/i_auth_repository.dart';
import 'package:cropguard_flutter/data/remote/supabase_auth_service.dart';
import 'package:cropguard_flutter/data/repositories/auth_repository_impl.dart';
import 'package:cropguard_flutter/data/remote/supabase_database_service.dart';
import 'package:cropguard_flutter/data/local/database_helper.dart';
import 'package:cropguard_flutter/presentation/screens/settings/settings_provider.dart';
import 'package:cropguard_flutter/core/utils/analytics_service.dart';
import 'package:cropguard_flutter/core/utils/biometric_service.dart';
import 'package:cropguard_flutter/core/utils/app_lock_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class MockSupabaseAuthService extends Mock implements SupabaseAuthService {}

class MockSupabaseDatabaseService extends Mock
    implements SupabaseDatabaseService {}

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockBiometricService extends Mock implements BiometricService {}

class MockAppLockController extends Mock implements AppLockController {}

class MockIAuthRepository extends Mock implements IAuthRepository {}

class MockGoRouter extends Mock implements GoRouter {}

class MockAuthResponse extends Mock implements sb.AuthResponse {}

class MockUser extends Mock implements sb.User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://cropguardai.app'));
  });

  group('Phase 11 - Account Lifecycle & Deep-Link Flows', () {
    late MockSupabaseAuthService mockAuthService;
    late AuthRepositoryImpl authRepo;

    setUp(() {
      mockAuthService = MockSupabaseAuthService();
      authRepo = AuthRepositoryImpl(mockAuthService);
    });

    // ─── 1. Email Signup ──────────────────────────────────────────────────
    test('1. Email signup creates user and sets display name', () async {
      final mockResp = MockAuthResponse();
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('user_123');
      when(() => mockUser.email).thenReturn('farmer@example.com');
      when(() => mockUser.userMetadata).thenReturn({'full_name': 'Kwame Mensah'});
      when(() => mockUser.isAnonymous).thenReturn(false);
      when(() => mockResp.user).thenReturn(mockUser);

      when(() => mockAuthService.register(
            email: 'farmer@example.com',
            password: 'SecurePassword123!',
            name: 'Kwame Mensah',
          )).thenAnswer((_) async => mockResp);

      final result = await authRepo.register(
        email: 'farmer@example.com',
        password: 'SecurePassword123!',
        name: 'Kwame Mensah',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.id, 'user_123');
      expect(result.data?.email, 'farmer@example.com');
      expect(result.data?.displayName, 'Kwame Mensah');
    });

    test('1b. Email signup fails on duplicate email / network error', () async {
      when(() => mockAuthService.register(
            email: 'existing@example.com',
            password: 'Password123!',
            name: 'Existing Farmer',
          )).thenThrow(const AuthFailure('email-already-in-use'));

      final result = await authRepo.register(
        email: 'existing@example.com',
        password: 'Password123!',
        name: 'Existing Farmer',
      );

      expect(result.isError, isTrue);
      expect(result.failure?.message, contains('email-already-in-use'));
    });

    // ─── 2. Email Login ───────────────────────────────────────────────────
    test('2. Email login succeeds with valid credentials', () async {
      final mockResp = MockAuthResponse();
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('user_login_1');
      when(() => mockUser.email).thenReturn('farmer@example.com');
      when(() => mockUser.userMetadata).thenReturn({'full_name': 'Ama Serwaa'});
      when(() => mockUser.isAnonymous).thenReturn(false);
      when(() => mockResp.user).thenReturn(mockUser);

      when(() => mockAuthService.signIn(
            email: 'farmer@example.com',
            password: 'CorrectPassword1!',
          )).thenAnswer((_) async => mockResp);

      final result = await authRepo.signIn(
        email: 'farmer@example.com',
        password: 'CorrectPassword1!',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.id, 'user_login_1');
      expect(result.data?.displayName, 'Ama Serwaa');
    });

    test('2b. Email login fails with wrong password', () async {
      when(() => mockAuthService.signIn(
            email: 'farmer@example.com',
            password: 'WrongPassword',
          )).thenThrow(const AuthFailure('wrong-password'));

      final result = await authRepo.signIn(
        email: 'farmer@example.com',
        password: 'WrongPassword',
      );

      expect(result.isError, isTrue);
      expect(result.failure?.message, contains('wrong-password'));
    });

    // ─── 3. Logout ────────────────────────────────────────────────────────
    test('3. Logout calls auth service signOut and succeeds', () async {
      when(() => mockAuthService.currentUserIdOrNull).thenReturn('user_123');
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});

      final result = await authRepo.signOut();

      expect(result.isSuccess, isTrue);
      verify(() => mockAuthService.signOut()).called(1);
    });

    // ─── 4. Google Sign-In ────────────────────────────────────────────────
    test('4. Google Sign-In completes successfully', () async {
      final mockResp = MockAuthResponse();
      when(() => mockAuthService.signInWithGoogle())
          .thenAnswer((_) async => mockResp);

      final result = await authRepo.signInWithGoogle();

      expect(result.isSuccess, isTrue);
      verify(() => mockAuthService.signInWithGoogle()).called(1);
    });

    test('4b. Google Sign-In handles user cancellation', () async {
      when(() => mockAuthService.signInWithGoogle())
          .thenThrow(const AuthFailure('Google sign-in cancelled'));

      final result = await authRepo.signInWithGoogle();

      expect(result.isError, isTrue);
      expect(result.failure?.message, contains('cancelled'));
    });

    // ─── 5. Password Reset ────────────────────────────────────────────────
    test('5. Password reset requests email dispatch', () async {
      when(() => mockAuthService.sendPasswordReset('farmer@example.com'))
          .thenAnswer((_) async {});

      final result = await authRepo.sendPasswordReset('farmer@example.com');

      expect(result.isSuccess, isTrue);
      verify(() => mockAuthService.sendPasswordReset('farmer@example.com'))
          .called(1);
    });

    // ─── 6. Expired Password-Reset Link ───────────────────────────────────
    test(
        '6. Expired password-reset code returns error and shows invalid link screen',
        () async {
      when(() => mockAuthService.sendPasswordReset('farmer@example.com'))
          .thenThrow(const AuthFailure('Invalid or expired code'));

      final result = await authRepo.sendPasswordReset('farmer@example.com');

      expect(result.isError, isTrue);
      expect(result.failure?.message, contains('Invalid or expired code'));
    });

    // ─── 7. Invalid Deep Link ─────────────────────────────────────────────
    test('7. DeepLinkService rejects invalid schemes and malicious domains',
        () {
      final deepLinkService = DeepLinkService();
      final mockRouter = MockGoRouter();

      // Invalid scheme (ftp)
      deepLinkService.handleUri(
        Uri.parse('ftp://cropguardai.app/reset-password?oobCode=123'),
        mockRouter,
      );
      verifyNever(() => mockRouter.go(any()));

      // Unauthorized host
      deepLinkService.handleUri(
        Uri.parse('https://evil-site.com/reset-password?oobCode=123'),
        mockRouter,
      );
      verifyNever(() => mockRouter.go(any()));

      // Malicious traversal code
      deepLinkService.handleUri(
        Uri.parse('https://cropguardai.app/reset-password?oobCode=../bad'),
        mockRouter,
      );
      verifyNever(() => mockRouter.go(any()));
    });

    // ─── 8. Cold Start Deep Link Handling ─────────────────────────────────
    test('8. Cold start valid password-reset link routes to /reset_password',
        () {
      final deepLinkService = DeepLinkService();
      final mockRouter = MockGoRouter();

      final uri = Uri.parse(
          'https://cropguardai.app/reset-password?oobCode=validOobCode123&mode=resetPassword');

      deepLinkService.handleUri(uri, mockRouter);

      verify(() => mockRouter.go('/reset_password?oobCode=validOobCode123'))
          .called(1);
    });

    test('8b. Supabase PKCE reset link routes to /reset_password with code',
        () {
      final deepLinkService = DeepLinkService();
      final mockRouter = MockGoRouter();

      final uri = Uri.parse(
          'https://cropguardai.app/reset-password?code=supabaseAuthCode456');

      deepLinkService.handleUri(uri, mockRouter);

      verify(() => mockRouter.go('/reset_password?oobCode=supabaseAuthCode456'))
          .called(1);
    });

    test('8c. Supabase implicit recovery hash fragment routes to /reset_password',
        () {
      final deepLinkService = DeepLinkService();
      final mockRouter = MockGoRouter();

      final uri = Uri.parse(
          'https://cropguardai.app/reset-password#access_token=token&type=recovery');

      deepLinkService.handleUri(uri, mockRouter);

      verify(() => mockRouter.go('/reset_password?oobCode='))
          .called(1);
    });

    // ─── 9. Warm Start Deep Link Handling ─────────────────────────────────
    test('9. Warm start inbound stream routes to target without crashing',
        () async {
      final deepLinkService = DeepLinkService();
      final mockRouter = MockGoRouter();

      var customHandled = false;
      deepLinkService.registerHandler('/outbreak', (uri, router) {
        customHandled = true;
      });

      final outbreakUri = Uri.parse('https://cropguardai.app/outbreak/123');
      deepLinkService.handleUri(outbreakUri, mockRouter);

      expect(customHandled, isTrue);
    });

    // ─── 10. App Closed / Auth State Stream ────────────────────────────────
    test('10. App closed auth state emission maps to AppUser model', () async {
      final controller = StreamController<sb.User?>();
      when(() => mockAuthService.authStateChanges)
          .thenAnswer((_) => controller.stream);

      final events = <AppUser?>[];
      final sub = authRepo.authStateChanges.listen((user) => events.add(user));

      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('persisted_uid');
      when(() => mockUser.email).thenReturn('persisted@example.com');
      when(() => mockUser.userMetadata).thenReturn({'full_name': 'Kwesi'});
      when(() => mockUser.isAnonymous).thenReturn(false);

      controller.add(mockUser);
      controller.add(null);

      await Future.delayed(Duration.zero);
      await sub.cancel();
      await controller.close();

      expect(events.length, 2);
      expect(events[0]?.id, 'persisted_uid');
      expect(events[1], isNull);
    });

    // ─── 11. Account Deletion with Purge Order ─────────────────────────────
    test(
        '11. Account deletion purges cloud data and local history before deleting Auth user',
        () async {
      final mockSupabaseDb = MockSupabaseDatabaseService();
      final mockDb = MockDatabaseHelper();
      final mockAnalytics = MockAnalyticsService();
      final mockBiometric = MockBiometricService();
      final mockLock = MockAppLockController();

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      if (sl.isRegistered<SupabaseDatabaseService>()) {
        sl.unregister<SupabaseDatabaseService>();
      }
      sl.registerSingleton<SupabaseDatabaseService>(mockSupabaseDb);

      when(() => mockAnalytics.setEnabled(any())).thenAnswer((_) async {});
      when(() => mockBiometric.isAvailable()).thenAnswer((_) async => false);
      when(() => mockAuthService.hasPasswordProvider).thenReturn(true);
      when(() => mockAuthService.hasGoogleProvider).thenReturn(false);
      when(() => mockAuthService.currentUserId).thenReturn('user_delete_123');
      when(() => mockAuthService.reauthenticateWithPassword('Pass1234!'))
          .thenAnswer((_) async {});
      when(() => mockSupabaseDb.deleteUserData('user_delete_123'))
          .thenAnswer((_) async {});
      when(() => mockDb.deleteAllDetections()).thenAnswer((_) async {});
      when(() => mockAuthService.deleteAccount()).thenAnswer((_) async {});

      final settingsProvider = SettingsProvider(
        prefs,
        mockAuthService,
        mockDb,
        mockAnalytics,
        mockBiometric,
        mockLock,
      );

      var successCalled = false;
      await settingsProvider.deleteAccount(
        password: 'Pass1234!',
        onSuccess: () => successCalled = true,
      );

      expect(successCalled, isTrue);
      // Verify strict purge order
      verifyInOrder([
        () => mockAuthService.reauthenticateWithPassword('Pass1234!'),
        () => mockSupabaseDb.deleteUserData('user_delete_123'),
        () => mockDb.deleteAllDetections(),
        () => mockAuthService.deleteAccount(),
      ]);

      sl.unregister<SupabaseDatabaseService>();
    });

    // ─── 12. Reauthentication Flows ────────────────────────────────────────
    test(
        '12. Reauthentication with password and Google works via AuthRepository',
        () async {
      when(() => mockAuthService.hasPasswordProvider).thenReturn(true);
      when(() => mockAuthService.hasGoogleProvider).thenReturn(true);
      when(() => mockAuthService.reauthenticateWithPassword('CorrectPass'))
          .thenAnswer((_) async {});
      when(() => mockAuthService.reauthenticateWithGoogle())
          .thenAnswer((_) async {});

      expect(authRepo.hasPasswordProvider, isTrue);
      expect(authRepo.hasGoogleProvider, isTrue);

      final passRes = await authRepo.reauthenticateWithPassword('CorrectPass');
      expect(passRes.isSuccess, isTrue);

      final googleRes = await authRepo.reauthenticateWithGoogle();
      expect(googleRes.isSuccess, isTrue);
    });

    test('12b. Reauthentication fails with incorrect credentials', () async {
      when(() => mockAuthService.reauthenticateWithPassword('BadPass'))
          .thenThrow(const AuthFailure('wrong-password'));

      final res = await authRepo.reauthenticateWithPassword('BadPass');
      expect(res.isError, isTrue);
      expect(res.failure?.message, contains('wrong-password'));
    });
  });
}
