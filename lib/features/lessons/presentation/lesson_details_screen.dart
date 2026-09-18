import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/lesson_model.dart';
import '../../../providers/lesson_provider.dart';
import '../../ai_practice/models/practice_session_args.dart';
import '../widgets/lesson_sign_card.dart';

class LessonDetailsScreen extends ConsumerWidget {
  final LessonModel lesson;

  const LessonDetailsScreen({
    super.key,
    required this.lesson,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final signsAsync = ref.watch(lessonSignsProvider(lesson.id));
    final progressAsync = ref.watch(lessonProgressProvider(lesson.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(lesson.title),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lessonSignsProvider(lesson.id));
          ref.invalidate(lessonProgressProvider(lesson.id));
        },
        child: signsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(lessonSignsProvider(lesson.id)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (signs) {
            if (signs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sign_language,
                        size: 64, color: AppColors.subtitle),
                    SizedBox(height: 16),
                    Text(
                      'No signs available.',
                      style:
                          TextStyle(color: AppColors.subtitle, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            return progressAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text(error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(lessonProgressProvider(lesson.id)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (progressData) {
                final completed =
                    progressData['completed'] as int? ?? 0;

                final progressMap =
                    ((progressData['progress'] ??
                                <String, Map<String, dynamic>>{})
                            as Map<String, dynamic>)
                        .cast<String, Map<String, dynamic>>();

                final progress =
                    signs.isEmpty ? 0.0 : completed / signs.length;

                final allComplete = completed >= signs.length;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header gradient card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary
                                .withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lesson.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                allComplete
                                    ? Icons.emoji_events
                                    : Icons.sign_language,
                                size: 32,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lesson.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$completed / ${signs.length} signs completed',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Start AI Practice button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.videocam),
                        label: Text(
                          allComplete
                              ? 'Review Lesson'
                              : 'Start AI Practice',
                        ),
                        onPressed: () {
                          context.push(
                            AppRoutes.practiceSession,
                            extra: lesson,
                          );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section header
                    Row(
                      children: [
                        const Text(
                          'Signs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${signs.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    ...signs.asMap().entries.map((entry) {
                      final sign = entry.value;
                      final signProgress = progressMap[sign.id];

                      return LessonSignCard(
                        sign: sign,
                        progress: signProgress,
                        index: entry.key,
                        onPractice: () {
                          context.push(
                            AppRoutes.practiceSession,
                            extra: PracticeSessionArgs(
                              lesson: lesson,
                              signId: sign.id,
                            ),
                          );
                        },
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}