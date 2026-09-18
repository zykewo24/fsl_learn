import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/progress_snapshot_model.dart';
import 'profile_section_title.dart';

/// Lists the most recently practiced signs with time-ago and best score.
class RecentActivitySection extends StatelessWidget {
  final ProgressSnapshotModel snapshot;

  const RecentActivitySection({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final activity = snapshot.recentActivity(8);

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
            const ProfileSectionTitle(
              icon: Icons.history,
              title: 'Recent Activity',
            ),
            const SizedBox(height: 16),
            if (activity.isEmpty)
              const Text(
                'No practice yet. Head to Lessons to get started!',
                style: TextStyle(color: AppColors.subtitle, fontSize: 13),
              )
            else
              for (var i = 0; i < activity.length; i++) ...[
                _ActivityRow(entry: activity[i]),
                if (i != activity.length - 1)
                  const Divider(height: 16, color: AppColors.border),
              ],
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final SignProgressEntry entry;

  const _ActivityRow({required this.entry});

  String get _timeAgo {
    final time = entry.lastPracticedAt;
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  IconData get _icon =>
      entry.completed ? Icons.check_circle : Icons.radio_button_unchecked;

  @override
  Widget build(BuildContext context) {
    final title = entry.signTitle.isEmpty
        ? 'Untitled sign'
        : entry.signTitle;

    return Row(
      children: [
        Icon(
          _icon,
          size: 20,
          color: entry.completed ? AppColors.success : AppColors.subtitle,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
        ),
        if (entry.practiceCount > 0) ...[
          Text(
            '${(entry.bestScore * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(
          _timeAgo,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.subtitle,
          ),
        ),
      ],
    );
  }
}
