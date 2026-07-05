import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> hasCameraPermission() async {
    return await Permission.camera.status.isGranted;
  }

  static Future<bool> hasStoragePermission() async {
    // Handling Android 13+ (photos) and below (storage) is done by the plugin
    return await Permission.photos.status.isGranted || await Permission.storage.status.isGranted;
  }

  // The scanner only needs the camera. Gallery access goes through
  // image_picker, which uses the system photo picker on Android 13+/iOS and
  // needs no runtime permission. Requiring photos/storage here locked users
  // out of scanning when they denied (or "limited") photo access.
  static Future<bool> hasScannerPermissions() async {
    return await hasCameraPermission();
  }

  static Future<bool> requestScannerPermissions() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
}
