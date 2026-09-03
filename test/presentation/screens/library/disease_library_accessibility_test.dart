import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cropguard_flutter/core/theme/app_theme.dart';
import 'package:cropguard_flutter/core/utils/tts_manager.dart';
import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/presentation/screens/library/disease_library_screen.dart';

Widget _wrapDiseaseLibrary({String initialLocation = '/disease_library'}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/disease_library'),
            child: const Text('Go to Library'),
          ),
        ),
      ),
      GoRoute(
        path: '/disease_library',
        builder: (context, state) => const DiseaseLibraryScreen(),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      AppLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => 1,
    );
    TtsManager().stop();
  });

  tearDown(() {
    TtsManager().stop();
  });

  group('DiseaseLibraryScreen Accessibility & Back Navigation', () {
    testWidgets('renders accessible AppBar with standard BackButton when navigated to', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapDiseaseLibrary(initialLocation: '/home'));
      await tester.pumpAndSettle();

      // Navigate to disease library
      await tester.tap(find.text('Go to Library'));
      await tester.pumpAndSettle();

      // Verify accessible AppBar exists
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Disease Library'), findsOneWidget);

      // Verify standard back button exists
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);

      // Verify tap target dimensions (standard 48x48)
      final size = tester.getSize(backButton);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      // Tap back button
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should be back at Home
      expect(find.text('Go to Library'), findsOneWidget);
    });

    testWidgets('renders fallback IconButton back with tooltip when cannot pop', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapDiseaseLibrary(initialLocation: '/disease_library'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      // Verify tap target dimensions
      final iconButton = find.byType(IconButton).first;
      final size = tester.getSize(iconButton);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('Disease Library TTS controls and lifecycle', () {
    testWidgets('displays play and stop toggle in disease detail sheet and stops on dismiss', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapDiseaseLibrary());
      await tester.pumpAndSettle();

      // Tap a disease item to open detail sheet
      await tester.tap(find.text('Apple Scab'));
      await tester.pumpAndSettle();

      // Initially sound button is volume_up with 'Listen to Disease Info' tooltip
      final playButton = find.byTooltip('Listen to Disease Info');
      expect(playButton, findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      // Simulate playing state
      TtsManager().isPlayingNotifier.value = true;
      await tester.pump();

      // Now button switches to stop icon with 'Stop reading' tooltip
      final stopButton = find.byTooltip('Stop reading');
      expect(stopButton, findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_rounded), findsOneWidget);

      // Tap stop button
      await tester.tap(stopButton);
      await tester.pump();

      // Verify TtsManager is stopped
      expect(TtsManager().isPlaying, isFalse);
      expect(find.byTooltip('Listen to Disease Info'), findsOneWidget);

      // Set playing again
      TtsManager().isPlayingNotifier.value = true;
      await tester.pump();
      expect(TtsManager().isPlaying, isTrue);

      // Dismiss modal bottom sheet by tapping barrier/scrim at top
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Verify playback was automatically stopped when sheet closed
      expect(TtsManager().isPlaying, isFalse);
    });
  });
}
