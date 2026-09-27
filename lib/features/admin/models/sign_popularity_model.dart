/// How heavily a single sign is practised across all learners.
///
/// Powers the "most practised signs" ranking on the admin overview so a
/// curriculum owner can spot signs that are either very popular or dead
/// content.
class SignPopularityModel {
  final String signId;

  /// Sign title, falling back to the AI label when the title is blank.
  final String title;

  /// Distinct learners who have a progress row for this sign.
  final int learnerCount;

  /// Sum of `practice_count` across those learners.
  final int practiceCount;

  /// Number of learners who marked the sign completed.
  final int completedCount;

  const SignPopularityModel({
    required this.signId,
    required this.title,
    required this.learnerCount,
    required this.practiceCount,
    required this.completedCount,
  });

  factory SignPopularityModel.fromMap(Map<String, dynamic> map) {
    return SignPopularityModel(
      signId: map['sign_id'] as String,
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? (map['title'] as String).trim()
          : ((map['ai_label'] as String?) ?? 'Untitled sign'),
      learnerCount: _asInt(map['learner_count']),
      practiceCount: _asInt(map['practice_count']),
      completedCount: _asInt(map['completed_count']),
    );
  }

  /// Share of learners who completed this sign (0..1), or `null` when the sign
  /// has been attempted by nobody.
  double? get completionRate {
    if (learnerCount <= 0) return null;
    return completedCount / learnerCount;
  }

  static int _asInt(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }
}
