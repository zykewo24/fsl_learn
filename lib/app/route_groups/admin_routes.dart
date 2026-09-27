import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../routes.dart';

class AdminRoutes {
  AdminRoutes._();

  static final List<RouteBase> routes = [
    GoRoute(
      path: AppRoutes.admin,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
  ];
}
