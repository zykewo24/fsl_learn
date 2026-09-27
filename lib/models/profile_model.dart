import '../features/admin/models/user_role.dart';

class ProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;

  /// Access level. Defaults to [UserRole.learner] so callers that predate the
  /// `role` column keep working and can never over-estimate privileges.
  final UserRole role;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    this.role = UserRole.learner,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.fromValue(json['role']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
      'role': role.value,
    };
  }

  ProfileModel copyWith({
    String? fullName,
    String? avatarUrl,
    UserRole? role,
  }) {
    return ProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
    );
  }
}