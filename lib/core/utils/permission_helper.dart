import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import 'app_logger.dart';

/// Centralized manager for handling runtime native permissions and their lifecycle:
/// - First runtime request
/// - Granted / Allowed (including limited on iOS)
/// - Denied (temporary)
/// - Permanently Denied / Restricted
/// - App Settings recovery navigation
class PermissionHelper {
  // ---------------------------------------------------------------------------
  // Status Checkers
  // ---------------------------------------------------------------------------

  /// Checks if camera permission is granted.
  static Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return isGrantedOrLimited(status);
  }

  /// Checks if photo library / storage permission is granted.
  static Future<bool> hasStoragePermission() async {
    final photosStatus = await Permission.photos.status;
    if (isGrantedOrLimited(photosStatus)) return true;

    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      if (isGrantedOrLimited(storageStatus)) return true;
    }
    return false;
  }

  /// Checks if photo library permission is granted.
  static Future<bool> hasPhotosPermission() => hasStoragePermission();

  /// Checks if location permission is granted.
  static Future<bool> hasLocationPermission() async {
    final status = await Permission.location.status;
    return isGrantedOrLimited(status);
  }

  /// Checks if microphone permission is granted.
  static Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return isGrantedOrLimited(status);
  }

  /// Checks if notification permission is granted.
  static Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return isGrantedOrLimited(status);
  }

  /// Scanner only requires camera permission.
  static Future<bool> hasScannerPermissions() async {
    return await hasCameraPermission();
  }

  /// Helper to determine if a [PermissionStatus] grants feature access.
  static bool isGrantedOrLimited(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  /// Helper to determine if a [PermissionStatus] cannot be re-prompted directly
  /// and requires settings recovery.
  static bool requiresSettingsRecovery(PermissionStatus status) {
    return status.isPermanentlyDenied || status.isRestricted;
  }

  // ---------------------------------------------------------------------------
  // Dialogs & Recovery UI
  // ---------------------------------------------------------------------------

  /// Shows an explanation dialog before requesting a permission if rationale is needed.
  static Future<bool> showPermissionRationaleDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Continue',
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: colors.onBackgroundSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Shows a modal dialog when a permission is permanently denied or restricted,
  /// with a direct action button to open device App Settings.
  static Future<bool> showPermissionRecoveryDialog(
    BuildContext context, {
    required String title,
    required String message,
    String settingsText = 'Open Settings',
    String cancelText = 'Not Now',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.settings_outlined, color: colors.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: colors.onBackgroundSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop(true);
                await openAppSettings();
              },
              child: Text(settingsText),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Unified Request & Recovery Engine
  // ---------------------------------------------------------------------------

  /// Performs a complete permission request cycle:
  /// 1. Checks current status. If granted/limited, returns true immediately.
  /// 2. If already permanently denied/restricted, shows [showPermissionRecoveryDialog].
  /// 3. Otherwise, requests permission via system prompt.
  /// 4. If newly granted/limited, returns true.
  /// 5. If newly permanently denied/restricted, displays recovery dialog to App Settings.
  /// 6. If temporarily denied, displays an informative SnackBar if [showDeniedSnackbar] is true.
  static Future<bool> requestWithRecovery(
    BuildContext context,
    Permission permission, {
    required String title,
    required String rationaleMessage,
    required String recoveryMessage,
    bool showDeniedSnackbar = true,
  }) async {
    try {
      final currentStatus = await permission.status;
      if (isGrantedOrLimited(currentStatus)) {
        return true;
      }

      if (requiresSettingsRecovery(currentStatus)) {
        if (context.mounted) {
          await showPermissionRecoveryDialog(
            context,
            title: title,
            message: recoveryMessage,
          );
        }
        return false;
      }

      final newStatus = await permission.request();
      if (isGrantedOrLimited(newStatus)) {
        return true;
      }

      if (requiresSettingsRecovery(newStatus)) {
        if (context.mounted) {
          await showPermissionRecoveryDialog(
            context,
            title: title,
            message: recoveryMessage,
          );
        }
        return false;
      }

      if (showDeniedSnackbar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rationaleMessage),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return false;
    } catch (e) {
      AppLogger.e('Permission request error for $permission: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Feature Specific Convenience Handlers
  // ---------------------------------------------------------------------------

  /// Request Camera permission with full denied & settings recovery cycle.
  static Future<bool> requestCameraWithRecovery(BuildContext context) {
    return requestWithRecovery(
      context,
      Permission.camera,
      title: 'Camera Permission Needed',
      rationaleMessage:
          'Camera permission is required to scan crop leaves and diagnose diseases.',
      recoveryMessage:
          'Camera access is disabled. Please enable Camera permissions in Settings to scan crops.',
    );
  }

  /// Request Microphone permission with full denied & settings recovery cycle.
  static Future<bool> requestMicrophoneWithRecovery(BuildContext context) {
    return requestWithRecovery(
      context,
      Permission.microphone,
      title: 'Microphone Permission Needed',
      rationaleMessage:
          'Microphone permission is required for voice dictation.',
      recoveryMessage:
          'Microphone access is disabled. Please enable Microphone permissions in Settings to record voice notes.',
    );
  }

  /// Request Location permission with full denied & settings recovery cycle.
  static Future<bool> requestLocationWithRecovery(BuildContext context) {
    return requestWithRecovery(
      context,
      Permission.location,
      title: 'Location Permission Needed',
      rationaleMessage:
          'Location permission is required to show nearby outbreak alerts and local weather.',
      recoveryMessage:
          'Location access is disabled. Please enable Location permissions in Settings to see local farm alerts.',
    );
  }

  /// Request Photo Library permission with recovery.
  static Future<bool> requestPhotosWithRecovery(BuildContext context) {
    return requestWithRecovery(
      context,
      Permission.photos,
      title: 'Photo Library Permission Needed',
      rationaleMessage:
          'Photo library access is required to select crop images from your gallery.',
      recoveryMessage:
          'Photo library access is disabled. Please enable Photos permissions in Settings to upload images.',
    );
  }

  /// Request Notification permission with recovery.
  static Future<bool> requestNotificationsWithRecovery(BuildContext context) {
    return requestWithRecovery(
      context,
      Permission.notification,
      title: 'Notifications Permission Needed',
      rationaleMessage:
          'Notifications are required to receive disease alerts and treatment reminders.',
      recoveryMessage:
          'Notifications are disabled. Please enable Notifications in Settings to receive alerts.',
    );
  }

  /// Scanner permissions request (retained for backward compatibility).
  static Future<bool> requestScannerPermissions() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return status.isGranted;
  }

  /// Request Notification permission (retained for backward compatibility).
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
