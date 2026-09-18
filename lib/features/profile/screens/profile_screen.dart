import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/progress_snapshot_model.dart';
import '../../../providers/lesson_provider.dart';
import '../controllers/profile_controller.dart';
import '../models/profile_model.dart';
import '../widgets/badges_section.dart';
import '../widgets/level_progress_section.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats_section.dart';
import '../widgets/recent_activity_section.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ProfileController _controller = ProfileController();

  late Future<ProfileModel> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _controller.loadProfile();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _controller.loadProfile();
    });

    await _profileFuture;

    // Also refresh the progress snapshot used by the rich widgets.
    ref.invalidate(progressSnapshotProvider);
  }

  Future<void> _logout() async {
    try {
      await _controller.logout();

      if (!mounted) return;

      context.go(AppRoutes.login);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to sign out: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileModel>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _refreshProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          return const Center(
            child: Text('Profile unavailable.'),
          );
        }

        final snapshotAsync = ref.watch(progressSnapshotProvider);

        return RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              snapshotAsync.when(
                loading: () => ProfileHeader(
                  profile: profile,
                  snapshot: _emptySnapshot,
                ),
                error: (_, __) => ProfileHeader(
                  profile: profile,
                  snapshot: _emptySnapshot,
                ),
                data: (data) => ProfileHeader(
                  profile: profile,
                  snapshot: data,
                ),
              ),
              const SizedBox(height: 20),
              const ProfileStatsSection(),
              const SizedBox(height: 20),
              snapshotAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LevelProgressSection(snapshot: data),
                    const SizedBox(height: 20),
                    RecentActivitySection(snapshot: data),
                    const SizedBox(height: 20),
                    BadgesSection(snapshot: data),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () => context.push(AppRoutes.settings),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.settings_outlined),
                      SizedBox(width: 12),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

/// Snapshot used while the progress data is still loading/erroring so the
/// header can render with neutral values.
final _emptySnapshot = ProgressSnapshotModel(
  levels: const [],
  modules: const [],
  lessons: const [],
  signProgress: const {},
);
