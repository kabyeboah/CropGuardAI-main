import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages locally blocked users to filter abusive users from the community feed
/// and outbreak contributions.
class UserBlockService extends ChangeNotifier {
  static const String _prefsKey = 'cropguard_blocked_users';
  final SharedPreferences? _prefs;
  final Set<String> _blockedUserIds = {};

  UserBlockService([this._prefs]) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;
    final list = _prefs.getStringList(_prefsKey);
    if (list != null) {
      _blockedUserIds.addAll(list);
    }
  }

  /// Returns an unmodifiable set of blocked user IDs.
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);

  /// Checks if [userId] is blocked.
  bool isBlocked(String userId) {
    if (userId.isEmpty) return false;
    return _blockedUserIds.contains(userId);
  }

  /// Blocks [userId] and persists to storage.
  Future<void> blockUser(String userId) async {
    if (userId.isEmpty || _blockedUserIds.contains(userId)) return;
    _blockedUserIds.add(userId);
    if (_prefs != null) {
      await _prefs.setStringList(_prefsKey, _blockedUserIds.toList());
    }
    notifyListeners();
  }

  /// Unblocks [userId] and updates storage.
  Future<void> unblockUser(String userId) async {
    if (userId.isEmpty || !_blockedUserIds.contains(userId)) return;
    _blockedUserIds.remove(userId);
    if (_prefs != null) {
      await _prefs.setStringList(_prefsKey, _blockedUserIds.toList());
    }
    notifyListeners();
  }

  /// Clears all blocked users.
  Future<void> clearAll() async {
    _blockedUserIds.clear();
    if (_prefs != null) {
      await _prefs.remove(_prefsKey);
    }
    notifyListeners();
  }
}
