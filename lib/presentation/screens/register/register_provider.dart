import 'package:flutter/material.dart';
import '../../../core/utils/email_validator.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/remote/firebase_auth_service.dart';
import '../../../domain/usecases/auth/register_usecase.dart';

enum RegisterStatus { idle, loading, success, error }

class RegisterProvider extends ChangeNotifier {
  final RegisterUseCase _registerUseCase;
  final DatabaseHelper _db;
  final FirebaseAuthService _auth;

  RegisterProvider(this._registerUseCase, this._db, this._auth);

  String name = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  bool termsAccepted = false;
  RegisterStatus status = RegisterStatus.idle;
  String? errorMessage;
  bool obscurePassword = true;

  // ── Guest migration state ──────────────────────────────────────────────────
  String? _anonUid;
  int _anonScanCount = 0;
  VoidCallback? _pendingOnSuccess;

  int get anonScanCount => _anonScanCount;

  void setName(String v) { name = v; notifyListeners(); }
  void setEmail(String v) { email = v; notifyListeners(); }
  void setPassword(String v) { password = v; notifyListeners(); }
  void setConfirmPassword(String v) { confirmPassword = v; notifyListeners(); }
  void setTermsAccepted(bool v) { termsAccepted = v; notifyListeners(); }
  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    notifyListeners();
  }

  int get passwordStrength {
    if (password.isEmpty) return 0;
    if (password.length < 6) return 1;
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[^a-zA-Z0-9]'));
    if (password.length >= 12 && hasDigit && hasSpecial) return 4;
    if (password.length >= 8 && hasDigit) return 3;
    return 2;
  }

  /// [onMigrationNeeded] is called instead of [onSuccess] when the user was
  /// a guest with saved scans. Call [acceptMigration] or [declineMigration]
  /// from the dialog to complete the flow and trigger navigation.
  Future<void> register(
    VoidCallback onSuccess, {
    void Function(int count)? onMigrationNeeded,
  }) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      errorMessage = 'Please fill in all fields.';
      notifyListeners();
      return;
    }
    if (!EmailValidator.isValid(email)) {
      errorMessage = 'Please enter a valid email address.';
      notifyListeners();
      return;
    }
    if (password != confirmPassword) {
      errorMessage = 'Passwords do not match.';
      notifyListeners();
      return;
    }
    if (!termsAccepted) {
      errorMessage = 'Please accept the terms and privacy policy.';
      notifyListeners();
      return;
    }
    if (password.length < 6) {
      errorMessage = 'Password must be at least 6 characters.';
      notifyListeners();
      return;
    }

    // Capture anonymous state before Firebase replaces the current user.
    final wasAnonymous = _auth.isAnonymous;
    final anonUid = wasAnonymous ? _auth.currentUserId : null;
    final anonCount = (anonUid != null)
        ? await _db.countDetectionsForUser(anonUid)
        : 0;

    status = RegisterStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await _registerUseCase(
        email: email, password: password, name: name);

    if (result.isSuccess) {
      status = RegisterStatus.success;
      notifyListeners();
      if (wasAnonymous && anonCount > 0 && onMigrationNeeded != null) {
        _anonUid = anonUid;
        _anonScanCount = anonCount;
        _pendingOnSuccess = onSuccess;
        onMigrationNeeded(anonCount);
      } else {
        onSuccess();
      }
    } else {
      status = RegisterStatus.error;
      errorMessage = _mapError(result.failure!.message);
      notifyListeners();
    }
  }

  Future<void> acceptMigration() async {
    if (_anonUid != null) {
      await _db.reassignDetections(_anonUid!, _auth.currentUserId);
    }
    _completeMigration();
  }

  void declineMigration() => _completeMigration();

  void _completeMigration() {
    _anonUid = null;
    _anonScanCount = 0;
    final fn = _pendingOnSuccess;
    _pendingOnSuccess = null;
    notifyListeners();
    fn?.call();
  }

  String _mapError(String e) {
    if (e.contains('email-already-in-use')) return 'An account already exists with that email.';
    if (e.contains('weak-password')) return 'Password is too weak.';
    if (e.contains('network-request-failed')) return 'No internet connection.';
    return 'Registration failed. Please try again.';
  }
}
