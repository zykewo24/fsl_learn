import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/progress_snapshot_model.dart';
import '../../../providers/lesson_provider.dart';

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime time) {
  final local = time.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}

String _formatPercent(double value) {
  return '${(value * 100).toStringAsFixed(0)}%';
}

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(progressSnapshotProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: snapshotAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load progress',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(progressSnapshotProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (snapshot) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(progressSnapshotProvider);
                await ref
                    .read(progressSnapshotProvider.future)
                    .catchError((_) => const ProgressSnapshotModel(
                          levels: [],
                          modules: [],
                          lessons: [],
                          signProgress: {},
                        ));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Progress',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  _ProgressHeader(snapshot: snapshot),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle_outline,
                          value:
                              '${snapshot.completedSigns}/${snapshot.totalSigns}',
                          label: 'Signs mastered',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.replay,
                          value:
                              '${snapshot.totalPracticeCount}',
                          label: 'Practice sessions',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.verified_outlined,
                          value:
                              '${(snapshot.bestAverageScore * 100).toStringAsFixed(0)}%',
                          label: 'Best accuracy',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department_outlined,
                          value: '${snapshot.streakDays}',
                          label: 'Day streak',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (snapshot.levels.isNotEmpty) ...[
                    Text(
                      'Learning Path',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...snapshot.levels.map(
                      (level) => _LevelCard(
                        level: level,
                        snapshot: snapshot,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  Text(
                    'Recently Practiced',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  _buildRecentActivity(snapshot),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
    ProgressSnapshotModel snapshot,
  ) {
    final entries = snapshot.recentActivity();

    if (entries.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Practice a sign to start building your history.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Text(
                'Complete a lesson from the Practice tab to see your activity here.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _RecentActivityRow(entry: entries[i]),
          ],
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final ProgressSnapshotModel snapshot;

  const _ProgressHeader({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Progress',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: snapshot.overallProgress,
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatPercent(snapshot.overallProgress),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'complete',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snapshot.completedSigns} of ${snapshot.totalSigns} signs mastered',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.streakDays} day streak',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.lastPracticedAt == null
                          ? 'No practice yet'
                          : 'Last practiced ${_formatDate(snapshot.lastPracticedAt!)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final ProgressLevel level;
  final ProgressSnapshotModel snapshot;

  const _LevelCard({
    required this.level,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final modules = snapshot.modulesForLevel(level.id);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${level.completedSigns}/${level.totalSigns} signs',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatPercent(level.progress),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: level.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(20),
            ),
            const SizedBox(height: 8),
            if (modules.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No modules in this level yet.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ...modules.map(
                (module) => _ModuleTile(
                  module: module,
                  snapshot: snapshot,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final ProgressModule module;
  final ProgressSnapshotModel snapshot;

  const _ModuleTile({
    required this.module,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final lessons = snapshot.lessonsForModule(module.id);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  module.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${module.completedLessons}/${module.totalLessons} lessons',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: module.progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(20),
          ),
          if (lessons.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final lesson in lessons)
              _LessonRow(lesson: lesson),
          ],
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final ProgressLesson lesson;

  const _LessonRow({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final complete = lesson.totalSigns == 0 || lesson.progress >= 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: complete
                ? Colors.green.shade600
                : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lesson.title,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '${lesson.completedSigns}/${lesson.totalSigns}',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  final SignProgressEntry entry;

  const _RecentActivityRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = entry.lastPracticedAt;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: entry.completed
            ? Colors.green.shade100
            : theme.colorScheme.primary.withValues(alpha: 0.15),
        child: Icon(
          entry.completed ? Icons.check : Icons.school_outlined,
          size: 18,
          color: entry.completed
              ? Colors.green.shade700
              : theme.colorScheme.primary,
        ),
      ),
      title: Text(
        entry.signTitle.isEmpty ? entry.signId : entry.signTitle,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(time == null ? 'Practiced' : _formatDate(time)),
      trailing: Text(
        entry.completed
            ? 'Mastered'
            : '${(entry.bestScore * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          color: entry.completed
              ? Colors.green.shade700
              : Colors.grey.shade600,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}