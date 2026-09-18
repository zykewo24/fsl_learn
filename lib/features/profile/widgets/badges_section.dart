import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/progress_snapshot_model.dart';
import 'profile_section_title.dart';

class _BadgeDef {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool earned;

  const _BadgeDef({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.earned,
  });
}

/// Renders a grid of achievement badges, earned from real progress data.
class BadgesSection extends StatelessWidget {
  final ProgressSnapshotModel snapshot;

  const BadgesSection({
    super.key,
    required this.snapshot,
  });

  List<_BadgeDef> _badges() {
    final practiced = snapshot.practicedSignCount;
    final mastered = snapshot.completedSigns;
    final streak = snapshot.streakDays;
    final accuracy = snapshot.bestAverageScore;
    final overall = snapshot.overallProgress;
    final total = snapshot.totalPracticeCount;

    int completedModules =
        snapshot.modules.where((m) => m.progress >= 1.0).length;

    return [
      _BadgeDef(
        title: 'First Steps',
        description: 'Practice your first sign',
        icon: Icons.favorite,
        color: const Color(0xFFEF4444),
        earned: practiced >= 1,
      ),
      _BadgeDef(
        title: 'Sign Seeker',
        description: 'Master your first sign',
        icon: Icons.check_circle,
        color: const Color(0xFF16A34A),
        earned: mastered >= 1,
      ),
      _BadgeDef(
        title: 'Alphabet Adept',
        description: 'Master 25 signs',
        icon: Icons.abc,
        color: const Color(0xFF2563EB),
        earned: mastered >= 25,
      ),
      _BadgeDef(
        title: 'Halfway Hero',
        description: 'Reach 50% overall progress',
        icon: Icons.flag,
        color: const Color(0xFF0891B2),
        earned: overall >= 0.5,
      ),
      _BadgeDef(
        title: 'Master of Signs',
        description: 'Master every sign',
        icon: Icons.workspace_premium,
        color: const Color(0xFF7C3AED),
        earned: overall >= 1.0,
      ),
      _BadgeDef(
        title: 'On a Roll',
        description: 'Practice 3 days in a row',
        icon: Icons.local_fire_department,
        color: const Color(0xFFF59E0B),
        earned: streak >= 3,
      ),
      _BadgeDef(
        title: 'Week Warrior',
        description: 'Practice 7 days in a row',
        icon: Icons.whatshot,
        color: const Color(0xFFEA580C),
        earned: streak >= 7,
      ),
      _BadgeDef(
        title: 'Module Master',
        description: 'Complete all signs in a module',
        icon: Icons.emoji_events,
        color: const Color(0xFFE11D48),
        earned: completedModules >= 1,
      ),
      _BadgeDef(
        title: 'Practice Addict',
        description: 'Log 20 practice runs',
        icon: Icons.repeat,
        color: const Color(0xFF4F46E5),
        earned: total >= 20,
      ),
      _BadgeDef(
        title: 'Sharpshooter',
        description: 'Keep 85% average accuracy',
        icon: Icons.gps_fixed,
        color: const Color(0xFF059669),
        earned: accuracy >= 0.85,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _badges();
    final earnedCount = badges.where((b) => b.earned).length;

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
                const ProfileSectionTitle(
                  icon: Icons.emoji_events,
                  title: 'Badges',
                ),
                const Spacer(),
                Text(
                  '$earnedCount/${badges.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                return _BadgeTile(badge: badges[index]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final _BadgeDef badge;

  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = badge.earned
        ? badge.color
        : AppColors.subtitle.withValues(alpha: 0.4);

    final labelColor = badge.earned
        ? AppColors.text
        : AppColors.subtitle.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badge.earned
            ? badge.color.withValues(alpha: 0.10)
            : AppColors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badge.earned
              ? badge.color.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badge.icon,
            size: 34,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: labelColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
