import 'package:in_app_update/in_app_update.dart';

import 'app_logger.dart';

class InAppUpdateHelper {
  static Future<void> checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Start downloading in the background. completeFlexibleUpdate() must
        // only be called after the download finishes (user prompted by system
        // notification), so we do not call it here.
        await InAppUpdate.startFlexibleUpdate();
      }
    } catch (e) {
      AppLogger.w('InAppUpdateHelper: update check failed (Play Store API): $e');
    }
  }
}
