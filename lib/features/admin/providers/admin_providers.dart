import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_page.dart';
import '../models/admin_user_model.dart';
import '../models/audit_log_model.dart';
import '../models/sign_popularity_model.dart';
import '../models/system_stats_model.dart';
import '../models/user_role.dart';
import '../services/admin_service.dart';

/// The single data-access point for the admin area.
///
/// Instantiated with the shared Supabase client so it works in tests where
/// `Supabase.initialize` has not run.
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(Supabase.instance.client);
});

/// Aggregate counts and rates for the admin overview.
final systemStatsProvider = FutureProvider<SystemStatsModel>((ref) {
  return ref.read(adminServiceProvider).getSystemStats();
});

/// Signs ranked by total practice attempts across all learners.
final topSignsProvider = FutureProvider<List<SignPopularityModel>>((ref) {
  return ref.read(adminServiceProvider).getTopSigns();
});

/// The most recent admin actions, newest first.
final auditLogProvider = FutureProvider<List<AuditLogModel>>((ref) {
  return ref.read(adminServiceProvider).getAuditLog();
});

/// Search text for the learner table. Kept as its own provider so typing does
/// not rebuild the whole screen and so a rebuild can reset pagination.
class AdminUserSearch extends Notifier<AsyncValue<String>> {
  @override
  AsyncValue<String> build() => const AsyncData('');

  void set(String value) {
    state = AsyncData(value);
  }
}

final adminUserSearchProvider =
    NotifierProvider<AdminUserSearch, AsyncValue<String>>(AdminUserSearch.new);

/// Role filter for the learner table. `null` means "all roles".
class AdminUserRoleFilter extends Notifier<AsyncValue<UserRole?>> {
  @override
  AsyncValue<UserRole?> build() => const AsyncData(null);

  void set(UserRole? value) {
    state = AsyncData(value);
  }
}

final adminUserRoleFilterProvider =
    NotifierProvider<AdminUserRoleFilter, AsyncValue<UserRole?>>(
  AdminUserRoleFilter.new,
);

/// Current page index for the learner table.
class AdminUserPage extends Notifier<int> {
  @override
  int build() => 0;

  void goTo(int page) {
    if (page < 0 || page == state) return;
    state = page;
  }

  void reset() {
    state = 0;
  }
}

final adminUserPageProvider =
    NotifierProvider<AdminUserPage, int>(AdminUserPage.new);

/// How many learners to fetch per page.
const int kAdminUsersPageSize = 20;

/// A page of learners matching the current search and role filter.
final adminUsersProvider =
    FutureProvider<AdminPage<AdminUserModel>>((ref) async {
  final search = ref.watch(adminUserSearchProvider).valueOrNull ?? '';
  final role = ref.watch(adminUserRoleFilterProvider).valueOrNull;
  final page = ref.watch(adminUserPageProvider);

  return ref
      .read(adminServiceProvider)
      .listUsers(search: search, role: role, page: page, pageSize: kAdminUsersPageSize);
});
