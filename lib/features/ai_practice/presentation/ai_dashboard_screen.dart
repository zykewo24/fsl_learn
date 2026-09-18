import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/progress_snapshot_model.dart';
import '../../../providers/lesson_provider.dart';

class AiDashboardScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigateTo;

  const AiDashboardScreen({super.key, this.onNavigateTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(progressSnapshotProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(progressSnapshotProvider);
        await ref.read(progressSnapshotProvider.future);
      },
      child: snapshotAsync.when(
        loading: () => ListView(
          children: const [
            SizedBox(height: 24),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (err, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load practice data',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(progressSnapshotProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
        data: (snapshot) => _buildContent(context, ref, snapshot),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ProgressSnapshotModel snapshot,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'AI Practice',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Practice sign language with real-time feedback',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.subtitle,
          ),
        ),
        const SizedBox(height: 20),

        _StatsHeader(snapshot: snapshot),
        const SizedBox(height: 24),

        const Text(
          'Start Practicing',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),
        _QuickActionGrid(onNavigateTo: onNavigateTo, snapshot: snapshot),

        const SizedBox(height: 24),

        _ContinueLearning(snapshot: snapshot),
        const SizedBox(height: 24),

        _RecentLessons(snapshot: snapshot),
        const SizedBox(height: 24),

        const Text(
          'Tools',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),
        _ToolsRow(context),
        const SizedBox(height: 30),
      ],
    );
  }
}

/// Gradient stats header card (day streak, mastered, accuracy).
class _StatsHeader extends StatelessWidget {
  final ProgressSnapshotModel snapshot;
  const _StatsHeader({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your progress',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat(
                '${snapshot.streakDays}',
                'Day streak',
                Icons.local_fire_department,
              ),
              const SizedBox(width: 12),
              _stat(
                '${snapshot.completedSigns}/${snapshot.totalSigns}',
                'Mastered',
                Icons.check_circle_outline,
              ),
              const SizedBox(width: 12),
              _stat(
                '${(snapshot.bestAverageScore * 100).toStringAsFixed(0)}%',
                'Accuracy',
                Icons.verified_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two large tappable cards: Continue Lesson and Free Practice.
class _QuickActionGrid extends StatelessWidget {
  final ValueChanged<int>? onNavigateTo;
  final ProgressSnapshotModel snapshot;
  const _QuickActionGrid({
    required this.onNavigateTo,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.play_circle_fill,
            title: 'Continue',
            subtitle: 'Resume lesson',
            colors: const [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
            onTap: () {
              final next = snapshot.nextLesson();
              if (next != null) {
                context.push(
                  AppRoutes.practiceSession,
                  extra: next.toLessonModel(),
                );
              } else {
                onNavigateTo?.call(1);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.front_hand,
            title: 'Free',
            subtitle: 'Practice any sign',
            colors: const [Color(0xFF16A34A), Color(0xFF22C55E)],
            onTap: () {
              ProgressLesson? target;
              if (snapshot.lessons.isNotEmpty) {
                for (final lesson in snapshot.lessons) {
                  if (lesson.totalSigns > 0) {
                    target = lesson;
                    break;
                  }
                }
              }
              if (target != null) {
                context.push(
                  AppRoutes.practiceSession,
                  extra: target.toLessonModel(),
                );
              } else {
                onNavigateTo?.call(1);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueLearning extends StatelessWidget {
  final ProgressSnapshotModel snapshot;
  const _ContinueLearning({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final next = snapshot.nextLesson();

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
              ],
            ),
            const SizedBox(height: 16),
            if (next == null)
              const _AllCompleteMessage()
            else ...[
              _ProgressRow(
                label: next.title,
                value: next.progress,
              ),
              const SizedBox(height: 12),
              Text(
                '${snapshot.completedSigns}/${snapshot.totalSigns} '
                'signs mastered',
                style: const TextStyle(
                  color: AppColors.subtitle,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    context.push(
                      AppRoutes.practiceSession,
                      extra: next.toLessonModel(),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Resume Learning'),
                ),
              ),
            ],
          ],
        ),
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
              'All lessons completed. Review anytime!',
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
                fontSize: 13,
                color: AppColors.subtitle,
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 13,
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

class _RecentLessons extends StatelessWidget {
  final ProgressSnapshotModel snapshot;
  const _RecentLessons({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lessons',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),
        ...snapshot.lessons.take(3).map((lesson) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LessonTile(lesson: lesson),
            )),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  final ProgressLesson lesson;
  const _LessonTile({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.practiceSession,
          extra: lesson.toLessonModel(),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                lesson.progress >= 1.0
                    ? Icons.check_circle
                    : Icons.menu_book_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: lesson.progress,
                      minHeight: 5,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(lesson.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolsRow extends StatelessWidget {
  final BuildContext context;
  const _ToolsRow(this.context);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToolTile(
            icon: Icons.camera_alt_outlined,
            title: 'Camera Test',
            subtitle: 'Verify camera works',
            onTap: () => context.push(AppRoutes.cameraTest),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToolTile(
            icon: Icons.tune,
            title: 'Calibration',
            subtitle: 'Improve accuracy',
            onTap: () => context.push(AppRoutes.cameraTest),
          ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.subtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
