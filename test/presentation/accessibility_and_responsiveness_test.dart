import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cropguard_flutter/core/theme/app_colors.dart';
import 'package:cropguard_flutter/core/theme/device_layout.dart';
import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/presentation/components/confidence_bar.dart';
import 'package:cropguard_flutter/presentation/components/cropguard_card.dart';
import 'package:cropguard_flutter/presentation/components/farm_health_ring.dart';
import 'package:cropguard_flutter/presentation/components/primary_button.dart';
import 'package:cropguard_flutter/presentation/components/severity_badge.dart';
import 'package:cropguard_flutter/presentation/components/voice_dictation_button.dart';

Widget _wrapWithLocale({
  required Widget child,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  Size size = const Size(375, 812),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    localeResolutionCallback: (loc, supportedLocales) {
      if (loc != null) {
        for (final supported in supportedLocales) {
          if (supported.languageCode == loc.languageCode) {
            return supported;
          }
        }
      }
      return const Locale('en');
    },
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('Accessibility & Semantics Tests', () {
    testWidgets(
        'PrimaryButton semantics include enabled state and loading label',
        (tester) async {
      final handle = tester.ensureSemantics();

      // Normal enabled state
      await tester.pumpWidget(_wrapWithLocale(
        child: PrimaryButton(text: 'Scan Now', onPressed: () {}),
      ));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(PrimaryButton)),
        matchesSemantics(
          label: 'Scan Now',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );

      // Loading state
      await tester.pumpWidget(_wrapWithLocale(
        child: const PrimaryButton(text: 'Scan Now', isLoading: true),
      ));
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(PrimaryButton)),
        matchesSemantics(
          label: 'Scan Now (Loading...)',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      handle.dispose();
    });

    testWidgets('SecondaryButton semantics reflect label and enabled state',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_wrapWithLocale(
        child: SecondaryButton(text: 'View Details', onPressed: () {}),
      ));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(SecondaryButton)),
        matchesSemantics(
          label: 'View Details',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('FarmHealthRing exposes score semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_wrapWithLocale(
        child: const FarmHealthRing(percentage: 0.85),
      ));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(FarmHealthRing)),
        matchesSemantics(
          label: 'Farm Health',
          value: '85%',
        ),
      );

      handle.dispose();
    });

    testWidgets('SeverityBadge and StatusBadge have correct semantics',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_wrapWithLocale(
        child: const Column(
          children: [
            SeverityBadge(severity: 'Severe'),
            StatusBadge(status: 'healthy'),
            StatusBadge(status: 'at risk'),
            StatusBadge(status: 'diseased'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Severe'), findsOneWidget);
      expect(find.bySemanticsLabel('Healthy'), findsOneWidget);
      expect(find.bySemanticsLabel('At Risk'), findsOneWidget);
      expect(find.bySemanticsLabel('Diseased'), findsOneWidget);

      handle.dispose();
    });
  });

  group('Touch Target Dimension Tests', () {
    testWidgets(
        'Primary and Secondary buttons satisfy min touch target of 48dp',
        (tester) async {
      await tester.pumpWidget(_wrapWithLocale(
        child: Column(
          children: [
            PrimaryButton(text: 'Primary', onPressed: () {}),
            const SizedBox(height: 8),
            SecondaryButton(text: 'Secondary', onPressed: () {}),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      final primarySize = tester.getSize(find.byType(PrimaryButton));
      final secondarySize = tester.getSize(find.byType(SecondaryButton));

      expect(primarySize.height,
          greaterThanOrEqualTo(DeviceLayout.minTouchTarget));
      expect(secondarySize.height,
          greaterThanOrEqualTo(DeviceLayout.minTouchTarget));
    });

    testWidgets('VoiceDictationButton satisfies min touch target of 48dp',
        (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(_wrapWithLocale(
        child: VoiceDictationButton(controller: ctrl),
      ));
      await tester.pumpAndSettle();

      final btnSize = tester.getSize(find.byType(IconButton));
      expect(btnSize.width, greaterThanOrEqualTo(DeviceLayout.minTouchTarget));
      expect(btnSize.height, greaterThanOrEqualTo(DeviceLayout.minTouchTarget));
    });
  });

  group('Font Scaling & Long Translations Tests', () {
    testWidgets(
        'Renders all 4 locales with 1.5x and 2.0x font scaling without overflow',
        (tester) async {
      final locales = [
        const Locale('en'),
        const Locale('tw'),
        const Locale('ee'),
        const Locale('dag'),
      ];

      for (final locale in locales) {
        for (final scale in [1.0, 1.5, 2.0]) {
          await tester.pumpWidget(_wrapWithLocale(
            locale: locale,
            textScale: scale,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const ConfidenceBar(confidence: 0.92),
                  const SizedBox(height: 12),
                  const FarmHealthRing(percentage: 0.78),
                  const SizedBox(height: 12),
                  PrimaryButton(text: 'Action Button', onPressed: () {}),
                  const SizedBox(height: 12),
                  SecondaryButton(text: 'Secondary Action', onPressed: () {}),
                  const SizedBox(height: 12),
                  const CropGuardCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SeverityBadge(severity: 'Moderate'),
                        SizedBox(height: 8),
                        StatusBadge(status: 'at risk'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ));
          await tester.pumpAndSettle();

          final exception = tester.takeException();
          if (exception is FlutterError) {
            expect(
              exception.toString(),
              isNot(contains('overflowed')),
              reason:
                  'Layout overflowed on locale ${locale.languageCode} at ${scale}x scale',
            );
          }
        }
      }
    });
  });

  group('Responsiveness & Form Factors Tests', () {
    testWidgets('Renders on small screens (320dp width) without overflow',
        (tester) async {
      await tester.pumpWidget(_wrapWithLocale(
        size: const Size(320, 568),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const ConfidenceBar(confidence: 0.75),
              const SizedBox(height: 16),
              PrimaryButton(text: 'Submit Scan Report', onPressed: () {}),
              const SizedBox(height: 16),
              SecondaryButton(text: 'Cancel and Discard', onPressed: () {}),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders in landscape orientation (800x400) without overflow',
        (tester) async {
      await tester.pumpWidget(_wrapWithLocale(
        size: const Size(800, 400),
        child: SingleChildScrollView(
          child: Row(
            children: [
              const Expanded(child: FarmHealthRing(percentage: 0.9)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    PrimaryButton(text: 'Scan Now', onPressed: () {}),
                    const SizedBox(height: 8),
                    SecondaryButton(text: 'View Outbreaks', onPressed: () {}),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Color Contrast Standards Verification', () {
    test('Light and Dark color palettes meet WCAG contrast thresholds', () {
      double contrastRatio(Color fg, Color bg) {
        final l1 = fg.computeLuminance();
        final l2 = bg.computeLuminance();
        final lighter = l1 > l2 ? l1 : l2;
        final darker = l1 > l2 ? l2 : l1;
        return (lighter + 0.05) / (darker + 0.05);
      }

      // Check primary button text (white) against primary green in light mode
      final primaryTextRatio =
          contrastRatio(Colors.white, AppColors.primaryLight);
      expect(primaryTextRatio, greaterThanOrEqualTo(4.5),
          reason:
              'Primary button contrast should meet WCAG AA standard (>=4.5:1)');

      // Check text against background in light mode
      final lightTextRatio =
          contrastRatio(AppColors.onBackgroundLight, AppColors.backgroundLight);
      expect(lightTextRatio, greaterThanOrEqualTo(4.5),
          reason:
              'Light theme text contrast should meet WCAG AA standard (>=4.5:1)');

      // Check text against background in dark mode
      final darkTextRatio =
          contrastRatio(AppColors.onBackgroundDark, AppColors.backgroundDark);
      expect(darkTextRatio, greaterThanOrEqualTo(4.5),
          reason:
              'Dark theme text contrast should meet WCAG AA standard (>=4.5:1)');
    });
  });
}
