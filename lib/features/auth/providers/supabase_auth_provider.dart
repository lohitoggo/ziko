import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseAuthStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final supabaseUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

class SupabaseAuthController {
  final SupabaseClient _client;
  SupabaseAuthController(this._client);

  Future<void> signInWithEmail(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: 'io.supabase.flutterquickstart://login-callback/',
    );
  }

  Future<AuthResponse> verifyEmailOtp(String email, String token) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

final supabaseAuthControllerProvider = Provider<SupabaseAuthController>((ref) {
  return SupabaseAuthController(ref.watch(supabaseClientProvider));
});
