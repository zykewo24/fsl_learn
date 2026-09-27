import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/sign_popularity_model.dart';
import '../models/system_stats_model.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_common.dart';
import '../widgets/admin_stat_tile.dart';

/// System analytics: how many learners there are, how engaged they are and how
/// much of the curriculum has been reached.
class AdminOverviewTab extends ConsumerWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(systemStatsProvider);
    final topSignsAsync = ref.watch(topSignsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(systemStatsProvider);
        ref.invalidate(topSignsProvider);
        // Await the refetches so the indicator dismisses once they land. The
        // errors are swallowed because the providers cache them and the error
        // branches below render them.
        await ref
            .read(systemStatsProvider.future)
            .catchError((_) => SystemStatsModel.empty);
        await ref
            .read(topSignsProvider.future)
            .catchError((_) => const <SignPopularityModel>[]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const AdminSectionHeader(title: 'LEARNERS'),
          const SizedBox(height: 10),
          _StatsGrid(
            async: statsAsync,
            onRetry: () => ref.invalidate(systemStatsProvider),
            tile: (stats) => _LearnerTiles(stats: stats),
          ),
          const SizedBox(height: 24),

          const AdminSectionHeader(title: 'ENGAGEMENT'),
          const SizedBox(height: 10),
          _StatsGrid(
            async: statsAsync,
            onRetry: () => ref.invalidate(systemStatsProvider),
            tile: (stats) => _EngagementTiles(stats: stats),
          ),
          const SizedBox(height: 24),

          const AdminSectionHeader(title: 'CURRICULUM'),
          const SizedBox(height: 10),
          _StatsGrid(
            async: statsAsync,
            onRetry: () => ref.invalidate(systemStatsProvider),
            tile: (stats) => _CurriculumTiles(stats: stats),
          ),
          const SizedBox(height: 24),

          const AdminSectionHeader(title: 'MOST PRACTISED SIGNS'),
          const SizedBox(height: 10),
          AdminCard(
            child: topSignsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '$error',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.danger,
                  ),
                ),
              ),
              data: (signs) {
                if (signs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No signs have been practised yet.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.subtitle,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (var i = 0; i < signs.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _TopSignRow(rank: i + 1, item: signs[i]),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders one group of tiles, sharing a single stats request.
///
/// Lets each section show its own loading and error state without issuing the
/// aggregate query three times.
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.async,
    required this.onRetry,
    required this.tile,
  });

  final AsyncValue<SystemStatsModel> async;
  final VoidCallback onRetry;
  final Widget Function(SystemStatsModel stats) tile;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => AdminCard(
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$error',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.subtitle,
                ),
              ),
            ),
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
            ),
          ],
        ),
      ),
      data: tile,
    );
  }
}

class _LearnerTiles extends StatelessWidget {
  const _LearnerTiles({required this.stats});

  final SystemStatsModel stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AdminStatTile(
                icon: Icons.people_outline,
                label: 'Total accounts',
                value: '${stats.totalUsers}',
                accent: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdminStatTile(
                icon: Icons.school_outlined,
                label: 'Learners',
                value: '${stats.learnerUsers}',
                accent: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AdminStatTile(
                icon: Icons.shield_outlined,
                label: 'Admins',
                value: '${stats.adminUsers}',
                accent: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdminStatTile(
                icon: Icons.person_off_outlined,
                label: 'Never practised',
                value: '${stats.inactiveLearners}',
                accent: AppColors.subtitle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EngagementTiles extends StatelessWidget {
  const _EngagementTiles({required this.stats});

  final SystemStatsModel stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AdminStatTile(
                icon: Icons.bolt_outlined,
                label: 'Active learners',
                value: '${stats.activeLearners}',
                caption: stats.activeRatePercent == null
                    ? null
                    : '${stats.activeRatePercent}% of learners',
                accent: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdminStatTile(
                icon: Icons.check_circle_outline,
                label: 'Signs mastered',
                value: '${stats.signsPractised}',
                caption: stats.signCoveragePercent == null
                    ? null
                    : '${stats.signCoveragePercent}% of catalogue',
                accent: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurriculumTiles extends StatelessWidget {
  const _CurriculumTiles({required this.stats});

  final SystemStatsModel stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AdminStatTile(
            icon: Icons.layers_outlined,
            label: 'Levels',
            value: '${stats.totalLevels}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AdminStatTile(
            icon: Icons.widgets_outlined,
            label: 'Modules',
            value: '${stats.totalModules}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AdminStatTile(
            icon: Icons.menu_book_outlined,
            label: 'Lessons',
            value: '${stats.totalLessons}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AdminStatTile(
            icon: Icons.back_hand_outlined,
            label: 'Signs',
            value: '${stats.totalSigns}',
            caption: stats.totalSignRows == stats.totalSigns
                ? null
                : '${stats.totalSignRows} incl. inactive',
          ),
        ),
      ],
    );
  }
}

class _TopSignRow extends StatelessWidget {
  const _TopSignRow({required this.rank, required this.item});

  final int rank;
  final SignPopularityModel item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.subtitle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${item.practiceCount} attempts',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtitle,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${item.learnerCount} learners',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.subtitle,
            ),
          ),
        ],
      ),
    );
  }
}
