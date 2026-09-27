/// Aggregate health of the learning system, shown on the admin overview.
///
/// Every field is nullable: the dashboard renders "—" for a metric the
/// database could not supply rather than showing a misleading `0`. Counts
/// always resolve because they come from `count(*)`-style aggregates.
class SystemStatsModel {
  /// Total accounts in `profiles`, including admins.
  final int totalUsers;

  /// Accounts holding the admin role.
  final int adminUsers;

  /// Accounts that hold the learner role.
  final int learnerUsers;

  /// Learners with at least one `user_sign_progress` row.
  final int activeLearners;

  /// Learners who have not practised a single sign.
  final int inactiveLearners;

  /// Active `lesson_signs` rows.
  final int totalSigns;

  /// Signs at least one learner has mastered.
  final int signsPractised;

  /// Count of `lesson_levels` rows.
  final int totalLevels;

  /// Count of `lesson_modules` rows.
  final int totalModules;

  /// Count of `lessons` rows.
  final int totalLessons;

  /// Count of `lesson_signs` rows in total, including deactivated ones.
  final int totalSignRows;

  const SystemStatsModel({
    required this.totalUsers,
    required this.adminUsers,
    required this.learnerUsers,
    required this.activeLearners,
    required this.inactiveLearners,
    required this.totalSigns,
    required this.signsPractised,
    required this.totalLevels,
    required this.totalModules,
    required this.totalLessons,
    required this.totalSignRows,
  });

  factory SystemStatsModel.fromMap(Map<String, dynamic> map) {
    final totalUsers = _asInt(map['total_users']);
    final activeLearners = _asInt(map['active_learners']);
    final totalSigns = _asInt(map['total_signs']);
    final signsPractised = _asInt(map['signs_practised']);

    final learnerUsers = _asInt(map['learner_users']);

    return SystemStatsModel(
      totalUsers: totalUsers,
      adminUsers: _asInt(map['admin_users']),
      learnerUsers: learnerUsers,
      activeLearners: activeLearners,
      inactiveLearners: _asInt(map['inactive_learners']),
      totalSigns: totalSigns,
      signsPractised: signsPractised,
      totalLevels: _asInt(map['total_levels']),
      totalModules: _asInt(map['total_modules']),
      totalLessons: _asInt(map['total_lessons']),
      totalSignRows: _asInt(map['total_sign_rows']),
    );
  }

  /// Placeholder used while loading or after a failed request.
  static const SystemStatsModel empty = SystemStatsModel(
    totalUsers: 0,
    adminUsers: 0,
    learnerUsers: 0,
    activeLearners: 0,
    inactiveLearners: 0,
    totalSigns: 0,
    signsPractised: 0,
    totalLevels: 0,
    totalModules: 0,
    totalLessons: 0,
    totalSignRows: 0,
  );

  /// Share of [activeLearners] among [learnerUsers] (0..1). `null` when there
  /// are no learners at all, since the ratio is undefined for a zero base.
  double? get activeRate => _ratio(activeLearners, learnerUsers);

  /// Share of [signsPractised] among [totalSigns] (0..1), or `null` when no
  /// active signs exist.
  double? get signCoverage => _ratio(signsPractised, totalSigns);

  /// Percentage form of [activeRate], or `null` when undefined.
  int? get activeRatePercent => _asPercent(activeRate);

  /// Percentage form of [signCoverage], or `null` when undefined.
  int? get signCoveragePercent => _asPercent(signCoverage);

  static int? _asPercent(double? value) =>
      value == null ? null : (value * 100).round();

  /// Returns `numerator / denominator`, or `null` when the denominator is zero.
  static double? _ratio(int numerator, int denominator) {
    if (denominator <= 0) return null;
    return numerator / denominator;
  }

  static int _asInt(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }
}
