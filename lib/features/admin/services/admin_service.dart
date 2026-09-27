import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/with_retry.dart';
import '../../../models/lesson_level_model.dart';
import '../../../models/lesson_model.dart';
import '../../../models/lesson_module_model.dart';
import '../../../models/lesson_sign_model.dart';
import '../models/admin_page.dart';
import '../models/admin_user_model.dart';
import '../models/audit_log_model.dart';
import '../models/curriculum_drafts.dart';
import '../models/sign_popularity_model.dart';
import '../models/system_stats_model.dart';
import '../models/user_role.dart';
import 'row_payload.dart';

/// Data access for the admin area: system analytics, learner management,
/// curriculum authoring and the moderation log.
///
/// Every write here is additionally gated by the Postgres RLS policies in
/// `supabase/admin_roles_and_rls.sql`, so a client that skips the in-app role
/// checks still cannot reach these tables. Reads use [withTransientJwtRetry]
/// for the same reason the learner-facing services do.
class AdminService {
  AdminService(this._supabase);

  final SupabaseClient _supabase;

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  /// Matches PostgREST's own missing-RPC error, which is what a client hits
  /// when `supabase/admin_roles_and_rls.sql` has not been applied yet.
  static const String _missingRpcCodes = 'PGRST202';

  // ==========================================================
  // ANALYTICS
  // ==========================================================

  /// Aggregate counts for the admin overview.
  ///
  /// Delegated to the `admin_system_stats()` SQL function because the
  /// distinct-learner and distinct-sign figures cannot be expressed as a
  /// PostgREST filter. Throws a migration hint if that function is missing.
  Future<SystemStatsModel> getSystemStats() async {
    try {
      final data = await withTransientJwtRetry(
        () => _supabase.rpc('admin_system_stats'),
      );

      final row = firstRow(data);

      if (row == null) return SystemStatsModel.empty;

      return SystemStatsModel.fromMap(row);
    } on PostgrestException catch (error) {
      if (error.code == _missingRpcCodes) {
        throw const AdminSetupException(
          'Admin analytics are unavailable because the database is missing the '
          'admin_system_stats() function. Apply '
          'supabase/admin_roles_and_rls.sql in the Supabase SQL Editor.',
        );
      }
      rethrow;
    }
  }

  /// Signs ranked by total practice attempts across all learners.
  ///
  /// Backed by the `admin_top_signs()` SQL function for the same reason as
  /// [getSystemStats].
  Future<List<SignPopularityModel>> getTopSigns({int limit = 5}) async {
    try {
      final data = await withTransientJwtRetry(
        () => _supabase.rpc('admin_top_signs', params: {'row_limit': limit}),
      );

      return normaliseRows(data)
          .map(SignPopularityModel.fromMap)
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.code == _missingRpcCodes) {
        throw const AdminSetupException(
          'Sign rankings are unavailable because the database is missing the '
          'admin_top_signs() function. Apply '
          'supabase/admin_roles_and_rls.sql in the Supabase SQL Editor.',
        );
      }
      rethrow;
    }
  }

  // ==========================================================
  // LEARNER MANAGEMENT
  // ==========================================================

  /// Lists profiles newest-first with a per-learner progress rollup.
  ///
  /// Runs as two queries: one paged read of `profiles`, then a single read of
  /// `user_sign_progress` restricted to just the [page] of learners on this
  /// page. Filtering the second query by the returned ids keeps the row count
  /// bounded by the page size instead of the whole history table, and avoids
  /// depending on a foreign-key relationship existing between the two tables
  /// (so this keeps working on the existing schema, which has no declared FK
  /// between them).
  Future<AdminPage<AdminUserModel>> listUsers({
    String search = '',
    UserRole? role,
    int page = 0,
    int pageSize = 20,
  }) async {
    final term = _sanitizeSearch(search);

    final response = await withTransientJwtRetry(() {
      // Filters must be applied before order()/range(), which hand off to the
      // transform stage where the filter methods no longer exist.
      var query = _supabase
          .from('profiles')
          .select('id, full_name, email, role, created_at');

      if (role != null) {
        query = query.eq('role', role.value);
      }

      if (term.isNotEmpty) {
        query = query.or('full_name.ilike.*$term*,email.ilike.*$term*');
      }

      return query
          .order('created_at', ascending: false)
          .range(page * pageSize, page * pageSize + pageSize - 1)
          .count(CountOption.exact);
    });

    final rows = response.data;
    final total = response.count;

    final byUser = await _rollupProgress(
      rows.map((row) => row['id'] as String).toList(growable: false),
    );

    final users = rows.map((row) {
      final id = row['id'] as String;
      return AdminUserModel.fromMap({...row, ...byUser[id] ?? const {}});
    }).toList(growable: false);

    return AdminPage(
      items: users,
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Aggregates `user_sign_progress` for [userIds] into the extra columns
  /// [AdminUserModel.fromMap] understands.
  ///
  /// Returns an empty map when there are no users, because PostgREST rejects an
  /// empty `in` filter.
  Future<Map<String, Map<String, dynamic>>> _rollupProgress(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};

    final rows = await withTransientJwtRetry(
      () => _supabase
          .from('user_sign_progress')
          .select('user_id, completed, practice_count, best_score, last_practiced_at')
          .inFilter('user_id', userIds),
    );

    // Accumulate per user in one pass so the result stays linear in the number
    // of progress rows rather than scanning the list per row.
    final mastered = <String, int>{};
    final practices = <String, int>{};
    final scoreTotals = <String, double>{};
    final scoreCounts = <String, int>{};
    final lastPracticed = <String, DateTime>{};

    for (final row in rows) {
      final userId = row['user_id'] as String?;
      if (userId == null) continue;

      if (row['completed'] == true) {
        mastered[userId] = (mastered[userId] ?? 0) + 1;
      }

      final count = (row['practice_count'] as num?)?.toInt() ?? 0;
      practices[userId] = (practices[userId] ?? 0) + count;

      final score = (row['best_score'] as num?)?.toDouble();
      if (score != null) {
        scoreTotals[userId] = (scoreTotals[userId] ?? 0) + score;
        scoreCounts[userId] = (scoreCounts[userId] ?? 0) + 1;
      }

      final practised = DateTime.tryParse(
        (row['last_practiced_at'] as String?) ?? '',
      );
      if (practised != null) {
        final previous = lastPracticed[userId];
        if (previous == null || practised.isAfter(previous)) {
          lastPracticed[userId] = practised;
        }
      }
    }

    final result = <String, Map<String, dynamic>>{};

    for (final userId in userIds) {
      final scoreCount = scoreCounts[userId] ?? 0;

      result[userId] = {
        'mastered_signs': mastered[userId] ?? 0,
        'practice_count': practices[userId] ?? 0,
        'average_score': scoreCount == 0
            ? null
            : (scoreTotals[userId] ?? 0) / scoreCount,
        'last_practiced_at': lastPracticed[userId]?.toIso8601String(),
      };
    }

    return result;
  }

  /// Changes a learner's role.
  ///
  /// Refuses to demote the account making the request, which would otherwise
  /// let the last admin lock every admin out of the app with no way back in
  /// from the client. The database enforces the same rule (see
  /// `prevent_last_admin_demotion` in the migration), so this is a fast local
  /// failure rather than the only line of defence.
  Future<void> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    if (role == UserRole.learner && userId == _currentUserId) {
      throw const AdminActionException(
        'You cannot remove your own admin access. Ask another admin to do it.',
      );
    }

    await withTransientJwtRetry(
      () => _supabase
          .from('profiles')
          .update({'role': role.value})
          .eq('id', userId),
    );
  }

  // ==========================================================
  // CURRICULUM AUTHORING
  // ==========================================================

  /// All levels, ordered for display.
  Future<List<LessonLevelModel>> getLevels() async {
    final rows = await withTransientJwtRetry(
      () => _supabase
          .from('lesson_levels')
          .select()
          .order('sort_order')
          .order('id'),
    );
    return normaliseRows(rows).map(LessonLevelModel.fromJson).toList(growable: false);
  }

  /// Modules belonging to [levelId], ordered for display.
  Future<List<LessonModuleModel>> getModules(int levelId) async {
    final rows = await withTransientJwtRetry(
      () => _supabase
          .from('lesson_modules')
          .select()
          .eq('level_id', levelId)
          .order('sort_order')
          .order('id'),
    );
    return normaliseRows(rows)
        .map(LessonModuleModel.fromJson)
        .toList(growable: false);
  }

  /// Lessons belonging to [moduleId], ordered for display.
  Future<List<LessonModel>> getLessons(String moduleId) async {
    final rows = await withTransientJwtRetry(
      () => _supabase
          .from('lessons')
          .select()
          .eq('module_id', moduleId)
          .order('sort_order')
          .order('id'),
    );
    return normaliseRows(rows).map(LessonModel.fromJson).toList(growable: false);
  }

  /// Signs belonging to [lessonId].
  ///
  /// Unlike the learner-facing `LessonService.getLessonSigns` this does **not**
  /// filter on `is_active`, because an admin needs to see deactivated signs in
  /// order to reactivate them.
  Future<List<LessonSignModel>> getSigns(String lessonId) async {
    final rows = await withTransientJwtRetry(
      () => _supabase
          .from('lesson_signs')
          .select()
          .eq('lesson_id', lessonId)
          .order('sort_order')
          .order('id'),
    );
    return normaliseRows(rows)
        .map(LessonSignModel.fromMap)
        .toList(growable: false);
  }

  Future<void> createLevel(LevelDraft draft) => _insert('lesson_levels', draft.toRow());

  Future<void> createModule(ModuleDraft draft) => _insert('lesson_modules', draft.toRow());

  Future<void> createLesson(LessonDraft draft) => _insert('lessons', draft.toRow());

  Future<void> createSign(SignDraft draft) => _insert('lesson_signs', draft.toRow());

  /// Updates one curriculum row by primary key.
  ///
  /// Takes an [Object] id for the same reason as [deleteRow]: `lesson_levels.id`
  /// is an integer and PostgREST must receive the value's real type to build a
  /// matching filter.
  Future<void> updateLevel(Object id, LevelDraft draft) =>
      _update('lesson_levels', id, draft.toRow());

  Future<void> updateModule(String id, ModuleDraft draft) =>
      _update('lesson_modules', id, draft.toRow());

  Future<void> updateLesson(String id, LessonDraft draft) =>
      _update('lessons', id, draft.toRow());

  Future<void> updateSign(String id, SignDraft draft) =>
      _update('lesson_signs', id, draft.toRow());

  /// Deletes a row by primary key.
  ///
  /// [id] is an [Object] rather than a [String] because `lesson_levels.id` is
  /// an integer column while the other three tables use UUIDs; PostgREST needs
  /// the value's real type to build a matching filter.
  ///
  /// Deleting curriculum content cascades to its children and orphans the
  /// `user_sign_progress` rows that referenced it, so callers should confirm
  /// with the learner first. Deactivating a sign is the softer alternative and
  /// is what the UI offers by default.
  Future<void> deleteRow(String table, Object id) async {
    _assertCurriculumTable(table);

    await withTransientJwtRetry(
      () => _supabase.from(table).delete().eq('id', id),
    );
  }

  /// Sets the `is_active` flag on a `lesson_signs` row.
  ///
  /// Deactivating hides a sign from learners and from practice sessions while
  /// keeping it and its accumulated progress intact.
  Future<void> setSignActive(String signId, bool isActive) async {
    await withTransientJwtRetry(
      () => _supabase
          .from('lesson_signs')
          .update({'is_active': isActive})
          .eq('id', signId),
    );
  }

  /// Rewrites `sort_order` for [table] so the rows appear in the given order.
  ///
  /// [orderedIds] must contain every id in the parent scope being reordered,
  /// each with its real database type: `lesson_levels.id` is an integer and the
  /// other three tables use UUIDs, and PostgREST needs the value's real type to
  /// build a matching filter. Writes are issued sequentially because a single
  /// multi-row update cannot express different values per row, and the counts
  /// here are small (a lesson's signs, not the whole curriculum).
  ///
  /// Pass [parentColumn]/[parentValue] to scope the updates to one parent, so a
  /// reorder can never renumber a sibling scope's rows.
  Future<void> reorderRows(
    String table,
    List<Object> orderedIds, {
    String? parentColumn,
    Object? parentValue,
  }) async {
    _assertCurriculumTable(table);

    if (parentColumn != null && parentValue == null) {
      throw ArgumentError.notNull('parentValue');
    }

    for (var index = 0; index < orderedIds.length; index++) {
      var query = _supabase
          .from(table)
          .update({'sort_order': index + 1})
          .eq('id', orderedIds[index]);

      if (parentColumn != null) {
        query = query.eq(parentColumn, parentValue as Object);
      }

      await withTransientJwtRetry(() => query);
    }
  }

  Future<void> _insert(String table, Map<String, dynamic> row) async {
    _assertCurriculumTable(table);
    await withTransientJwtRetry(() => _supabase.from(table).insert(row));
  }

  Future<void> _update(
    String table,
    Object id,
    Map<String, dynamic> row,
  ) async {
    _assertCurriculumTable(table);
    await withTransientJwtRetry(
      () => _supabase.from(table).update(row).eq('id', id),
    );
  }

  /// Restricts the table-name arguments of the generic helpers above to the
  /// curriculum tables they are meant for, so a future refactor cannot turn
  /// one of them into an arbitrary-table write.
  static void _assertCurriculumTable(String table) {
    const allowed = {
      'lesson_levels',
      'lesson_modules',
      'lessons',
      'lesson_signs',
    };

    if (!allowed.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Not a curriculum table');
    }
  }

  // ==========================================================
  // MODERATION LOG
  // ==========================================================

  /// Most recent admin actions, newest first.
  Future<List<AuditLogModel>> getAuditLog({int limit = 50}) async {
    final rows = await withTransientJwtRetry(
      () => _supabase
          .from('admin_audit_log')
          .select()
          .order('created_at', ascending: false)
          .limit(limit),
    );

    return normaliseRows(rows).map(AuditLogModel.fromMap).toList(growable: false);
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  /// Strips the characters PostgREST's `or` filter treats as syntax, so a
  /// search term like `a,b(c)` cannot alter the filter's structure.
  static String _sanitizeSearch(String raw) {
    final term = raw.replaceAll(RegExp(r'[,()*%\\]'), ' ').trim();
    return term;
  }

}

/// Raised when an admin action is refused for a reason the user can act on.
class AdminActionException implements Exception {
  const AdminActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Raised when the database is missing the schema this feature needs.
///
/// [AdminService] cannot create its own aggregates through PostgREST, so this
/// is surfaced as an explicit setup instruction instead of a silent zero-filled
/// dashboard that would look like an empty system.
class AdminSetupException implements Exception {
  const AdminSetupException(this.message);

  final String message;

  @override
  String toString() => message;
}
