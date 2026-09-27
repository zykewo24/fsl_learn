import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'route_groups/admin_routes.dart';
import 'route_groups/auth_routes.dart';
import 'route_groups/home_routes.dart';
import 'route_groups/lesson_routes.dart';
import 'route_groups/practice_routes.dart';
import 'route_groups/settings_routes.dart';
import 'routes.dart';
import 'session_role.dart';

class AppRouter {
  AppRouter._();

  /// Set to `true` by the password-recovery listener when the user arrives
  /// from a Supabase reset-link deep link. While true the router pins the user
  /// on the reset-password screen so the recovery session isn't bounced to
  /// the home page.
  static bool recoveryPending = false;

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,

    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;

      final isLoggedIn = session != null;
      final isLoginPage = state.matchedLocation == AppRoutes.login;
      final isResetPage = state.matchedLocation == AppRoutes.resetPassword;

      // Client-side gate on the admin area. The role is cached in
      // [SessionRole] by AdminRoleController because this callback is
      // synchronous. It is defence in depth only — the RLS policies in
      // supabase/admin_roles_and_rls.sql are what actually stop a modified
      // client reaching admin data, so an unresolved role here (which starts
      // and stays at learner) is safe rather than merely inconvenient.
      final isAdminArea = state.matchedLocation == AppRoutes.admin ||
          state.matchedLocation.startsWith('${AppRoutes.admin}/');

      if (isLoggedIn && isAdminArea && !SessionRole.isAdmin) {
        return AppRoutes.home;
      }

      if (isLoggedIn && recoveryPending && !isResetPage) {
        return AppRoutes.resetPassword;
      }

      if (!isLoggedIn && !isLoginPage && !isResetPage) {
        return AppRoutes.login;
      }

      if (isLoggedIn && isLoginPage) {
        return AppRoutes.home;
      }

      return null;
    },

    routes: [
      ...AuthRoutes.routes,
      ...HomeRoutes.routes,
      ...LessonRoutes.routes,
      ...PracticeRoutes.routes,
      ...SettingsRoutes.routes,
      ...AdminRoutes.routes,
    ],
  );
}