import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/lesson_model.dart';

class LessonTile extends StatelessWidget {
  final LessonModel lesson;
  final double progress;
  final bool completed;
  final VoidCallback onTap;

  const LessonTile({
    super.key,
    required this.lesson,
    required this.onTap,
    this.progress = 0.0,
    this.completed = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: completed
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Lesson number or checkmark
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completed
                      ? AppColors.success.withValues(alpha: 0.12)
                      : theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: completed
                    ? const Icon(
                        Icons.check,
                        size: 20,
                        color: AppColors.success,
                      )
                    : Icon(
                        Icons.sign_language,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
              ),

              const SizedBox(width: 14),

              // Title, description, progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: completed ? AppColors.subtitle : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (progress > 0 && !completed) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                backgroundColor:
                                    Colors.grey.shade200,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Trailing: time + arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (lesson.estimatedMinutes > 0)
                    Text(
                      '${lesson.estimatedMinutes} min',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}