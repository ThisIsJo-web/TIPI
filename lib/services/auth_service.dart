import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Get current user session
  User? get currentUser => _client.auth.currentUser;

  // Stream of auth state changes (e.g. to listen to login/logout)
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Sign up with Email & Password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Sign in with Email & Password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Send SMS OTP to Phone (Pending provider setup)
  Future<void> sendOtpToPhone({
    required String phone,
  }) async {
    return _client.auth.signInWithOtp(
      phone: phone,
    );
  }

  // Verify SMS OTP for Phone
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    return _client.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: token,
    );
  }

  // Sign out
  Future<void> signOut() async {
    return _client.auth.signOut();
  }
}
