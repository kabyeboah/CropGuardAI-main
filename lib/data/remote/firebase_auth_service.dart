import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_secrets.dart';

/// Wraps FirebaseAuth — equivalent of AuthRepositoryImpl + use cases
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Deep-link target for the password-reset email. Firebase appends the
  /// `oobCode`/`mode` query params to this URL; the app intercepts it as an
  /// Android App Link / iOS Universal Link and handles the reset in-app
  /// (see DeepLinkService + docs/PASSWORD_RESET_DEEPLINK.md).
  ///
  /// Values are resolved from [AppSecrets] (dart-define > .env > Remote Config >
  /// fallback) so they can be patched without a store release.
  String get _passwordResetContinueUrl => AppSecrets.passwordResetContinueUrl;
  String get _androidPackageName => AppSecrets.androidPackageName;
  String get _iosBundleId => AppSecrets.iosBundleId;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isSignedIn => _auth.currentUser != null;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  // ─── Email / Password ─────────────────────────────────────────────────
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    await credential.user?.updateDisplayName(name.trim());
    return credential;
  }

  Future<void> sendPasswordReset(String email) async {
    // handleCodeInApp + a deep-link continue URL makes the reset link open the
    // app directly rather than the Firebase-hosted web page.
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
      actionCodeSettings: ActionCodeSettings(
        url: _passwordResetContinueUrl,
        handleCodeInApp: true,
        androidPackageName: _androidPackageName,
        androidInstallApp: true,
        androidMinimumVersion: '1',
        iOSBundleId: _iosBundleId,
      ),
    );
  }

  /// Validates a password-reset `oobCode` from the deep link; returns the email
  /// the code is for. Throws if the code is invalid or expired.
  Future<String> verifyPasswordResetCode(String code) {
    return _auth.verifyPasswordResetCode(code);
  }

  /// Completes the in-app password reset using the `oobCode` from the link.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) {
    return _auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }

  // ─── Google Sign-In ───────────────────────────────────────────────────
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  // ─── Anonymous ────────────────────────────────────────────────────────
  Future<UserCredential> signInAnonymously() async {
    return _auth.signInAnonymously();
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── Re-authentication ────────────────────────────────────────────────
  bool get hasPasswordProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  bool get hasGoogleProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw Exception('No email account to re-authenticate');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> reauthenticateWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    await user.reauthenticateWithCredential(credential);
  }

  // ─── Delete Account ───────────────────────────────────────────────────
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    await user.delete();
  }

  // ─── Update Profile ───────────────────────────────────────────────────
  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }

  Future<void> updatePhotoUrl(String url) async {
    await _auth.currentUser?.updatePhotoURL(url);
  }

  String get currentUserId {
    final uid = _auth.currentUser?.uid;
    assert(uid != null, 'currentUserId called with no authenticated user');
    return uid ?? '';
  }
  String get currentUserEmail => _auth.currentUser?.email ?? '';
  String get currentUserName =>
      _auth.currentUser?.displayName ?? 'Farmer';
  String? get currentUserPhotoUrl => _auth.currentUser?.photoURL;
}
