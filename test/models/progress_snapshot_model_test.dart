import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/models/progress_snapshot_model.dart';

void main() {
  final now = DateTime.now();

  final levelRows = [
    {'id': 1, 'name': 'Beginner'},
    {'id': 2, 'name': 'Intermediate'},
  ];

  final moduleRows = [
    {'id': 'm1', 'level_id': 1, 'title': 'Module One', 'total_lessons': 2},
    {'id': 'm2', 'level_id': 1, 'title': 'Module Two', 'total_lessons': 1},
    {'id': 'm3', 'level_id': 2, 'title': 'Module Three', 'total_lessons': 1},
  ];

  final lessonRows = [
    {
      'id': 'l1',
      'module_id': 'm1',
      'title': 'Lesson One',
      'description': 'First',
      'estimated_minutes': 5,
      'sort_order': 1,
    },
    {
      'id': 'l2',
      'module_id': 'm1',
      'title': 'Lesson Two',
      'description': 'Second',
      'estimated_minutes': 5,
      'sort_order': 2,
    },
    {
      'id': 'l3',
      'module_id': 'm2',
      'title': 'Lesson Three',
      'description': 'Third',
      'estimated_minutes': 5,
      'sort_order': 3,
    },
    {
      'id': 'l4',
      'module_id': 'm3',
      'title': 'Lesson Four',
      'description': 'Fourth',
      'estimated_minutes': 5,
      'sort_order': 4,
    },
  ];

  final signRows = [
    {'id': 's1', 'lesson_id': 'l1', 'title': 'A'},
    {'id': 's2', 'lesson_id': 'l1', 'title': 'B'},
    {'id': 's3', 'lesson_id': 'l2', 'title': 'C'},
    {'id': 's4', 'lesson_id': 'l2', 'title': 'D'},
    {'id': 's5', 'lesson_id': 'l3', 'title': 'E'},
    {'id': 's6', 'lesson_id': 'l4', 'title': 'F'},
  ];

  final progressRows = [
    {
      'sign_id': 's1',
      'completed': true,
      'practice_count': 3,
      'best_score': 0.9,
      'last_practiced_at': now
          .subtract(const Duration(days: 1))
          .toIso8601String(),
    },
    {
      'sign_id': 's3',
      'completed': true,
      'practice_count': 1,
      'best_score': 0.8,
      'last_practiced_at': now.toIso8601String(),
    },
    {
      'sign_id': 's4',
      'completed': true,
      'practice_count': 2,
      'best_score': 0.7,
      'last_practiced_at': now
          .subtract(const Duration(days: 3))
          .toIso8601String(),
    },
  ];

  ProgressSnapshotModel build() {
    return ProgressSnapshotModel.fromData(
      levelRows: levelRows,
      moduleRows: moduleRows,
      lessonRows: lessonRows,
      signRows: signRows,
      progressRows: progressRows,
    );
  }

  test('computes totals and per-level progress', () {
    final snapshot = build();

    expect(snapshot.totalSigns, 6);
    expect(snapshot.completedSigns, 3);
    expect(snapshot.overallProgress, closeTo(0.5, 0.001));

    final beginner = snapshot.levels.first;
    expect(beginner.id, 1);
    expect(beginner.totalSigns, 5);
    expect(beginner.completedSigns, 3);

    final moduleOne = snapshot.modules.first;
    expect(moduleOne.id, 'm1');
    expect(moduleOne.totalLessons, 2);
    expect(moduleOne.completedLessons, 1);
    expect(moduleOne.progress, greaterThan(0));
  });

  test('computes streak, averages, and practice counts', () {
    final snapshot = build();

    expect(snapshot.totalPracticeCount, 6);
    expect(snapshot.bestAverageScore, closeTo(0.8, 0.001));
    expect(snapshot.streakDays, 2);
    expect(snapshot.lastPracticedAt, isNotNull);
  });

  test('reports the first incomplete lesson', () {
    final snapshot = build();

    final next = snapshot.nextLesson();
    expect(next, isNotNull);
    expect(next!.id, 'l1');

    final model = next.toLessonModel();
    expect(model.id, 'l1');
    expect(model.moduleId, 'm1');
    expect(model.title, 'Lesson One');
  });

  test('orders lessons by module then lesson sort order', () {
    // The raw query orders lessons only by their own `sort_order`, which
    // repeats per module. The model must re-sort by (module, lesson) so the
    // learning path follows the module hierarchy.
    final snapshot = ProgressSnapshotModel.fromData(
      levelRows: [
        {'id': 1, 'name': 'Beginner'},
      ],
      moduleRows: [
        {
          'id': 'm2',
          'level_id': 1,
          'title': 'Module Two',
          'total_lessons': 1,
          'sort_order': 2,
        },
        {
          'id': 'm1',
          'level_id': 1,
          'title': 'Module One',
          'total_lessons': 2,
          'sort_order': 1,
        },
      ],
      lessonRows: [
        {
          'id': 'l2',
          'module_id': 'm1',
          'title': 'L2',
          'description': '',
          'estimated_minutes': 5,
          'sort_order': 2,
        },
        {
          'id': 'l3',
          'module_id': 'm2',
          'title': 'L3',
          'description': '',
          'estimated_minutes': 5,
          'sort_order': 1,
        },
        {
          'id': 'l1',
          'module_id': 'm1',
          'title': 'L1',
          'description': '',
          'estimated_minutes': 5,
          'sort_order': 1,
        },
      ],
      signRows: const [
        {'id': 's1', 'lesson_id': 'l1', 'title': 'A'},
        {'id': 's2', 'lesson_id': 'l1', 'title': 'B'},
        {'id': 's3', 'lesson_id': 'l2', 'title': 'C'},
        {'id': 's4', 'lesson_id': 'l3', 'title': 'D'},
      ],
      progressRows: const [],
    );

    expect(
      snapshot.lessons.map((lesson) => lesson.id).toList(),
      ['l1', 'l2', 'l3'],
    );
    expect(snapshot.nextLesson()?.id, 'l1');
  });
}