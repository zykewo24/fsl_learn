class ProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.avatarUrl,
    required this.createdAt,
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
    );
  }
}