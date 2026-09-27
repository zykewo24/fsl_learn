/// The four levels of the curriculum tree an admin can edit.
///
/// The hierarchy is `level -> module -> lesson -> sign`, mirroring the
/// `lesson_levels` / `lesson_modules` / `lessons` / `lesson_signs` tables.
enum CurriculumEntity {
  level('Levels'),
  module('Modules'),
  lesson('Lessons'),
  sign('Signs');

  const CurriculumEntity(this.label);

  /// Plural label used in section headers and breadcrumbs.
  final String label;
}

/// Editable fields of a `lesson_levels` row.
class LevelDraft {
  final String name;
  final String description;
  final int sortOrder;

  const LevelDraft({
    required this.name,
    required this.description,
    this.sortOrder = 0,
  });

  /// Prefills the form from an existing row.
  factory LevelDraft.fromModel({
    required String name,
    required String description,
    required int sortOrder,
  }) {
    return LevelDraft(
      name: name,
      description: description,
      sortOrder: sortOrder,
    );
  }

  Map<String, dynamic> toRow() => {
        'name': name.trim(),
        'description': description.trim(),
        'sort_order': sortOrder,
      };
}

/// Editable fields of a `lesson_modules` row.
///
/// `total_lessons` is deliberately absent: it is a denormalised cache that
/// the app only reads for display, and admins would have to keep it in sync by
/// hand. See `supabase/admin_roles_and_rls.sql` for the trigger that maintains
/// it.
class ModuleDraft {
  final int levelId;
  final String title;
  final String description;
  final String icon;
  final int sortOrder;

  const ModuleDraft({
    required this.levelId,
    required this.title,
    required this.description,
    this.icon = '',
    this.sortOrder = 0,
  });

  factory ModuleDraft.fromModel({
    required int levelId,
    required String title,
    required String description,
    required String? icon,
    required int sortOrder,
  }) {
    return ModuleDraft(
      levelId: levelId,
      title: title,
      description: description,
      icon: icon ?? '',
      sortOrder: sortOrder,
    );
  }

  Map<String, dynamic> toRow() => {
        'level_id': levelId,
        'title': title.trim(),
        'description': description.trim(),
        'icon': icon.trim(),
        'sort_order': sortOrder,
      };
}

/// Editable fields of a `lessons` row.
///
/// `total_signs` is derived by a database trigger from the number of active
/// signs, exactly as `total_lessons` is for a module, so it is not editable.
class LessonDraft {
  final String moduleId;
  final String title;
  final String description;
  final int estimatedMinutes;
  final int sortOrder;

  const LessonDraft({
    required this.moduleId,
    required this.title,
    required this.description,
    this.estimatedMinutes = 5,
    this.sortOrder = 0,
  });

  factory LessonDraft.fromModel({
    required String moduleId,
    required String title,
    required String description,
    required int estimatedMinutes,
    required int sortOrder,
  }) {
    return LessonDraft(
      moduleId: moduleId,
      title: title,
      description: description,
      estimatedMinutes: estimatedMinutes,
      sortOrder: sortOrder,
    );
  }

  Map<String, dynamic> toRow() => {
        'module_id': moduleId,
        'title': title.trim(),
        'description': description.trim(),
        'estimated_minutes': estimatedMinutes,
        'sort_order': sortOrder,
      };
}

/// Editable fields of a `lesson_signs` row.
///
/// [aiLabel] is the label the on-device recogniser reports, so it must match a
/// label the recogniser can actually detect — changing it to an unknown value
/// makes the sign impossible to pass in practice.
class SignDraft {
  final String lessonId;
  final String title;
  final String description;
  final String aiLabel;
  final bool isActive;
  final int sortOrder;

  const SignDraft({
    required this.lessonId,
    required this.title,
    required this.description,
    required this.aiLabel,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory SignDraft.fromModel({
    required String lessonId,
    required String title,
    required String description,
    required String aiLabel,
    required bool isActive,
    required int sortOrder,
  }) {
    return SignDraft(
      lessonId: lessonId,
      title: title,
      description: description,
      aiLabel: aiLabel,
      isActive: isActive,
      sortOrder: sortOrder,
    );
  }

  Map<String, dynamic> toRow() => {
        'lesson_id': lessonId,
        'title': title.trim(),
        'description': description.trim(),
        'ai_label': aiLabel.trim(),
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}
