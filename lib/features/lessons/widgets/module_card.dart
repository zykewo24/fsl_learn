import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/lesson_model.dart';
import '../../../models/progress_snapshot_model.dart';
import '../../../providers/lesson_provider.dart';
import 'lesson_tile.dart';

class ModuleCard extends ConsumerStatefulWidget {
  final String moduleId;
  final String title;
  final String description;
  final int totalLessons;
  final int completedLessons;
  final double progress;
  final List<ProgressLesson> moduleProgressLessons;
  final VoidCallback? onContinue;
  final Function(LessonModel)? onLessonTap;

  const ModuleCard({
    super.key,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.totalLessons,
    required this.progress,
    this.completedLessons = 0,
    this.moduleProgressLessons = const [],
    this.onContinue,
    this.onLessonTap,
  });

  @override
  ConsumerState<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends ConsumerState<ModuleCard> {
  bool _expanded = false;

  bool get _allComplete =>
      widget.totalLessons > 0 &&
      widget.completedLessons >= widget.totalLessons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final lessonsAsync = ref.watch(
      lessonsProvider(widget.moduleId),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: _allComplete
            ? Border.all(
                color: AppColors.success.withValues(alpha: 0.25),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Module icon with completion overlay
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _allComplete
                                ? AppColors.success.withValues(alpha: 0.12)
                                : theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                            child: Icon(
                              _allComplete
                                  ? Icons.check_circle_rounded
                                  : Icons.menu_book_rounded,
                              color: _allComplete
                                  ? AppColors.success
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (_allComplete)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Complete',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            Text(
                              widget.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.expand_more,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      Icon(
                        Icons.library_books_outlined,
                        size: 15,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${widget.completedLessons}/${widget.totalLessons} lessons',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        '${(widget.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _allComplete
                              ? AppColors.success
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _allComplete
                            ? AppColors.success
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onContinue,
                      icon: Icon(
                        _allComplete
                            ? Icons.replay
                            : Icons.play_arrow,
                      ),
                      label: Text(
                        _allComplete ? 'Review Module' : 'Continue Learning',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: lessonsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      error.toString(),
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
                data: (lessons) {
                  if (lessons.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No lessons available.',
                          style: TextStyle(color: AppColors.subtitle),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: lessons.asMap().entries.map((entry) {
                      final lesson = entry.value;
                      final progress = widget.moduleProgressLessons
                          .where((pl) => pl.id == lesson.id)
                          .toList();
                      final lessonProgress = progress.isNotEmpty
                          ? progress.first.progress
                          : 0.0;
                      final lessonComplete = progress.isNotEmpty &&
                          progress.first.progress >= 1.0;

                      return LessonTile(
                        lesson: lesson,
                        progress: lessonProgress,
                        completed: lessonComplete,
                        onTap: () {
                          widget.onLessonTap?.call(lesson);
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}