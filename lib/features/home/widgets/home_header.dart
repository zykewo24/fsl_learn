import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/profile_model.dart';
import '../../../models/progress_snapshot_model.dart';

/// Greeting header with the user's avatar, name, and a compact stats strip
/// (day streak, signs mastered, accuracy) derived from the snapshot.
class HomeHeader extends StatelessWidget {
  final ProfileModel profile;
  final ProgressSnapshotModel snapshot;

  const HomeHeader({
    super.key,
    required this.profile,
    required this.snapshot,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String get _initials {
    final parts = profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first +
            parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        _initials,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()},',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _statsStrip(snapshot),
        ],
      ),
    );
  }

  Widget _statsStrip(ProgressSnapshotModel snapshot) {
    return Row(
      children: [
        _stat(_StatValue('${snapshot.streakDays}', icon: Icons.local_fire_department, label: 'Day streak')),
        const SizedBox(width: 12),
        _stat(_StatValue(
          '${snapshot.completedSigns}/${snapshot.totalSigns}',
          icon: Icons.check_circle_outline,
          label: 'Mastered',
        )),
        const SizedBox(width: 12),
        _stat(_StatValue(
          '${(snapshot.bestAverageScore * 100).toStringAsFixed(0)}%',
          icon: Icons.verified_outlined,
          label: 'Accuracy',
        )),
      ],
    );
  }

  Widget _stat(_StatValue value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(value.icon, color: Colors.white, size: 18),
            const SizedBox(height: 6),
            Text(
              value.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatValue {
  final String value;
  final IconData icon;
  final String label;
  const _StatValue(this.value, {required this.icon, required this.label});
}
