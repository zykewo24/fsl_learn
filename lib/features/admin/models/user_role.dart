/// Access level of a profile.
///
/// Persisted in the `profiles.role` column as a lowercase string. See
/// `supabase/admin_roles_and_rls.sql` for the column, the check constraint and
/// the RLS policies that enforce it server-side.
///
/// [UserRole.learner] is the default for every account, so a missing, NULL or
/// unrecognised value can never accidentally grant admin rights.
enum UserRole {
  learner('learner', 'Learner'),
  admin('admin', 'Admin');

  const UserRole(this.value, this.label);

  /// Database representation written to `profiles.role`.
  final String value;

  /// Human-readable name used in badges and dialogs.
  final String label;

  /// Whether this role may reach the admin area.
  bool get isAdmin => this == UserRole.admin;

  /// Parses a raw `profiles.role` value.
  ///
  /// Falls back to [UserRole.learner] for anything unrecognised (including
  /// NULL, non-string values and future roles added server-side) so a
  /// malformed row degrades to the least-privileged role instead of throwing.
  static UserRole fromValue(Object? raw) {
    if (raw is! String) return UserRole.learner;

    final normalized = raw.trim().toLowerCase();

    for (final role in UserRole.values) {
      if (role.value == normalized) return role;
    }

    return UserRole.learner;
  }
}
