import '../../admin/models/user_role.dart';

/// The profile row as the profile screen sees it.
///
/// A second `ProfileModel` exists at `lib/models/profile_model.dart` for the
/// auth and settings layers. Both parse the same table, so both carry `role`
/// rather than letting the two drift apart.
class ProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  /// Access level. Defaults to [UserRole.learner] for the same fail-closed
  /// reason as [UserRole.fromValue]: a row written before the column existed
  /// must never be read as an admin.
  final UserRole role;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.avatarUrl,
    required this.createdAt,
    this.role = UserRole.learner,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
      role: UserRole.fromValue(map['role']),
    );
  }
}