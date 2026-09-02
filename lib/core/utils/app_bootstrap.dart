import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_secrets.dart';
import 'app_logger.dart';
import 'image_compressor.dart';

class AppBootstrap {
  static Future<void> runStartupTasks() async {
    try {
      await _fetchRemoteConfigFromSupabase();
    } catch (e) {
      AppLogger.w("Supabase app_config fetch non-fatal notice: $e");
    }

    try {
      await ImageCompressor.cleanOldCompressedImages();
    } catch (e) {
      AppLogger.w("Old compressed images cleanup non-fatal warning: $e");
    }
  }

  static Future<void> _fetchRemoteConfigFromSupabase() async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('app_config')
          .select()
          .timeout(const Duration(seconds: 5));

      for (final row in rows) {
        final key = row['key']?.toString();
        final value = row['value'];
        if (key == null || value == null) continue;

        if (key == 'ghana_nlp_subscription_key' && value is String) {
          AppSecrets.setGhanaNlpSubscriptionKey(value);
        } else if (key == 'gemini_api_key' && value is String) {
          AppSecrets.setGeminiApiKey(value);
        } else if (key == 'cloudinary_config' && value is Map) {
          AppSecrets.setCloudinaryConfig(
            cloudName: value['cloud_name']?.toString(),
            uploadPreset: value['upload_preset']?.toString(),
          );
        } else if (key == 'password_reset_url' && value is String) {
          AppSecrets.setPasswordResetConfig(continueUrl: value);
        }
      }
    } catch (e) {
      AppLogger.d("Supabase app_config table not reachable or empty; using defaults ($e)");
    }
  }
}
