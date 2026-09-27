import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/admin_role_controller.dart';
import '../models/user_role.dart';
import '../widgets/user_role_badge.dart';
import 'admin_audit_tab.dart';
import 'admin_curriculum_tab.dart';
import 'admin_overview_tab.dart';
import 'admin_users_tab.dart';

/// Shell for the admin area: one tab per capability.
///
/// Access is granted by the router guard in `AppRouter` before this screen is
/// ever built, and re-checked here on mount. The second check matters because a
/// promoted or demoted account keeps its already-open screen until something
/// invalidates it, and an admin who has just demoted themselves should not be
/// able to carry on writing.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    // Re-read the role on entry. `force` because this is a fresh navigation
    // and the cached value could predate a promotion or demotion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminRoleProvider.notifier).refresh(force: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          if (isAdmin) const _AdminBadge(),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.subtitle,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.insights_outlined, size: 20), text: 'Overview'),
            Tab(icon: Icon(Icons.people_outline, size: 20), text: 'Learners'),
            Tab(
              icon: Icon(Icons.account_tree_outlined, size: 20),
              text: 'Curriculum',
            ),
            Tab(icon: Icon(Icons.history_outlined, size: 20), text: 'Activity'),
          ],
        ),
      ),
      body: isAdmin
          ? TabBarView(
              controller: _tabController,
              children: const [
                AdminOverviewTab(),
                AdminUsersTab(),
                AdminCurriculumTab(),
                AdminAuditTab(),
              ],
            )
          : const _AccessRevokedView(),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    return const UserRoleBadge(role: UserRole.admin);
  }
}

/// Shown when the cached role says the user is not an admin any more.
class _AccessRevokedView extends StatelessWidget {
  const _AccessRevokedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 48,
              color: AppColors.subtitle,
            ),
            const SizedBox(height: 16),
            Text(
              'Admin access required',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your account no longer has admin access. Go back to the app or '
              'ask an administrator to restore it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.subtitle),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
