class UserSignProgressModel {
  final String signId;
  final bool completed;
  final int masteryLevel;
  final int practiceCount;
  final double bestScore;

  const UserSignProgressModel({
    required this.signId,
    required this.completed,
    required this.masteryLevel,
    required this.practiceCount,
    required this.bestScore,
  });

  factory UserSignProgressModel.fromMap(
    Map<String, dynamic> json,
  ) {
    return UserSignProgressModel(
      signId: json['sign_id'],
      completed: json['completed'] ?? false,
      masteryLevel: json['mastery_level'] ?? 0,
      practiceCount: json['practice_count'] ?? 0,
      bestScore: (json['best_score'] ?? 0).toDouble(),
    );
  }
}