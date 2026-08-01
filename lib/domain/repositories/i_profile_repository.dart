import '../../core/utils/result.dart';
import '../models/reporter_trust_stats.dart';

abstract class IProfileRepository {
  Future<Result<Map<String, int>>> getFarmStats();
  Future<Result<ReporterTrustStats>> getReporterTrustStats(String userId);
  Future<Result<void>> signOut();

  // Settings
  bool getAlertsEnabled();
  Future<void> setAlertsEnabled(bool enabled);

  bool getHighQualityScans();
  Future<void> setHighQualityScans(bool enabled);

  // Local profile photo (offline-first). The picture is copied into the app's
  // documents directory so it displays instantly and works without a network.
  /// Copies [sourcePath] into app storage and persists it as the profile
  /// photo. Returns the new local file path.
  Future<String> saveLocalProfilePhoto(String sourcePath);

  /// The persisted local profile photo path, or null if none exists on disk.
  String? getLocalProfilePhotoPath();

  /// Removes the local profile photo file and clears the saved path.
  Future<void> clearLocalProfilePhoto();
}
