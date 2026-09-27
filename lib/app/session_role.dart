import '../features/admin/models/user_role.dart';

/// Process-wide snapshot of the signed-in user's role, readable
/// synchronously.
///
/// `GoRouter.redirect` is synchronous and cannot await a profile lookup, so the
/// role is resolved once by `AdminRoleController` and cached here for the
/// guard to consult. Lives in its own leaf library so both the router and the
/// controller can depend on it without importing each other.
///
/// The cache starts at [UserRole.learner] and is only ever widened by a
/// successful lookup, so an unresolved or failed refresh leaves access denied.
class SessionRole {
  SessionRole._();

  static UserRole _role = UserRole.learner;

  /// Last role resolved for the current session.
  static UserRole get current => _role;

  /// Whether the cached role may reach the admin area.
  static bool get isAdmin => _role.isAdmin;

  /// Publishes a freshly resolved role to the router guard.
  static void update(UserRole role) {
    _role = role;
  }

  /// Drops back to the least-privileged role.
  ///
  /// Called on sign-out and whenever a new session starts, so a previous
  /// user's admin access can never leak into the next account that signs in.
  static void clear() {
    _role = UserRole.learner;
  }
}
