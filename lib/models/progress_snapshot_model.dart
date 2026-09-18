import 'lesson_model.dart';

class SignProgressEntry {
  final String signId;
  final String signTitle;
  final bool completed;
  final int practiceCount;
  final double bestScore;
  final DateTime? lastPracticedAt;

  const SignProgressEntry({
    required this.signId,
    required this.signTitle,
    required this.completed,
    required this.practiceCount,
    required this.bestScore,
    required this.lastPracticedAt,
  });
}

class ProgressLevel {
  final int id;
  final String name;
  final int totalSigns;
  final int completedSigns;

  const ProgressLevel({
    required this.id,
    required this.name,
    required this.totalSigns,
    required this.completedSigns,
  });

  double get progress =>
      totalSigns == 0 ? 0 : completedSigns / totalSigns;
}

class ProgressModule {
  final String id;
  final int levelId;
  final String title;
  final int totalLessons;
  final int completedLessons;
  final int totalSigns;
  final int completedSigns;

  const ProgressModule({
    required this.id,
    required this.levelId,
    required this.title,
    required this.totalLessons,
    required this.completedLessons,
    required this.totalSigns,
    required this.completedSigns,
  });

  double get progress =>
      totalSigns == 0 ? 0 : completedSigns / totalSigns;
}

class ProgressLesson {
  final String id;
  final String moduleId;
  final String title;
  final String description;
  final int totalSigns;
  final int completedSigns;
  final int estimatedMinutes;
  final int sortOrder;

  const ProgressLesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.totalSigns,
    required this.completedSigns,
    required this.estimatedMinutes,
    required this.sortOrder,
  });

  double get progress =>
      totalSigns == 0 ? 0 : completedSigns / totalSigns;

  LessonModel toLessonModel() {
    return LessonModel(
      id: id,
      moduleId: moduleId,
      title: title,
      description: description,
      totalSigns: totalSigns,
      estimatedMinutes: estimatedMinutes,
      sortOrder: sortOrder,
    );
  }
}

class ProgressSnapshotModel {
  final List<ProgressLevel> levels;
  final List<ProgressModule> modules;
  final List<ProgressLesson> lessons;
  final Map<String, SignProgressEntry> signProgress;

  const ProgressSnapshotModel({
    required this.levels,
    required this.modules,
    required this.lessons,
    required this.signProgress,
  });

  int get totalSigns {
    var total = 0;
    for (final lesson in lessons) {
      total += lesson.totalSigns;
    }
    return total;
  }

  int get completedSigns {
    var total = 0;
    for (final lesson in lessons) {
      total += lesson.completedSigns;
    }
    return total;
  }

  double get overallProgress =>
      totalSigns == 0 ? 0 : completedSigns / totalSigns;

  int get practicedSignCount => signProgress.length;

  int get totalPracticeCount {
    var total = 0;
    for (final entry in signProgress.values) {
      total += entry.practiceCount;
    }
    return total;
  }

  double get bestAverageScore {
    final entries = signProgress.values
        .where((e) => e.practiceCount > 0)
        .toList();

    if (entries.isEmpty) return 0;

    var sum = 0.0;
    for (final entry in entries) {
      sum += entry.bestScore;
    }

    return sum / entries.length;
  }

  DateTime? get lastPracticedAt {
    DateTime? latest;

    for (final entry in signProgress.values) {
      final time = entry.lastPracticedAt;
      if (time == null) continue;
      if (latest == null || time.isAfter(latest)) {
        latest = time;
      }
    }

    return latest;
  }

  int get streakDays {
    final dates = <String>{};

    for (final entry in signProgress.values) {
      final time = entry.lastPracticedAt;
      if (time == null) continue;
      dates.add(_dateKey(time));
    }

    if (dates.isEmpty) return 0;

    var day = DateTime.now();
    var streak = 0;

    if (!dates.contains(_dateKey(day))) {
      day = DateTime(day.year, day.month, day.day - 1);
    }

    while (dates.contains(_dateKey(day))) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }

    return streak;
  }

  ProgressLesson? nextLesson() {
    for (final lesson in lessons) {
      if (lesson.totalSigns > 0 && lesson.progress < 1.0) {
        return lesson;
      }
    }

    return null;
  }

  List<SignProgressEntry> recentActivity([int limit = 8]) {
    final entries = signProgress.values
        .where((e) => e.lastPracticedAt != null)
        .toList()
      ..sort((a, b) => b.lastPracticedAt!.compareTo(a.lastPracticedAt!));

    return entries.take(limit).toList();
  }

  List<ProgressLesson> lessonsForModule(String moduleId) {
    return lessons
        .where((lesson) => lesson.moduleId == moduleId)
        .toList();
  }

  List<ProgressModule> modulesForLevel(int levelId) {
    return modules
        .where((module) => module.levelId == levelId)
        .toList();
  }

  static String _dateKey(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${local.month}-${local.day}';
  }

  factory ProgressSnapshotModel.fromData({
    required List<dynamic> levelRows,
    required List<dynamic> moduleRows,
    required List<dynamic> lessonRows,
    required List<dynamic> signRows,
    required List<dynamic> progressRows,
  }) {
    final signLessonId = <String, String>{};
    final signTitle = <String, String>{};
    final lessonModuleId = <String, String>{};
    final moduleLevelId = <String, int>{};
    final moduleTitle = <String, String>{};

    final lessonTitle = <String, String>{};
    final lessonDescription = <String, String>{};
    final lessonMinutes = <String, int>{};
    final lessonSortOrder = <String, int>{};
    final orderedLessonIds = <String>[];
    final moduleSortOrder = <String, int>{};

    for (final row in signRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) continue;

      signLessonId[id] = map['lesson_id'] as String? ?? '';
      signTitle[id] = map['title'] as String? ?? '';
    }

    for (final row in lessonRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) continue;

      orderedLessonIds.add(id);
      lessonModuleId[id] = map['module_id'] as String? ?? '';
      lessonTitle[id] = map['title'] as String? ?? '';
      lessonDescription[id] = map['description'] as String? ?? '';
      lessonMinutes[id] = map['estimated_minutes'] as int? ?? 0;
      lessonSortOrder[id] = map['sort_order'] as int? ?? 0;
    }

    for (final row in moduleRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) continue;

      moduleLevelId[id] = map['level_id'] as int? ?? 0;
      moduleTitle[id] = map['title'] as String? ?? '';
      moduleSortOrder[id] = map['sort_order'] as int? ?? 0;
    }

    final progressBySign = <String, SignProgressEntry>{};

    for (final row in progressRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final signId = map['sign_id'] as String? ?? '';
      if (signId.isEmpty) continue;

      final rawTime = map['last_practiced_at'];

      progressBySign[signId] = SignProgressEntry(
        signId: signId,
        signTitle: signTitle[signId] ?? '',
        completed: map['completed'] == true,
        practiceCount: map['practice_count'] as int? ?? 0,
        bestScore: (map['best_score'] as num?)?.toDouble() ?? 0,
        lastPracticedAt: rawTime == null
            ? null
            : DateTime.tryParse(rawTime.toString()),
      );
    }

    final lessonTotalSigns = <String, int>{};
    final lessonCompletedSigns = <String, int>{};

    for (final row in signRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final lessonId = map['lesson_id'] as String? ?? '';
      if (lessonId.isEmpty) continue;

      lessonTotalSigns[lessonId] =
          (lessonTotalSigns[lessonId] ?? 0) + 1;
    }

    for (final entry in progressBySign.values) {
      if (!entry.completed) continue;

      final lessonId = signLessonId[entry.signId] ?? '';
      if (lessonId.isEmpty) continue;

      lessonCompletedSigns[lessonId] =
          (lessonCompletedSigns[lessonId] ?? 0) + 1;
    }

    final lessons = <ProgressLesson>[];

    for (final lessonId in orderedLessonIds) {
      final total = lessonTotalSigns[lessonId] ?? 0;

      lessons.add(ProgressLesson(
        id: lessonId,
        moduleId: lessonModuleId[lessonId] ?? '',
        title: lessonTitle[lessonId] ?? '',
        description: lessonDescription[lessonId] ?? '',
        totalSigns: total,
        completedSigns: lessonCompletedSigns[lessonId] ?? 0,
        estimatedMinutes: lessonMinutes[lessonId] ?? 0,
        sortOrder: lessonSortOrder[lessonId] ?? 0,
      ));
    }

    // The raw query orders every lesson only by its own `sort_order`, which
    // repeats across modules. Sort by module first, then lesson, so the
    // learning path (and `nextLesson`) follows the intended hierarchy.
    lessons.sort((a, b) {
      final moduleCompare =
          (moduleSortOrder[a.moduleId] ?? 0)
              .compareTo(moduleSortOrder[b.moduleId] ?? 0);
      if (moduleCompare != 0) return moduleCompare;
      return a.sortOrder.compareTo(b.sortOrder);
    });

    final moduleTotalSigns = <String, int>{};
    final moduleCompletedSigns = <String, int>{};
    final moduleTotalLessons = <String, int>{};

    for (final row in moduleRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) continue;
      moduleTotalLessons[id] = map['total_lessons'] as int? ?? 0;
    }

    for (final lesson in lessons) {
      final moduleId = lesson.moduleId;
      if (moduleId.isEmpty) continue;

      moduleTotalSigns[moduleId] =
          (moduleTotalSigns[moduleId] ?? 0) + lesson.totalSigns;
      moduleCompletedSigns[moduleId] =
          (moduleCompletedSigns[moduleId] ?? 0) +
              lesson.completedSigns;
    }

    final modules = <ProgressModule>[];

    for (final row in moduleRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final moduleId = map['id'] as String? ?? '';
      if (moduleId.isEmpty) continue;

      final moduleLessons =
          lessonsFor(lessons, moduleId);

      final completedLessons = moduleLessons
          .where((lesson) =>
              lesson.totalSigns > 0 && lesson.progress >= 1.0)
          .length;

      modules.add(ProgressModule(
        id: moduleId,
        levelId: moduleLevelId[moduleId] ?? 0,
        title: moduleTitle[moduleId] ?? '',
        totalLessons: moduleTotalLessons[moduleId] ?? 0,
        completedLessons: completedLessons,
        totalSigns: moduleTotalSigns[moduleId] ?? 0,
        completedSigns: moduleCompletedSigns[moduleId] ?? 0,
      ));
    }

    final levelTotalSigns = <int, int>{};
    final levelCompletedSigns = <int, int>{};

    for (final module in modules) {
      levelTotalSigns[module.levelId] =
          (levelTotalSigns[module.levelId] ?? 0) +
              module.totalSigns;
      levelCompletedSigns[module.levelId] =
          (levelCompletedSigns[module.levelId] ?? 0) +
              module.completedSigns;
    }

    final levelOrder = <int>[];
    final levelNames = <int, String>{};

    for (final row in levelRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as int? ?? 0;
      levelOrder.add(id);
      levelNames[id] = map['name'] as String? ?? 'Level $id';
    }

    final levels = <ProgressLevel>[];

    for (final id in levelOrder) {
      levels.add(ProgressLevel(
        id: id,
        name: levelNames[id] ?? 'Level $id',
        totalSigns: levelTotalSigns[id] ?? 0,
        completedSigns: levelCompletedSigns[id] ?? 0,
      ));
    }

    return ProgressSnapshotModel(
      levels: levels,
      modules: modules,
      lessons: lessons,
      signProgress: progressBySign,
    );
  }

  static List<ProgressLesson> lessonsFor(
    List<ProgressLesson> lessons,
    String moduleId,
  ) {
    return lessons
        .where((lesson) => lesson.moduleId == moduleId)
        .toList();
  }
}