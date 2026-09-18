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
}