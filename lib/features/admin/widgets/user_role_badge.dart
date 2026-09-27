import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/user_role.dart';

/// Small coloured pill showing a profile's access level.
class UserRoleBadge extends StatelessWidget {
  const UserRoleBadge({
    super.key,
    required this.role,
    this.compact = false,
  });

  final UserRole role;

  /// Renders the icon-less, label-only form used inside dense list rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = role.isAdmin ? AppColors.primary : AppColors.subtitle;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (role.isAdmin) ...[
            Icon(Icons.shield_outlined, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            role.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
