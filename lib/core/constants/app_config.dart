class AppConfig {
  AppConfig._();

  /// Supabase project URL, injected at build time via
  /// `--dart-define=SUPABASE_URL=...`.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon/publishable key, injected at build time via
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether both Supabase values were provided by the build.
  static const bool isConfigured =
      supabaseUrl != '' && supabaseAnonKey != '';

  /// Comma-separated emails granted the admin role at sign-up, injected via
  /// `--dart-define=ADMIN_EMAILS=you@example.com,other@example.com`.
  ///
  /// Development convenience only — the list is compiled into the binary and
  /// is readable by anyone who unpacks the app, so it must never be the only
  /// gate. Real admins are promoted in the database with
  /// `supabase/promote_first_admin.sql`; see
  /// [adminEmailAllowlist] for how the value is parsed.
  static const String adminEmails = String.fromEnvironment('ADMIN_EMAILS');

  /// Lower-cased, non-empty entries of [adminEmails].
  static Set<String> get adminEmailAllowlist => {
        for (final email in adminEmails.split(','))
          if (email.trim().isNotEmpty) email.trim().toLowerCase(),
      };

  /// Whether [email] is in the build-time [adminEmailAllowlist].
  static bool isAllowlistedAdmin(String email) =>
      adminEmailAllowlist.contains(email.trim().toLowerCase());
}