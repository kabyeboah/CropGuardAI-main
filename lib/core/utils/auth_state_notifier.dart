import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Listens to [FirebaseAuth.authStateChanges] and notifies listeners (such as
/// [GoRouter]) when the user signs in or out.
class AuthStateNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _subscription;

  AuthStateNotifier([FirebaseAuth? auth]) {
    final firebaseAuth = auth ?? FirebaseAuth.instance;
    _subscription = firebaseAuth.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
