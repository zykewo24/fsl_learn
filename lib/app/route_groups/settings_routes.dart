import 'package:go_router/go_router.dart';

import '../../features/settings/presentation/settings_screen.dart';
import '../routes.dart';

class SettingsRoutes {
  SettingsRoutes._();

  static final List<RouteBase> routes = [
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ];
}
