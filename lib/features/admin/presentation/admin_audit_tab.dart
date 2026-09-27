import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../models/audit_log_model.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_common.dart';

/// Read-only moderation log of every privileged write.
///
/// Entries are produced by database triggers, not the client, so the log is
/// complete even if a build of the app misbehaves.
class AdminAuditTab extends ConsumerWidget {
  const AdminAuditTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(auditLogProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(auditLogProvider);
        // Swallow the error: the provider caches it, so the error branch
        // below re-renders. Rethrowing here would leave the indicator stuck.
        await ref
            .read(auditLogProvider.future)
            .catchError((_) => const <AuditLogModel>[]);
      },
      child: logAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            AdminStatusView(
              isLoading: false,
              error: error,
              isEmpty: false,
              onRetry: () => ref.invalidate(auditLogProvider),
              builder: (_) => const SizedBox.shrink(),
            ),
          ],
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 60),
                AdminStatusView(
                  isLoading: false,
                  error: null,
                  isEmpty: true,
                  onRetry: () => ref.invalidate(auditLogProvider),
                  emptyIcon: Icons.history_outlined,
                  emptyMessage:
                      'No admin activity recorded yet. Changes made here will '
                      'appear in this log.',
                  builder: (context) => const SizedBox.shrink(),
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _AuditRow(entry: entries[index]),
          );
        },
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditLogModel entry;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconFor(entry.action),
              size: 18,
              color: AppColors.subtitle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _describe(entry),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.actorName} · ${_formatWhen(entry.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtitle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Plain-language summary of the action.
  static String _describe(AuditLogModel entry) {
    final label = entry.targetLabel?.trim();
    final subject = label == null || label.isEmpty
        ? (entry.targetId == null ? '' : entry.targetId!)
        : label;

    return switch (entry.action) {
      'role.update' => 'Changed access level for $subject',
      'role.create' => 'Granted access to $subject',
      'profile.update' => 'Updated profile $subject',
      _ => '${entry.summary}${subject.isEmpty ? "" : ": $subject"}',
    };
  }

  static IconData _iconFor(String action) {
    if (action.startsWith('role.')) return Icons.shield_outlined;
    if (action.startsWith('profile.')) return Icons.person_outline;
    if (action.contains('delete')) return Icons.delete_outline;
    if (action.contains('create') || action.contains('insert')) {
      return Icons.add_circle_outline;
    }
    if (action.contains('update')) return Icons.edit_outlined;
    return Icons.history_outlined;
  }

  static String _formatWhen(DateTime? time) {
    if (time == null) return 'unknown time';

    final local = time.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;

    final timeOfDay =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (isToday) return 'today at $timeOfDay';

    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} $timeOfDay';
  }
}
