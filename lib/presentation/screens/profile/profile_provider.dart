import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/connectivity_service.dart';
import '../../../data/remote/image_upload_service.dart';
import '../../../domain/repositories/i_auth_repository.dart';
import '../../../domain/repositories/i_profile_repository.dart';

import '../../../domain/models/reporter_trust_stats.dart';

class ProfileStats {
  final int totalScans;
  final int healthyScans;
  final int diseasedScans;
  final int warningScans;

  const ProfileStats({
    this.totalScans = 0,
    this.healthyScans = 0,
    this.diseasedScans = 0,
    this.warningScans = 0,
  });

  double get healthScore => totalScans > 0 ? healthyScans / totalScans : 0;
  int get diseasesCaught => diseasedScans + warningScans;
}

/// Equivalent of ProfileViewModel.kt
class ProfileProvider extends ChangeNotifier {
  final IProfileRepository _repository;
  final IAuthRepository _authRepository;
  final ConnectivityService _connectivity;
  final ImageUploadService _uploader;
  StreamSubscription<ConnectionStatus>? _connectivitySub;

  ProfileProvider(this._repository, this._authRepository, this._connectivity,
      this._uploader) {
    _connectivitySub = _connectivity.statusStream.listen((status) {
      connectionStatus = status;
      notifyListeners();
    });
    _connectivity.checkStatus().then((status) {
      connectionStatus = status;
      notifyListeners();
    });
    load();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  ProfileStats stats = const ProfileStats();
  ReporterTrustStats trustStats = const ReporterTrustStats();
  bool alertsEnabled = true;
  bool highQualityScans = true;
  ConnectionStatus connectionStatus = ConnectionStatus.online;
  bool get isOffline => connectionStatus == ConnectionStatus.offline;
  bool isPro = false;

  String get userName => _authRepository.currentUser?.displayName ?? 'Farmer';
  String get userEmail => _authRepository.currentUser?.email ?? '';

  /// Cloud copy of the avatar (synced to Auth backend) — used as a fallback
  /// when there is no local file (e.g. fresh install on a new device).
  String? get avatarUrl => _authRepository.currentUser?.photoUrl;

  /// Local, offline-first copy of the avatar. This is the primary display
  /// source: it shows instantly and works with no network.
  String? localPhotoPath;

  Future<void> load() async {
    localPhotoPath = _repository.getLocalProfilePhotoPath();

    final result = await _repository.getFarmStats();
    if (result.isSuccess) {
      final rawStats = result.data!;
      final total = rawStats['total'] ?? 0;
      stats = ProfileStats(
        totalScans: total,
        healthyScans: rawStats['healthy'] ?? 0,
        diseasedScans: rawStats['diseased'] ?? 0,
      );
      isPro = total >= 100;
    }

    final userId = _authRepository.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      final trustResult = await _repository.getReporterTrustStats(userId);
      if (trustResult.isSuccess && trustResult.data != null) {
        trustStats = trustResult.data!;
      }
    }

    alertsEnabled = _repository.getAlertsEnabled();
    highQualityScans = _repository.getHighQualityScans();

    notifyListeners();
  }

  void setAlertsEnabled(bool v) {
    alertsEnabled = v;
    _repository.setAlertsEnabled(v);
    notifyListeners();
  }

  void setHighQualityScans(bool v) {
    highQualityScans = v;
    _repository.setHighQualityScans(v);
    notifyListeners();
  }

  Future<void> signOut(VoidCallback onDone) async {
    await _repository.signOut();
    onDone();
  }

  // ─── Profile photo (local-first, cloud-synced) ──────────────────────────
  /// True while the chosen image is being copied into local storage.
  bool isSavingPhoto = false;

  /// True while the local photo is being uploaded to the cloud in the
  /// background. Display is never blocked on this.
  bool isSyncingPhoto = false;
  String? uploadPhotoError;

  /// Sets [sourcePath] (a freshly picked image) as the profile photo.
  ///
  /// The file is copied into app storage first so it displays instantly and
  /// works offline; the cloud upload then runs in the background and never
  /// blocks the UI. A cloud-sync failure is non-fatal — the photo is already
  /// set locally and sync will retry next time the user changes it.
  Future<void> setProfilePhoto(String sourcePath) async {
    isSavingPhoto = true;
    uploadPhotoError = null;
    notifyListeners();
    try {
      localPhotoPath = await _repository.saveLocalProfilePhoto(sourcePath);
    } catch (e, st) {
      AppLogger.e('Saving local profile photo failed', e, st);
      uploadPhotoError = 'Could not set photo: ${_readableError(e)}';
      isSavingPhoto = false;
      notifyListeners();
      return;
    }
    isSavingPhoto = false;
    notifyListeners();

    // Best-effort background sync to the cloud — failures are swallowed.
    unawaited(_syncPhotoToCloud(localPhotoPath!));
  }

  Future<void> _syncPhotoToCloud(String localPath) async {
    if (connectionStatus == ConnectionStatus.offline) return;
    isSyncingPhoto = true;
    notifyListeners();
    try {
      final url = await _uploader.uploadImage(localPath,
          userId: _authRepository.currentUser?.id);
      await _authRepository.updatePhotoUrl(url);
    } catch (e, st) {
      // Non-fatal: the picture is already set locally. Log for diagnostics.
      AppLogger.e('Cloud photo sync failed (photo still set locally)', e, st);
    } finally {
      isSyncingPhoto = false;
      notifyListeners();
    }
  }

  /// Removes the profile photo locally and clears the cloud copy (best-effort).
  Future<void> removeProfilePhoto() async {
    await _repository.clearLocalProfilePhoto();
    localPhotoPath = null;
    uploadPhotoError = null;
    notifyListeners();
    if (connectionStatus != ConnectionStatus.offline) {
      final result = await _authRepository.updatePhotoUrl('');
      if (!result.isSuccess) {
        AppLogger.e('Clearing cloud photo failed', result.failure);
      }
    }
  }

  /// Strips the leading "Exception:" noise so the user sees a clean reason.
  String _readableError(Object e) {
    final msg = e.toString();
    return msg.startsWith('Exception: ')
        ? msg.substring('Exception: '.length)
        : msg;
  }

  String? profileError;
  bool isSavingProfile = false;

  /// Saves the editable profile fields. The photo is handled separately and
  /// immediately by [setProfilePhoto]/[removeProfilePhoto]; this only persists
  /// the display name.
  Future<bool> saveProfile({required String displayName}) async {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      profileError = 'Display name cannot be empty.';
      notifyListeners();
      return false;
    }

    isSavingProfile = true;
    profileError = null;
    notifyListeners();

    final nameResult = await _authRepository.updateDisplayName(trimmedName);
    if (!nameResult.isSuccess) {
      AppLogger.e('Update display name failed', nameResult.failure);
      profileError =
          'Could not update display name: ${nameResult.failure?.message ?? 'unknown error'}';
      isSavingProfile = false;
      notifyListeners();
      return false;
    }

    isSavingProfile = false;
    notifyListeners();
    return true;
  }

  void clearProfileError() {
    profileError = null;
    notifyListeners();
  }
}
