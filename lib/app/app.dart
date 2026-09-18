import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import '../features/ai_practice/providers/ai_session_provider.dart';
import '../providers/lesson_provider.dart';
import '../providers/profile_provider.dart';
import 'router.dart';
import 'routes.dart';

class FslLearnApp extends StatefulWidget {
  const FslLearnApp({super.key});

  @override
  State<FslLearnApp> createState() => _FslLearnAppState();
}

class _FslLearnAppState extends State<FslLearnApp> {
  StreamSubscription<AuthState>? _authSub;
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        // The user tapped the password-reset link in the Supabase recovery email.
        // The SDK has already established the recovery session; pin the user on
        // the reset-password screen so they land there instead of home.
        if (data.event == AuthChangeEvent.passwordRecovery) {
          AppRouter.recoveryPending = true;
          AppRouter.router.go(AppRoutes.resetPassword);
          return;
        }

        // The SDK emits `signedOut` as soon as the local session is cleared,
        // BEFORE the server-side token-revocation request completes. Navigating
        // here (instead of awaiting `signOut()` in each screen) makes sign-out
        // take effect immediately and from anywhere in the app.
        if (data.event == AuthChangeEvent.signedOut) {
          AppRouter.recoveryPending = false;
          _invalidateUserScopedProviders();
          AppRouter.router.go(AppRoutes.login);
        }

        // A session was just established — either the user signed in, or an
        // OAuth provider (Google/Facebook) returned via the `fsllearn://callback`
        // deep link. Navigate to home so auth success always lands the user on
        // the signed-in experience, from any screen.
        if (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.tokenRefreshed) {
          AppRouter.recoveryPending = false;
          if (data.event == AuthChangeEvent.signedIn) {
            _invalidateUserScopedProviders();
          }
          AppRouter.router.go(AppRoutes.home);
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context, listen: false);
  }

  /// Clears cached user-scoped providers so account switches never show the
  /// previous user's progress. Curriculum providers (levels/modules/signs)
  /// are untouched, and [settingsProvider] must NOT be invalidated here
  /// because it is loaded once from SharedPreferences.
  void _invalidateUserScopedProviders() {
    final container = _container;
    if (container == null) return;

    container.invalidate(profileProvider);
    container.invalidate(progressSnapshotProvider);
    container.invalidate(lessonProgressProvider);
    container.invalidate(aiSessionProvider);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'FSL Learn',
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
