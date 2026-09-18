import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/lesson_level_model.dart';
import '../../models/lesson_model.dart';
import '../../models/lesson_module_model.dart';
import '../../models/lesson_sign_model.dart';
import '../../models/progress_snapshot_model.dart';
import '../utils/with_retry.dart';

class LessonService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================================================
  // LEVELS
  // ==========================================================

  Future<List<LessonLevelModel>> getLevels() async {
    return withTransientJwtRetry(() async {
      final response = await _supabase
          .from('lesson_levels')
          .select()
          .order('sort_order');

      return response
          .map<LessonLevelModel>(
            (json) => LessonLevelModel.fromJson(json),
          )
          .toList();
    });
  }

  // ==========================================================
  // MODULES
  // ==========================================================

  Future<List<LessonModuleModel>> getModules(int levelId,) async {
    return withTransientJwtRetry(() async {
      final response = await _supabase
          .from('lesson_modules')
          .select()
          .eq('level_id', levelId)
          .order('sort_order');

      return response
          .map<LessonModuleModel>(
            (json) => LessonModuleModel.fromJson(json),
          )
          .toList();
    });
  }

  // ==========================================================
  // LESSONS
  // ==========================================================

  Future<List<LessonModel>> getLessons(
    String moduleId,
  ) async {
    return withTransientJwtRetry(() async {
      final response = await _supabase
          .from('lessons')
          .select()
          .eq('module_id', moduleId)
          .order('sort_order');

      return response
          .map<LessonModel>(
            (json) => LessonModel.fromJson(json),
          )
          .toList();
    });
  }

  // ==========================================================
  // LESSON SIGNS
  // ==========================================================

  Future<List<LessonSignModel>> getLessonSigns(
    String lessonId,
  ) async {
    return withTransientJwtRetry(() async {
      final response = await _supabase
          .from('lesson_signs')
          .select()
          .eq('lesson_id', lessonId)
          .eq('is_active', true)
          .order('sort_order');

      return response
          .map<LessonSignModel>(
            (json) => LessonSignModel.fromMap(json),
          )
          .toList();
    });
  }

  // ==========================================================
  // PROGRESS SNAPSHOT
  // ==========================================================

  Future<ProgressSnapshotModel> getProgressSnapshot() async {
    return withTransientJwtRetry(() async {
      final levelRows = await _supabase
          .from('lesson_levels')
          .select('id, name')
          .order('sort_order');

      final moduleRows = await _supabase
          .from('lesson_modules')
          .select('id, level_id, title, total_lessons, sort_order')
          .order('sort_order');

      final lessonRows = await _supabase
          .from('lessons')
          .select(
            'id, module_id, title, description, '
            'estimated_minutes, sort_order',
          )
          .order('sort_order');

      final signRows = await _supabase
          .from('lesson_signs')
          .select('id, lesson_id, title')
          .eq('is_active', true);

      final user = _supabase.auth.currentUser;

      if (user == null) {
        return ProgressSnapshotModel.fromData(
          levelRows: levelRows,
          moduleRows: moduleRows,
          lessonRows: lessonRows,
          signRows: signRows,
          progressRows: const [],
        );
      }

      final progressRows = await _supabase
          .from('user_sign_progress')
          .select()
          .eq('user_id', user.id);

      return ProgressSnapshotModel.fromData(
        levelRows: levelRows,
        moduleRows: moduleRows,
        lessonRows: lessonRows,
        signRows: signRows,
        progressRows: progressRows,
      );
    });
  }

  // ==========================================================
  // LESSON PROGRESS
  // ==========================================================

  Future<Map<String, dynamic>> getLessonProgress(
    String lessonId,
  ) async {
    return withTransientJwtRetry(() async {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        return {
          'completed': 0,
          'progress': <String, Map<String, dynamic>>{},
        };
      }

      final signs = await _supabase
          .from('lesson_signs')
          .select('id')
          .eq('lesson_id', lessonId)
          .eq('is_active', true);

      if (signs.isEmpty) {
        return {
          'completed': 0,
          'progress': <String, Map<String, dynamic>>{},
        };
      }

      final signIds = signs
          .map<String>((e) => e['id'] as String)
          .toList();

      final progressRows = await _supabase
          .from('user_sign_progress')
          .select()
          .eq('user_id', user.id)
          .inFilter('sign_id', signIds);

      final Map<String, Map<String, dynamic>> progressMap = {};

      for (final row in progressRows) {
          progressMap[row['sign_id'] as String] =
              Map<String, dynamic>.from(row);
      }

      final completed = progressRows
          .where((row) => row['completed'] == true)
          .length;

      return {
        'completed': completed,
        'progress': progressMap,
      };
    });
  }

  // ==========================================================
  // COMPLETE SIGN
  // ==========================================================

  Future<void> completeSign({
    required String signId,
    required double score,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    final existing = await _supabase
        .from('user_sign_progress')
        .select('practice_count, best_score')
        .eq('user_id', user.id)
        .eq('sign_id', signId)
        .maybeSingle();

    final prevCount = existing?['practice_count'] as int? ?? 0;
    final prevBest = (existing?['best_score'] as num?)?.toDouble() ?? 0;

    final now = DateTime.now().toUtc();

    await _supabase.from('user_sign_progress').upsert({
      'user_id': user.id,
      'sign_id': signId,
      'completed': true,
      'mastery_level': 5,
      'practice_count': prevCount + 1,
      'best_score': score > prevBest ? score : prevBest,
      'completed_at': now.toIso8601String(),
      'last_practiced_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, onConflict: 'user_id, sign_id');
  }
}