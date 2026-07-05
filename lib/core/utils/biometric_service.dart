import 'package:local_auth/local_auth.dart';

import 'app_logger.dart';

/// Thin wrapper around [LocalAuthentication] for the biometric app-lock.
///
/// All methods are best-effort and never throw, so a missing sensor or a
/// platform error can't crash the lock flow — they just report "unavailable" or
/// "not authenticated".
class BiometricService {
  BiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True when the device can perform an authentication prompt — either real
  /// biometrics (fingerprint / Face ID / face unlock) or a device credential
  /// (PIN / pattern / passcode), which we accept as a fallback.
  Future<bool> isAvailable() async {
    try {
      // isDeviceSupported() is true when biometrics or a device credential
      // (PIN/passcode) is available — enough since we don't require biometricOnly.
      return await _auth.isDeviceSupported();
    } catch (e) {
      AppLogger.e('Biometric availability check failed', e);
      return false;
    }
  }

  /// Prompts for biometric / device-credential auth. Returns true only on a
  /// successful unlock. `biometricOnly: false` enables the PIN/passcode
  /// fallback so users without enrolled biometrics can still unlock.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        // Keep the prompt alive across the brief background it causes.
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      AppLogger.e('Biometric authentication failed', e);
      return false;
    }
  }
}
