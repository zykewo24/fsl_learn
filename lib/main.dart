import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/session_role.dart';
import 'core/constants/app_config.dart';
import 'core/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    throw StateError(
      'Supabase configuration missing.\n'
      'Build with:\n'
      '  flutter run --dart-define=SUPABASE_URL=<project-url> '
      "--dart-define=SUPABASE_ANON_KEY=<anon-key>\n"
      'See scripts/build_and_install.ps1 for the reference values used in development.',
    );
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  // Resolve the role *before* the router exists. GoRouter's redirect callback
  // is synchronous and reads the cached role, so a cold start that lands
  // directly on /admin would otherwise be redirected away before the lookup
  // ever ran. Failure is not fatal: the cache stays at the learner role and the
  // admin area simply stays closed until the next refresh.
  try {
    SessionRole.update(await AuthService().getCurrentRole());
  } catch (_) {
    SessionRole.clear();
  }

  runApp(
    const ProviderScope(
      child: FslLearnApp(),
    ),
  );
}