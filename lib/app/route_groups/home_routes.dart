import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../routes.dart';

class HomeRoutes {
  HomeRoutes._();

  static final List<RouteBase> routes = [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
  ];
}