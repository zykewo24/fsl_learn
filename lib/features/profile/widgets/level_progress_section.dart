import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/progress_snapshot_model.dart';
import 'profile_section_title.dart';

/// Shows progress broken down by level, with each level's modules listed
/// and their own completion bars.
class LevelProgressSection extends StatelessWidget {
  final ProgressSnapshotModel snapshot;

  const LevelProgressSection({
    super.key,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.levels.isEmpty) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('No learning levels yet.'),
        ),
      );
    }

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
              icon: Icons.auto_stories,
              title: 'Learning Levels',
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < snapshot.levels.length; i++) ...[
              _LevelTile(
                level: snapshot.levels[i],
                modules: snapshot.modules
                    .where(
                      (m) => m.levelId == snapshot.levels[i].id,
                    )
                    .toList(),
              ),
              if (i != snapshot.levels.length - 1)
                const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final ProgressLevel level;
  final List<ProgressModule> modules;

  const _LevelTile({
    required this.level,
    required this.modules,
  });

  @override
  Widget build(BuildContext context) {
    final pct = level.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              level.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            Text(
              '${level.completedSigns}/${level.totalSigns}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.subtitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        if (modules.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final module in modules)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ModuleRow(module: module),
            ),
        ],
      ],
    );
  }
}

class _ModuleRow extends StatelessWidget {
  final ProgressModule module;

  const _ModuleRow({required this.module});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  module.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${module.completedSigns}/${module.totalSigns}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.subtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: module.progress,
              minHeight: 6,
              backgroundColor:
                  AppColors.secondary.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(
                AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
