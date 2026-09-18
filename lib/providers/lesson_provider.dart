import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/lesson_service.dart';
import '../models/lesson_level_model.dart';
import '../models/lesson_model.dart';
import '../models/lesson_module_model.dart';
import '../models/lesson_sign_model.dart';
import '../models/progress_snapshot_model.dart';

/// ==========================================================
/// SERVICE
/// ==========================================================

final lessonServiceProvider = Provider<LessonService>((ref) {
  return LessonService();
});

/// ==========================================================
/// LEVELS
/// ==========================================================

final lessonLevelsProvider =
    FutureProvider<List<LessonLevelModel>>((ref) {
  return ref.read(lessonServiceProvider).getLevels();
});

/// ==========================================================
/// MODULES
/// ==========================================================

final lessonModulesProvider =
    FutureProvider.family<List<LessonModuleModel>, int>(
  (ref, levelId) {
    return ref.read(lessonServiceProvider).getModules(levelId);
  },
);

/// ==========================================================
/// LESSONS
/// ==========================================================

final lessonsProvider =
    FutureProvider.family<List<LessonModel>, String>(
  (ref, moduleId) {
    return ref.read(lessonServiceProvider).getLessons(moduleId);
  },
);

/// ==========================================================
/// LESSON SIGNS
/// ==========================================================

final lessonSignsProvider =
    FutureProvider.family<List<LessonSignModel>, String>(
  (ref, lessonId) {
    return ref
        .read(lessonServiceProvider)
        .getLessonSigns(lessonId);
  },
);

/// ==========================================================
/// LESSON PROGRESS
/// Returns:
/// {
///   completed: int,
///   progress: `Map<String, Map<String, dynamic>>`
/// }
/// ==========================================================

final lessonProgressProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, lessonId) {
    return ref
        .read(lessonServiceProvider)
        .getLessonProgress(lessonId);
  },
);

/// ==========================================================
/// OVERALL PROGRESS SNAPSHOT
/// ==========================================================

final progressSnapshotProvider =
    FutureProvider<ProgressSnapshotModel>((ref) {
  return ref
      .read(lessonServiceProvider)
      .getProgressSnapshot();
});