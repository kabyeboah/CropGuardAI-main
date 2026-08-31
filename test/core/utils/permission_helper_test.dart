import 'package:cropguard_flutter/core/utils/permission_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionHelper Status Classifiers', () {
    test('isGrantedOrLimited correctly identifies granted states', () {
      expect(PermissionHelper.isGrantedOrLimited(PermissionStatus.granted),
          isTrue);
      expect(PermissionHelper.isGrantedOrLimited(PermissionStatus.limited),
          isTrue);
      expect(PermissionHelper.isGrantedOrLimited(PermissionStatus.denied),
          isFalse);
      expect(
          PermissionHelper.isGrantedOrLimited(
              PermissionStatus.permanentlyDenied),
          isFalse);
      expect(PermissionHelper.isGrantedOrLimited(PermissionStatus.restricted),
          isFalse);
      expect(PermissionHelper.isGrantedOrLimited(PermissionStatus.provisional),
          isFalse);
    });

    test(
        'requiresSettingsRecovery correctly identifies unrecoverable runtime states',
        () {
      expect(
          PermissionHelper.requiresSettingsRecovery(
              PermissionStatus.permanentlyDenied),
          isTrue);
      expect(
          PermissionHelper.requiresSettingsRecovery(
              PermissionStatus.restricted),
          isTrue);
      expect(
          PermissionHelper.requiresSettingsRecovery(PermissionStatus.granted),
          isFalse);
      expect(
          PermissionHelper.requiresSettingsRecovery(PermissionStatus.limited),
          isFalse);
      expect(PermissionHelper.requiresSettingsRecovery(PermissionStatus.denied),
          isFalse);
      expect(
          PermissionHelper.requiresSettingsRecovery(
              PermissionStatus.provisional),
          isFalse);
    });
  });

  group('PermissionHelper Dialogs UI Tests', () {
    testWidgets('showPermissionRationaleDialog renders and handles actions',
        (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult =
                      await PermissionHelper.showPermissionRationaleDialog(
                    context,
                    title: 'Camera Access Needed',
                    message: 'We need camera access to scan crop leaves.',
                    confirmText: 'Allow Access',
                    cancelText: 'Not Now',
                  );
                },
                child: const Text('Open Rationale'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Rationale'));
      await tester.pumpAndSettle();

      expect(find.text('Camera Access Needed'), findsOneWidget);
      expect(find.text('We need camera access to scan crop leaves.'),
          findsOneWidget);
      expect(find.text('Allow Access'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Allow Access'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('showPermissionRationaleDialog returns false when cancelled',
        (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult =
                      await PermissionHelper.showPermissionRationaleDialog(
                    context,
                    title: 'Location Needed',
                    message: 'Location is required for outbreak alerts.',
                    confirmText: 'Continue',
                    cancelText: 'Cancel',
                  );
                },
                child: const Text('Open Rationale'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Rationale'));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });

    testWidgets(
        'showPermissionRecoveryDialog renders title, message and settings action',
        (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult =
                      await PermissionHelper.showPermissionRecoveryDialog(
                    context,
                    title: 'Microphone Permission Disabled',
                    message:
                        'Microphone permission is required for voice dictation. Please enable it in Settings.',
                    settingsText: 'Go to Settings',
                    cancelText: 'Dismiss',
                  );
                },
                child: const Text('Open Recovery'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Recovery'));
      await tester.pumpAndSettle();

      expect(find.text('Microphone Permission Disabled'), findsOneWidget);
      expect(
          find.text(
              'Microphone permission is required for voice dictation. Please enable it in Settings.'),
          findsOneWidget);
      expect(find.text('Go to Settings'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      // Dismiss
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });
  });
}
