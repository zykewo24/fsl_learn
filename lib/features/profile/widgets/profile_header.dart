import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/progress_snapshot_model.dart';
import '../models/profile_model.dart';

/// Derives a learner rank from the overall progress snapshot.
class LearnerRank {
  final String title;
  final IconData icon;
  final Color color;

  const LearnerRank({
    required this.title,
    required this.icon,
    required this.color,
  });
}

LearnerRank rankFor(ProgressSnapshotModel snapshot) {
  final p = snapshot.overallProgress;

  if (p >= 0.8) {
    return const LearnerRank(
      title: 'Master',
      icon: Icons.workspace_premium,
      color: Color(0xFF7C3AED),
    );
  }

  if (p >= 0.5) {
    return const LearnerRank(
      title: 'Advanced',
      icon: Icons.auto_awesome,
      color: Color(0xFF2563EB),
    );
  }

  if (p >= 0.2) {
    return const LearnerRank(
      title: 'Intermediate',
      icon: Icons.trending_up,
      color: Color(0xFF0891B2),
    );
  }

  return const LearnerRank(
    title: 'Beginner',
    icon: Icons.spa,
    color: Color(0xFF16A34A),
  );
}

class ProfileHeader extends StatelessWidget {
  final ProfileModel profile;
  final ProgressSnapshotModel snapshot;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.snapshot,
  });

  String get _initials {
    final parts = profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    return (parts.first.characters.first +
            parts.last.characters.first)
        .toUpperCase();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final rank = rankFor(snapshot);
    final progress = snapshot.overallProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.secondary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          // Avatar with a progress ring.
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.primary,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 40,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          _initials,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: rank.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            rank.icon,
                            size: 16,
                            color: rank.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            rank.title,
                            style: TextStyle(
                              color: rank.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Member since',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.subtitle,
                          ),
                        ),
                        Text(
                          _formatDate(profile.createdAt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
