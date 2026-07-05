import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/error/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../local/database_helper.dart';
import '../remote/firebase_auth_service.dart';

class ProfileRepositoryImpl implements IProfileRepository {
  static const _localPhotoPathKey = 'profile_photo_local_path';

  final FirebaseAuthService _auth;
  final DatabaseHelper _db;
  final SharedPreferences _prefs;

  ProfileRepositoryImpl(this._auth, this._db, this._prefs);

  @override
  Future<Result<Map<String, int>>> getFarmStats() async {
    try {
      // Scope to the signed-in user so the profile shows this account's farm
      // stats, not every account that has ever scanned on this device.
      final stats = await _db.getFarmStats(userId: _auth.currentUser?.uid);
      return Result.success(stats);
    } catch (e) {
      return Result.error(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      return Result.success(null);
    } catch (e) {
      return Result.error(AuthFailure(e.toString()));
    }
  }

  @override
  bool getAlertsEnabled() => _prefs.getBool('alerts_enabled') ?? true;

  @override
  Future<void> setAlertsEnabled(bool enabled) => _prefs.setBool('alerts_enabled', enabled);

  @override
  bool getHighQualityScans() => _prefs.getBool('high_quality_scans') ?? true;

  @override
  Future<void> setHighQualityScans(bool enabled) => _prefs.setBool('high_quality_scans', enabled);

  @override
  Future<String> saveLocalProfilePhoto(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    // Versioned filename so the in-memory image cache always sees a new path
    // and refreshes (overwriting the same file would keep a stale cached image).
    final dest = p.join(dir.path, 'profile_${DateTime.now().millisecondsSinceEpoch}$ext');

    final copied = await File(sourcePath).copy(dest);

    // Delete the previous photo (if any) now that the new one is safely written.
    final previous = _prefs.getString(_localPhotoPathKey);
    if (previous != null && previous != copied.path) {
      final old = File(previous);
      if (await old.exists()) {
        try {
          await old.delete();
        } catch (_) {/* best-effort cleanup */}
      }
    }

    await _prefs.setString(_localPhotoPathKey, copied.path);
    return copied.path;
  }

  @override
  String? getLocalProfilePhotoPath() {
    final path = _prefs.getString(_localPhotoPathKey);
    if (path == null) return null;
    // Guard against a stale path whose file was removed (e.g. cache cleared).
    return File(path).existsSync() ? path : null;
  }

  @override
  Future<void> clearLocalProfilePhoto() async {
    final path = _prefs.getString(_localPhotoPathKey);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {/* best-effort cleanup */}
      }
    }
    await _prefs.remove(_localPhotoPathKey);
  }
}
