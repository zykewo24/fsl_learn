import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/admin_role_controller.dart';
import '../models/admin_page.dart';
import '../models/admin_user_model.dart';
import '../models/user_role.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_common.dart';
import '../widgets/role_picker_sheet.dart';
import '../widgets/user_role_badge.dart';

/// Searchable, filterable learner table with inline role changes.
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  /// Long enough to skip intermediate keystrokes, short enough to feel live.
  static const _debounceDelay = Duration(milliseconds: 300);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Rebuild so the clear button appears as soon as the field is non-empty,
    // without waiting for the debounced query to resolve.
    setState(() {});

    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      // A new result set always starts at page 0, or an out-of-range page
      // would render empty after narrowing the filter.
      ref.read(adminUserPageProvider.notifier).reset();
      ref.read(adminUserSearchProvider.notifier).set(value);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(adminUsersProvider);
    // Wait for the refetch so the indicator dismisses once it lands, but drop
    // the result and the error: the provider caches either, and the error
    // branch renders it.
    await ref.read(adminUsersProvider.future).then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        );
  }

  Future<void> _changeRole(AdminUserModel user) async {
    final currentUserId = ref.read(currentUserIdProvider);

    final role = await showRolePickerSheet(
      context,
      user: user,
      currentUserId: currentUserId,
    );

    if (role == null || role == user.role || !mounted) return;

    try {
      await ref
          .read(adminServiceProvider)
          .updateUserRole(userId: user.id, role: role);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('$error');
      return;
    }

    if (!mounted) return;

    // The role counts on the overview and the current session's own access
    // both change, so drop every affected cache.
    ref.invalidate(adminUsersProvider);
    ref.invalidate(systemStatsProvider);
    await ref.read(adminRoleProvider.notifier).refresh(force: true);

    if (!mounted) return;
    _showSnackBar('${user.fullName} is now a ${role.label.toLowerCase()}.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final roleFilter = ref.watch(adminUserRoleFilterProvider).valueOrNull;
    final search = ref.watch(adminUserSearchProvider).valueOrNull ?? '';
    final currentUserId = ref.watch(currentUserIdProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by name or email',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        ref.read(adminUserPageProvider.notifier).reset();
                        ref.read(adminUserSearchProvider.notifier).set('');
                        setState(() {});
                      },
                    ),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _RoleFilterChip(
                label: 'All',
                selected: roleFilter == null,
                onSelected: () => _setRoleFilter(null),
              ),
              const SizedBox(width: 8),
              for (final role in UserRole.values) ...[
                _RoleFilterChip(
                  label: role.label,
                  selected: roleFilter == role,
                  onSelected: () => _setRoleFilter(role),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AdminStatusView(
              isLoading: false,
              error: error,
              isEmpty: false,
              onRetry: _refresh,
              builder: (_) => const SizedBox.shrink(),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return AdminStatusView(
                  isLoading: false,
                  error: null,
                  isEmpty: true,
                  onRetry: _refresh,
                  emptyIcon: Icons.person_search_outlined,
                  emptyMessage: search.isNotEmpty
                      ? 'No accounts match that search.'
                      : 'No accounts yet.',
                  builder: (_) => const SizedBox.shrink(),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: page.items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == page.items.length) {
                      return _Pager(page: page);
                    }

                    final user = page.items[index];

                    return _UserRow(
                      user: user,
                      isSelf: user.id == currentUserId,
                      onChangeRole: () => _changeRole(user),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _setRoleFilter(UserRole? role) {
    ref.read(adminUserPageProvider.notifier).reset();
    ref.read(adminUserRoleFilterProvider.notifier).set(role);
  }
}

class _RoleFilterChip extends StatelessWidget {
  const _RoleFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isSelf,
    required this.onChangeRole,
  });

  final AdminUserModel user;
  final bool isSelf;
  final VoidCallback onChangeRole;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                user.role.isAdmin ? AppColors.primary : AppColors.secondary,
            backgroundImage: null,
            child: Text(
              _initials(user.fullName),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '(you)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtitle,
                        ),
                      ),
                    ],
                  ],
                ),
                if (user.email.isNotEmpty)
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.subtitle,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    UserRoleBadge(role: user.role, compact: true),
                    _MiniStat(
                      icon: Icons.check_circle_outline,
                      label: '${user.masteredCount} signs',
                    ),
                    if (user.hasActivity)
                      _MiniStat(
                        icon: Icons.replay,
                        label: '${user.practiceCount}',
                      ),
                    if (user.averageScorePercent != null)
                      _MiniStat(
                        icon: Icons.speed_outlined,
                        label: '${user.averageScorePercent}%',
                      ),
                    if (!user.hasActivity)
                      const _MiniStat(
                        icon: Icons.schedule,
                        label: 'No activity',
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Manage ${user.fullName}',
            onSelected: (value) {
              if (value == 'role') onChangeRole();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'role',
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Change access level'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.subtitle),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
        ),
      ],
    );
  }
}

class _Pager extends ConsumerWidget {
  const _Pager({required this.page});

  final AdminPage<AdminUserModel> page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page.totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Showing ${page.items.length} of ${page.total}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Showing ${page.firstRowIndex + 1}–${page.lastRowIndex} '
            'of ${page.total}',
            style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: page.page == 0
                ? null
                : () => ref
                    .read(adminUserPageProvider.notifier)
                    .goTo(page.page - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
          ),
          Text(
            '${page.page + 1} / ${page.totalPages}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: page.hasMore
                ? null
                : () => ref
                    .read(adminUserPageProvider.notifier)
                    .goTo(page.page + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}
