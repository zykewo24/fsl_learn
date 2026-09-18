import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/profile_model.dart';
import '../utils/with_retry.dart';
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final AuthResponse response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;

    if (user != null) {
      try {
        await _supabase.from('profiles').insert({
          'id': user.id,
          'full_name': fullName,
          'email': email,
        });
      } catch (_) {
        // Best-effort: the account was already created, so the sign-up
        // succeeded. [getProfile] falls back to auth metadata when the
        // profile row is missing, and a retry could reconcile it later.
      }
    }

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Starts Google OAuth sign-in. Launches the external browser, and the
  /// authenticated session returns to the app through the
  /// `fsllearn://callback` deep link once the user authorizes.
  Future<void> signInWithGoogle() async {
    final res = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'fsllearn://callback',
    );
    if (!res) {
      throw Exception('Unable to open Google sign-in.');
    }
  }

  /// Starts Facebook OAuth sign-in (see [signInWithGoogle]).
  Future<void> signInWithFacebook() async {
    final res = await _supabase.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: 'fsllearn://callback',
    );
    if (!res) {
      throw Exception('Unable to open Facebook sign-in.');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Sends a password-reset email to [email] via Supabase.
  ///
  /// The email points back to the app through the `fsllearn://reset-password`
  /// deep link so the user can set a new password without leaving the app.
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'fsllearn://reset-password',
    );
  }

  /// Applies a new password during the password-recovery flow.
  ///
  /// Requires the recovering user's session to be active, which the Supabase
  /// SDK establishes when the app launches with the recovery deep link from
  /// the reset email.
  Future<void> updatePassword({required String newPassword}) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  Future<ProfileModel?> getProfile() async {
    final user = currentUser;

    if (user == null) return null;

    return withTransientJwtRetry(() async {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // No profile row yet — fall back to Auth metadata so the
      // home screen can still load instead of throwing PGRST116.
      if (data == null) {
        final metadata = user.userMetadata ?? <String, dynamic>{};

        final fullName =
            (metadata['full_name'] as String?)?.trim().isNotEmpty == true
                ? (metadata['full_name'] as String).trim()
                : ((metadata['name'] as String?)?.trim().isNotEmpty == true
                    ? (metadata['name'] as String).trim()
                    : 'User');

        return ProfileModel(
          id: user.id,
          fullName: fullName,
          email: user.email ?? '',
          avatarUrl: null,
        );
      }

      return ProfileModel.fromJson(data);
    });
  }
}