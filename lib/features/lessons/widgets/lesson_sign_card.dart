import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/sign_asset.dart';
import '../../../models/lesson_sign_model.dart';

class LessonSignCard extends StatelessWidget {
  final LessonSignModel sign;
  final Map<String, dynamic>? progress;
  final int index;
  final VoidCallback? onPractice;

  const LessonSignCard({
    super.key,
    required this.sign,
    this.progress,
    this.index = 0,
    this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    final completed = progress?['completed'] == true;

    final score = progress?['best_score'] != null
        ? (progress!['best_score'] as num).toDouble()
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: completed
              ? AppColors.success.withValues(alpha: 0.25)
              : Colors.grey.shade200,
          width: completed ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status icon
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed
                        ? AppColors.success.withValues(alpha: 0.12)
                        : Colors.grey.shade200,
                  ),
                  child: Icon(
                    completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: completed
                        ? AppColors.success
                        : Colors.grey.shade400,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${sign.title}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: completed ? AppColors.subtitle : null,
                        ),
                      ),
                      if (sign.difficulty.isNotEmpty)
                        Text(
                          _difficultyLabel(sign.difficulty),
                          style: TextStyle(
                            fontSize: 11,
                            color: _difficultyColor(sign.difficulty),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),

                // Score chip
                if (score > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _scoreColor(score).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(score * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _scoreColor(score),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Reference image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 170,
                width: double.infinity,
                color: Colors.grey.shade50,
                alignment: Alignment.center,
                child: _buildReferenceImage(resolveSignAssetPath(sign.aiLabel)),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              sign.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            // Status + button
            Row(
              children: [
                Chip(
                  avatar: Icon(
                    completed ? Icons.check : Icons.schedule,
                    size: 16,
                  ),
                  label: Text(
                    completed ? 'Completed' : 'Not Started',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: completed
                      ? AppColors.success.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  side: BorderSide.none,
                ),
                const Spacer(),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPractice,
                icon: const Icon(Icons.videocam, size: 20),
                label: Text(
                  completed ? 'Practice Again' : 'Start Practice',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceImage(String? assetPath) {
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        height: 150,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
      );
    }

    if (sign.imageUrl != null) {
      return Image.network(
        sign.imageUrl!,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
      );
    }

    return const _ImagePlaceholder();
  }

  String _difficultyLabel(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      default:
        return difficulty;
    }
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return const Color(0xFFEF4444);
      default:
        return AppColors.subtitle;
    }
  }

  static Color _scoreColor(double score) {
    if (score >= 0.8) return AppColors.success;
    if (score >= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.image, size: 40, color: Colors.grey.shade300),
      ),
    );
  }
}