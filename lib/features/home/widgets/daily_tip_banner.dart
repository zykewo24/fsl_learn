import 'package:flutter/material.dart';

import '../../../models/progress_snapshot_model.dart';

/// A dismissible, personalized encouragement banner. The tip is derived from
/// the user's actual progress so it always feels relevant.
class DailyTipBanner extends StatefulWidget {
  final ProgressSnapshotModel snapshot;
  final VoidCallback? onBrowseLessons;

  const DailyTipBanner({
    super.key,
    required this.snapshot,
    this.onBrowseLessons,
  });

  @override
  State<DailyTipBanner> createState() => _DailyTipBannerState();
}

class _DailyTipBannerState extends State<DailyTipBanner> {
  bool _visible = true;

  String get _tip {
    final snapshot = widget.snapshot;

    final nextLesson = snapshot.nextLesson();
    final streak = snapshot.streakDays;
    final mastered = snapshot.completedSigns;
    final practiced = snapshot.practicedSignCount;
    final accuracy = snapshot.bestAverageScore;

    if (practiced == 0 || mastered == 0) {
      return 'Start with the FSL Alphabet — master a few letters to get '
          'your first badge.';
    }

    if (nextLesson != null) {
      return 'Keep building momentum! Next up: "${nextLesson.title}".';
    }

    if (streak >= 7) {
      return 'Amazing week streak! Keep the daily rhythm going. 🎉';
    }

    if (streak >= 3) {
      return 'You are on a roll 🎯 — a little practice each day keeps the '
          'streak alive!';
    }

    if (accuracy < 0.7) {
      return 'Take it slow and focus on hand shape — accuracy beats speed.';
    }

    if (mastered >= 25) {
      return 'You have mastered $mastered signs. Try the Numbers module next!';
    }

    return 'Daily practice keeps your signs sharp — 5 minutes is enough!';
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF3C4).withValues(alpha: 0.6),
            const Color(0xFFFFE0B2).withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb,
            color: Color(0xFFB45309),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _tip,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _visible = false),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 18,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
