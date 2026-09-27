import 'user_role.dart';

/// A learner account plus the progress rollup an admin needs to triage it.
///
/// Assembled by [AdminService.listUsers] from a `profiles` left-joined to an
/// aggregate over `user_sign_progress`, so one round trip returns the whole
/// list. Progress columns are nullable because a learner who has never
/// practised has no `user_sign_progress` rows at all.
class AdminUserModel {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final DateTime? createdAt;

  /// Signs this learner has mastered, or `null` when unknown.
  final int? masteredSigns;

  /// Total practice attempts recorded for this learner, or `null` when unknown.
  final int? practiceCount;

  /// Mean of the learner's best per-sign scores (0..1), or `null` when the
  /// learner has no graded practice yet.
  final double? averageScore;

  /// Timestamp of their most recent practice, or `null` if never practised.
  final DateTime? lastPracticedAt;

  const AdminUserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.createdAt,
    this.masteredSigns,
    this.practiceCount,
    this.averageScore,
    this.lastPracticedAt,
  });

  factory AdminUserModel.fromMap(Map<String, dynamic> map) {
    return AdminUserModel(
      id: map['id'] as String,
      fullName: (map['full_name'] as String?)?.trim().isNotEmpty == true
          ? (map['full_name'] as String).trim()
          : 'Unnamed learner',
      email: (map['email'] as String?) ?? '',
      role: UserRole.fromValue(map['role']),
      createdAt: _parseDate(map['created_at']),
      masteredSigns: _parseInt(map['mastered_signs']),
      practiceCount: _parseInt(map['practice_count']),
      averageScore: _parseDouble(map['average_score']),
      lastPracticedAt: _parseDate(map['last_practiced_at']),
    );
  }

  /// Whether this learner has ever practised a sign.
  bool get hasActivity => (practiceCount ?? 0) > 0;

  /// Best score as a percentage, or `null` when the learner has no scores.
  int? get averageScorePercent {
    final score = averageScore;
    if (score == null) return null;
    return (score * 100).round();
  }

  /// Number of completed signs, or 0 when unknown.
  int get masteredCount => masteredSigns ?? 0;

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static int? _parseInt(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static double? _parseDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}
