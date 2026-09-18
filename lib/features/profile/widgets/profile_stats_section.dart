import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/lesson_provider.dart';
import 'profile_section_title.dart';

class ProfileStatsSection extends ConsumerWidget {
  const ProfileStatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(progressSnapshotProvider);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: snapshotAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Could not load statistics',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
          data: (snapshot) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfileSectionTitle(
                  icon: Icons.insights,
                  title: 'Your Progress',
                ),
                const SizedBox(height: 16),

                // Accuracy bar.
                _AccuracyBar(
                  accuracy: snapshot.bestAverageScore,
                ),
                const SizedBox(height: 16),

                // Metrics grid.
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.check_circle_outline,
                        value:
                            '${snapshot.completedSigns}/${snapshot.totalSigns}',
                        label: 'Signs mastered',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.replay,
                        value: '${snapshot.totalPracticeCount}',
                        label: 'Practice runs',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.verified_outlined,
                        value:
                            '${(snapshot.bestAverageScore * 100).toStringAsFixed(0)}%',
                        label: 'Best accuracy',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.local_fire_department_outlined,
                        value: '${snapshot.streakDays}',
                        label: 'Day streak',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.handshake_outlined,
                        value: '${snapshot.practicedSignCount}',
                        label: 'Signs practiced',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LastActiveTile(
                        lastPracticedAt: snapshot.lastPracticedAt,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccuracyBar extends StatelessWidget {
  final double accuracy;

  const _AccuracyBar({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final pct = (accuracy * 100).clamp(0, 100).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Average accuracy',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.subtitle,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: accuracy,
              minHeight: 8,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastActiveTile extends StatelessWidget {
  final DateTime? lastPracticedAt;

  const _LastActiveTile({required this.lastPracticedAt});

  String get _label {
    if (lastPracticedAt == null) return 'Never';
    final diff = DateTime.now().difference(lastPracticedAt!);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.schedule,
            size: 18,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 8),
          const Text(
            'Last active',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.subtitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
