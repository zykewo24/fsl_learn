import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shared section header used across profile page widgets.
class ProfileSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const ProfileSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
