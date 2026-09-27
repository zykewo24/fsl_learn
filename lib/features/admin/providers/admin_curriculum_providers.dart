import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/lesson_level_model.dart';
import '../../../models/lesson_model.dart';
import '../../../models/lesson_module_model.dart';
import '../../../models/lesson_sign_model.dart';
import 'admin_providers.dart';

/// Curriculum tree readers for the admin authoring screen.
///
/// The screen drills down level -> module -> lesson -> sign, so each level is a
/// family keyed by its parent's id.

final adminLevelsProvider = FutureProvider<List<LessonLevelModel>>((ref) {
  return ref.read(adminServiceProvider).getLevels();
});

final adminModulesProvider =
    FutureProvider.family<List<LessonModuleModel>, int>((ref, levelId) {
  return ref.read(adminServiceProvider).getModules(levelId);
});

final adminLessonsProvider =
    FutureProvider.family<List<LessonModel>, String>((ref, moduleId) {
  return ref.read(adminServiceProvider).getLessons(moduleId);
});

final adminSignsProvider =
    FutureProvider.family<List<LessonSignModel>, String>((ref, lessonId) {
  return ref.read(adminServiceProvider).getSigns(lessonId);
});

/// Drops every curriculum cache after a write.
///
/// Invalidating the families themselves (rather than one instance each) clears
/// every branch currently on screen. That is deliberate: a lesson's displayed
/// `total_signs`, its module's `total_lessons` and the level list are all
/// denormalised counts maintained by database triggers, so a write anywhere in
/// the tree can change any of them and the exact dependency is not worth
/// tracking in the client. The refetch is scoped to the expanded branch.
void invalidateCurriculum(WidgetRef ref) {
  ref.invalidate(adminLevelsProvider);
  ref.invalidate(adminModulesProvider);
  ref.invalidate(adminLessonsProvider);
  ref.invalidate(adminSignsProvider);
}
