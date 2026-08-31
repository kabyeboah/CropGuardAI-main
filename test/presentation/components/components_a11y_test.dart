import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cropguard_flutter/l10n/app_localizations.dart';
import 'package:cropguard_flutter/presentation/components/confidence_bar.dart';
import 'package:cropguard_flutter/presentation/components/primary_button.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      AppLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('ConfidenceBar renders the rounded percentage', (tester) async {
    await tester.pumpWidget(_wrap(const ConfidenceBar(confidence: 0.85)));
    await tester.pumpAndSettle();
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('LimeButton exposes button semantics with its label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(LimeButton(text: 'Scan now', onPressed: () {})),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Scan now')),
      matchesSemantics(
          label: 'Scan now',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true),
    );
    handle.dispose();
  });

  testWidgets('PrimaryButton shows a spinner instead of label while loading',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const PrimaryButton(text: 'Submit', isLoading: true)),
    );
    expect(find.text('Submit'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
