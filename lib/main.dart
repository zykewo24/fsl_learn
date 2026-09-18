import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/constants/app_config.dart';

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

  runApp(
    const ProviderScope(
      child: FslLearnApp(),
    ),
  );
}