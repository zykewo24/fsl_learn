class ProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
    };
  }
}