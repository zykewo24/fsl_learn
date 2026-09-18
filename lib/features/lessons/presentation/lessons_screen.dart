import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/lesson_level_model.dart';
import '../../../models/progress_snapshot_model.dart';
import '../../../providers/lesson_provider.dart';
import '../controller/lessons_controller.dart';
import '../widgets/difficulty_toggle.dart';
import '../widgets/learning_path_card.dart';
import '../widgets/module_card.dart';
import '../widgets/search_lessons.dart';

class LessonsScreen extends ConsumerWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final levelsAsync = ref.watch(lessonLevelsProvider);
    final snapshotAsync = ref.watch(progressSnapshotProvider);
    final selectedLevelId = ref.watch(selectedLevelProvider);
    final searchController = ref.watch(searchControllerProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: levelsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(lessonLevelsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (levels) {
            if (levels.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined, size: 64, color: AppColors.subtitle),
                    SizedBox(height: 16),
                    Text(
                      'No lesson levels found.',
                      style: TextStyle(color: AppColors.subtitle, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            LessonLevelModel selectedLevel = levels.firstWhere(
              (level) => level.id == selectedLevelId,
              orElse: () => levels.first,
            );

            final modulesAsync = ref.watch(
              lessonModulesProvider(selectedLevel.id),
            );

            return modulesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text(error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(
                        lessonModulesProvider(selectedLevel.id),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (modules) {
                final snapshot = snapshotAsync.valueOrNull ??
                    const ProgressSnapshotModel(
                      levels: [],
                      modules: [],
                      lessons: [],
                      signProgress: {},
                    );

                final levelProgress = snapshot.levels
                    .where((level) => level.id == selectedLevel.id)
                    .toList();

                final levelModules =
                    snapshot.modulesForLevel(selectedLevel.id);

                final completedLessons = levelModules.fold(
                  0,
                  (sum, module) => sum + module.completedLessons,
                );

                final totalLevelLessons = levelModules.fold(
                  0,
                  (sum, module) => sum + module.totalLessons,
                );

                final levelCompletion = levelProgress.isEmpty
                    ? 0.0
                    : levelProgress.first.progress;

                final filteredModules = modules.where((module) {
                  if (searchQuery.isEmpty) return true;
                  final q = searchQuery.toLowerCase();
                  return module.title.toLowerCase().contains(q) ||
                      module.description.toLowerCase().contains(q);
                }).toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(lessonLevelsProvider);
                    ref.invalidate(lessonModulesProvider(selectedLevel.id));
                    ref.invalidate(progressSnapshotProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      // Title
                      Text(
                        'Lessons',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Stats overview
                      _StatsOverview(snapshot: snapshot),

                      const SizedBox(height: 20),

                      // Difficulty toggle (dynamic from levels)
                      DifficultyToggle(
                        levels: levels,
                        selectedLevel: selectedLevel.id,
                        onChanged: (value) {
                          ref.read(selectedLevelProvider.notifier).state =
                              value;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Learning path card
                      LearningPathCard(
                        title: selectedLevel.name,
                        description: selectedLevel.description,
                        progress: levelCompletion,
                        completedLessons: completedLessons,
                        totalLessons: totalLevelLessons > 0
                            ? totalLevelLessons
                            : filteredModules.fold(
                                0,
                                (sum, module) =>
                                    sum + module.totalLessons,
                              ),
                        streakDays: snapshot.streakDays,
                        onContinue: () {
                          final moduleIds = levelModules
                              .map((module) => module.id)
                              .toSet();

                          ProgressLesson? nextLesson;

                          for (final lesson in snapshot.lessons) {
                            if (moduleIds.contains(lesson.moduleId) &&
                                lesson.totalSigns > 0 &&
                                lesson.progress < 1.0) {
                              nextLesson = lesson;
                              break;
                            }
                          }

                          if (nextLesson != null) {
                            context.push(
                              AppRoutes.lessonDetails,
                              extra: nextLesson.toLessonModel(),
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 20),

                      // Search
                      SearchLessons(
                        controller: searchController,
                        onChanged: (value) {
                          ref.read(searchQueryProvider.notifier).state =
                              value;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Section header
                      Row(
                        children: [
                          const Text(
                            'Modules',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${filteredModules.length}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (filteredModules.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  searchQuery.isNotEmpty
                                      ? Icons.search_off
                                      : Icons.menu_book_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchQuery.isNotEmpty
                                      ? 'No modules match "$searchQuery"'
                                      : 'No modules found.',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      ...filteredModules.map((module) {
                        final moduleProgress = snapshot.modules
                            .where((item) => item.id == module.id)
                            .toList();

                        final moduleProg = moduleProgress.isNotEmpty
                            ? moduleProgress.first
                            : null;

                        final moduleLessons =
                            snapshot.lessonsForModule(module.id);

                        return ModuleCard(
                          moduleId: module.id,
                          title: module.title,
                          description: module.description,
                          totalLessons: module.totalLessons,
                          completedLessons:
                              moduleProg?.completedLessons ?? 0,
                          progress: moduleProg?.progress ?? 0,
                          moduleProgressLessons: moduleLessons,
                          onContinue: () {
                            ProgressLesson? target;

                            for (final lesson in moduleLessons) {
                              if (lesson.totalSigns > 0 &&
                                  lesson.progress < 1.0) {
                                target = lesson;
                                break;
                              }
                            }

                            target ??= moduleLessons
                                .where((lesson) => lesson.totalSigns > 0)
                                .toList()
                                .firstOrNull;

                            if (target != null) {
                              context.push(
                                AppRoutes.lessonDetails,
                                extra: target.toLessonModel(),
                              );
                            }
                          },
                          onLessonTap: (lesson) {
                            context.push(
                              AppRoutes.lessonDetails,
                              extra: lesson,
                            );
                          },
                        );
                      }),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats overview row
// ---------------------------------------------------------------------------

class _StatsOverview extends StatelessWidget {
  final ProgressSnapshotModel snapshot;
  const _StatsOverview({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.sign_language,
          value: '${snapshot.practicedSignCount}',
          label: 'Practiced',
          color: AppColors.secondary,
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.local_fire_department,
          value: '${snapshot.streakDays}',
          label: 'Day streak',
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.star_rounded,
          value: '${(snapshot.bestAverageScore * 100).toInt()}%',
          label: 'Best avg',
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}