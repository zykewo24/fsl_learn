import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/progress_snapshot_model.dart';
import '../../../providers/lesson_provider.dart';
import '../../../providers/profile_provider.dart';
import 'continue_learning_card.dart';
import 'daily_tip_banner.dart';
import 'dashboard_card.dart';
import 'home_header.dart';

class DashboardScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigateTo;

  const DashboardScreen({super.key, this.onNavigateTo});

  static const _emptySnapshot = ProgressSnapshotModel(
    levels: [],
    modules: [],
    lessons: [],
    signProgress: {},
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final snapshotAsync = ref.watch(progressSnapshotProvider);

    return profile.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                "Couldn't load your progress",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.invalidate(profileProvider);
                  ref.invalidate(progressSnapshotProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const Center(
            child: Text('Unable to load profile'),
          );
        }

        final snapshot = snapshotAsync.valueOrNull ?? _emptySnapshot;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(progressSnapshotProvider);
            await Future.wait([
              ref.read(profileProvider.future).catchError((_) => null),
              ref
                  .read(progressSnapshotProvider.future)
                  .catchError((_) => _emptySnapshot),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              HomeHeader(profile: user, snapshot: snapshot),
              const SizedBox(height: 16),
              DailyTipBanner(
                snapshot: snapshot,
                onBrowseLessons: () => onNavigateTo?.call(1),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  DashboardCard(
                    icon: Icons.menu_book_rounded,
                    title: 'Lessons',
                    subtitle: 'Learn FSL',
                    onTap: () => onNavigateTo?.call(1),
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 16),
                  DashboardCard(
                    icon: Icons.front_hand,
                    title: 'Practice',
                    subtitle: 'Camera AI',
                    onTap: () => onNavigateTo?.call(2),
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  DashboardCard(
                    icon: Icons.bar_chart,
                    title: 'Progress',
                    subtitle: 'Statistics',
                    onTap: () => onNavigateTo?.call(3),
                    color: const Color(0xFF0891B2),
                  ),
                  const SizedBox(width: 16),
                  DashboardCard(
                    icon: Icons.person,
                    title: 'Profile',
                    subtitle: 'Account',
                    onTap: () => onNavigateTo?.call(4),
                    color: const Color(0xFF16A34A),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              ContinueLearningCard(
                onContinue: () => onNavigateTo?.call(1),
              ),
            ],
          ),
        );
      },
    );
  }
}
