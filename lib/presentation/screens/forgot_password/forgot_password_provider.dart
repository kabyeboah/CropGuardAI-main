import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/email_validator.dart';
import '../../../domain/usecases/auth/send_password_reset_usecase.dart';

enum ForgotPasswordStatus { idle, loading, success, error }

class ForgotPasswordProvider extends ChangeNotifier {
  final SendPasswordResetUseCase _resetUseCase;

  ForgotPasswordProvider(this._resetUseCase);

  ForgotPasswordStatus status = ForgotPasswordStatus.idle;
  String? errorMessage;
  int resendCooldown = 0;
  String _sentEmail = '';
  String get sentEmail => _sentEmail;

  Timer? _cooldownTimer;

  Future<void> send(String email) async {
    if (!EmailValidator.isValid(email)) {
      errorMessage = 'Please enter a valid email address.';
      status = ForgotPasswordStatus.error;
      notifyListeners();
      return;
    }
    status = ForgotPasswordStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await _resetUseCase(email.trim());
    if (result.isSuccess) {
      _sentEmail = email.trim();
      status = ForgotPasswordStatus.success;
      _startCooldown();
    } else {
      status = ForgotPasswordStatus.error;
      errorMessage = _mapError(result.failure!.message);
    }
    notifyListeners();
  }

  void _startCooldown() {
    resendCooldown = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendCooldown <= 1) {
        t.cancel();
        resendCooldown = 0;
      } else {
        resendCooldown--;
      }
      notifyListeners();
    });
  }

  String _mapError(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('INVALID_LOGIN_CREDENTIALS') ||
        raw.contains('no user record')) {
      return 'No account found with that email address.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (raw.contains('network-request-failed')) {
      return 'No internet connection.';
    }
    if (raw.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    return 'Could not send reset email. Please try again.';
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
