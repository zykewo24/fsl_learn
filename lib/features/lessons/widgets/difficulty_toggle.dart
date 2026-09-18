import 'package:flutter/material.dart';

import '../../../models/lesson_level_model.dart';

class DifficultyToggle extends StatelessWidget {
  final List<LessonLevelModel> levels;
  final int selectedLevel;
  final ValueChanged<int> onChanged;

  const DifficultyToggle({
    super.key,
    required this.levels,
    required this.selectedLevel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: levels.map((level) {
          final isSelected = selectedLevel == level.id;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(level.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  level.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}