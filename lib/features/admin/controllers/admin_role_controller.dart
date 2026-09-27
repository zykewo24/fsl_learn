import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/session_role.dart';
import '../../auth/controller/auth_controller.dart';
import '../models/user_role.dart';

/// Holds the signed-in user's [UserRole] and keeps [SessionRole] in sync so the
/// synchronous router guard can consult it.
///
/// Deliberately fails closed: [build] starts at [UserRole.learner] and
/// [refresh] only widens access after a successful `profiles` lookup. A missing
/// profile row, an expired session or a network error all leave the user on
/// the learner side of the guard, and the database enforces the same rule
/// independently.
class AdminRoleController extends Notifier<UserRole> {
  /// Whether a lookup has already succeeded for this session, so route builds
  /// can call [refresh] freely without re-querying on every frame.
  bool _resolved = false;

  @override
  UserRole build() {
    // main() resolves the role before the router exists, so this may already be
    // populated. Adopt it rather than clearing the cache: a cold start that
    // lands directly on /admin must not be bounced by a provider that happened
    // to initialise after that lookup. Anything not yet resolved stays at
    // learner, and [refresh] is free to widen it.
    final preloaded = SessionRole.current;
    _resolved = preloaded.isAdmin;
    return preloaded;
  }

  /// Re-reads the role for the current session.
  ///
  /// Call with [force] after a role change, or once per session otherwise.
  /// [AuthService.getCurrentRole] returns [UserRole.learner] when there is no
  /// session, so this is safe to call before sign-in completes.
  Future<UserRole> refresh({bool force = false}) async {
    if (!force && _resolved) return state;

    final role = await ref.read(authServiceProvider).getCurrentRole();

    state = role;
    SessionRole.update(role);
    _resolved = true;

    return role;
  }

  /// Whether the current session still holds admin access.
  bool get isAdmin => state.isAdmin;
}

/// The signed-in user's role. Watch this to show or hide admin-only UI.
final adminRoleProvider = NotifierProvider<AdminRoleController, UserRole>(
  AdminRoleController.new,
);

/// Whether the signed-in user may open the admin area.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(adminRoleProvider).isAdmin;
});

/// The signed-in user's id, or `null` when signed out.
///
/// The admin UI compares this against each row to mark "you" and to disable the
/// self-demotion control.
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});
