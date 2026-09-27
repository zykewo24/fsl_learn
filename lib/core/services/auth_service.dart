import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/admin/models/user_role.dart';
import '../../models/profile_model.dart';
import '../constants/app_config.dart';
import '../utils/with_retry.dart';
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Resolves the role a new account should start with.
  ///
  /// Only emails in the build-time [AppConfig.adminEmailAllowlist] start as
  /// [UserRole.admin]. This is a development convenience, not a security
  /// boundary — Postgres RLS policies from `supabase/admin_roles_and_rls.sql`
  /// are what actually gate admin data, so a tampered client cannot use this
  /// path to read or write anything an admin-only policy blocks.
  UserRole resolveSignUpRole(String email) {
    return AppConfig.isAllowlistedAdmin(email)
        ? UserRole.admin
        : UserRole.learner;
  }

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final AuthResponse response = await _supabase.auth.signUp(
      email: email,
      password: password,
      // The database creates the profiles row from an auth.users trigger
      // (public.handle_new_user), and it reads the display name from this
      // metadata. Without it the row lands as "User" and the insert below
      // conflicts, so the name the user just typed would be lost.
      data: <String, dynamic>{'full_name': fullName.trim()},
    );

    final user = response.user;

    if (user != null) {
      final role = resolveSignUpRole(email);

      // Normally redundant: public.handle_new_user has already created this
      // row from the auth.users insert, so this raises a primary-key conflict.
      // It is kept as the fallback for a database where that trigger is
      // missing, and the conflict is the expected outcome either way.
      try {
        await _supabase.from('profiles').insert({
          'id': user.id,
          'full_name': fullName,
          'email': email,
          // Advisory only. guard_profile_insert() overwrites it with the role
          // the database derives from public.admin_email_allowlist, so this is
          // never what actually decides the account's access level.
          'role': role.value,
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

  /// Reads the signed-in user's role from their `profiles` row.
  ///
  /// Returns [UserRole.learner] when there is no session, when the profile row
  /// does not exist yet, or when the lookup fails — the route guard and the
  /// admin UI both fail closed so a transient error can never widen access.
  Future<UserRole> getCurrentRole() async {
    final user = currentUser;

    if (user == null) return UserRole.learner;

    try {
      return withTransientJwtRetry(() async {
        final data = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        return UserRole.fromValue(data?['role']);
      });
    } catch (_) {
      return UserRole.learner;
    }
  }

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