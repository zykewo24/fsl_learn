import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One metric on the admin overview.
///
/// A `null` [value] renders as an em dash rather than `0`, so a metric the
/// database could not supply is visually distinct from a real zero.
class AdminStatTile extends StatelessWidget {
  const AdminStatTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.caption,
    this.accent = AppColors.primary,
  });

  final IconData icon;
  final String label;

  /// Formatted metric, or `null` when unavailable.
  final String? value;

  /// Optional secondary line, e.g. "of 42".
  final String? caption;

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            value ?? '—',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.subtitle,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.subtitle.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
