import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Listens to Supabase auth state changes and notifies listeners (such as
/// [GoRouter]) when the user signs in or out.
class AuthStateNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  AuthStateNotifier([SupabaseClient? client]) {
    final supabaseClient = client ?? Supabase.instance.client;
    _subscription = supabaseClient.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
