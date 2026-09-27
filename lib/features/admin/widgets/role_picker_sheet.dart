import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/admin_user_model.dart';
import '../models/user_role.dart';
import 'user_role_badge.dart';

/// Lets an admin change [user]'s role.
///
/// Resolves to the chosen role, or `null` if the user backed out. Demoting
/// yourself is disabled in the UI; [AdminService.updateUserRole] refuses it
/// too, and a database trigger refuses it last, so the last admin cannot be
/// locked out from any of the three layers.
Future<UserRole?> showRolePickerSheet(
  BuildContext context, {
  required AdminUserModel user,
  required String? currentUserId,
}) {
  final isSelf = user.id == currentUserId;

  return showModalBottomSheet<UserRole>(
    context: context,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const Text(
                    'Change access level',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.email.isEmpty ? user.fullName : user.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.subtitle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  UserRoleBadge(role: user.role),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final role in UserRole.values)
              _RoleOption(
                role: role,
                selected: role == user.role,
                enabled: !(isSelf && role == UserRole.learner),
                disabledHint: isSelf && role == UserRole.learner
                    ? 'You cannot remove your own admin access'
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(role),
              ),
            if (isSelf)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  'Ask another admin if you need to give up your own access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.subtitle),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.disabledHint,
  });

  final UserRole role;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final description = switch (role) {
      UserRole.admin =>
        'Can manage the curriculum, review learners and change roles.',
      UserRole.learner =>
        'Can learn and practise signs. No access to the admin area.',
    };

    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        role.isAdmin ? Icons.shield_outlined : Icons.person_outline,
        color: enabled ? AppColors.primary : AppColors.subtitle,
      ),
      title: Text(
        role.label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: enabled ? AppColors.text : AppColors.subtitle,
        ),
      ),
      subtitle: Text(
        disabledHint ?? description,
        style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
    );
  }
}
