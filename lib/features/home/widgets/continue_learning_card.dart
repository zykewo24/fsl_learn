import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/progress_snapshot_model.dart';
import '../../../providers/lesson_provider.dart';

class ContinueLearningCard extends ConsumerWidget {
  final VoidCallback? onContinue;

  const ContinueLearningCard({super.key, this.onContinue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(progressSnapshotProvider);

    return snapshotAsync.when(
      loading: () => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, color: AppColors.subtitle, size: 28),
              const SizedBox(height: 8),
              const Text(
                "Couldn't load your learning path",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () =>
                    ref.invalidate(progressSnapshotProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (snapshot) {
        final nextLesson = snapshot.nextLesson();
        final allDone = snapshot.totalSigns > 0 && nextLesson == null;

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Continue Learning',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        color: AppColors.text,
                      ),
                    ),
                    const Spacer(),
                    _StreakChip(days: snapshot.streakDays),
                  ],
                ),
                const SizedBox(height: 16),

                if (allDone)
                  const _AllCompleteMessage()
                else ...[
                  _NextLesson(
                    lesson: nextLesson,
                    overallProgress: snapshot.overallProgress,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.completedSigns}/${snapshot.totalSigns} '
                    'signs mastered overall',
                    style: const TextStyle(
                      color: AppColors.subtitle,
                      fontSize: 13,
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onContinue,
                    icon: Icon(
                      allDone
                          ? Icons.replay
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      allDone ? 'Review Lessons' : 'Resume Learning',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NextLesson extends StatelessWidget {
  final ProgressLesson? lesson;
  final double overallProgress;

  const _NextLesson({
    required this.lesson,
    required this.overallProgress,
  });

  @override
  Widget build(BuildContext context) {
    final title = lesson?.title ?? 'Start the learning path';
    final lessonProgress = lesson?.progress ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next up',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),
        _ProgressRow(
          label: 'Overall',
          value: overallProgress,
        ),
        const SizedBox(height: 8),
        _ProgressRow(
          label: 'This lesson',
          value: lessonProgress,
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;

  const _ProgressRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.subtitle,
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  final int days;

  const _StreakChip({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            size: 16,
            color: Color(0xFFEA580C),
          ),
          const SizedBox(width: 4),
          Text(
            '$days day${days == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFC2410C),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllCompleteMessage extends StatelessWidget {
  const _AllCompleteMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration, color: AppColors.success),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'All lessons completed. Incredible work — review anytime!',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
