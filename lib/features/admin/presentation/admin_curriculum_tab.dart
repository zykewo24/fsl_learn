import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/lesson_level_model.dart';
import '../../../models/lesson_model.dart';
import '../../../models/lesson_module_model.dart';
import '../../../models/lesson_sign_model.dart';
import '../models/curriculum_drafts.dart';
import '../providers/admin_curriculum_providers.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_common.dart';
import '../widgets/curriculum_editor_sheet.dart';

/// Table name for each editable entity, used by delete and reorder.
const String _tableLevels = 'lesson_levels';
const String _tableModules = 'lesson_modules';
const String _tableLessons = 'lessons';
const String _tableSigns = 'lesson_signs';

/// Curriculum authoring: a drill-down browser over the
/// level -> module -> lesson -> sign tree with create, edit, reorder,
/// deactivate and delete at every level.
class AdminCurriculumTab extends ConsumerStatefulWidget {
  const AdminCurriculumTab({super.key});

  @override
  ConsumerState<AdminCurriculumTab> createState() =>
      _AdminCurriculumTabState();
}

class _AdminCurriculumTabState extends ConsumerState<AdminCurriculumTab> {
  LessonLevelModel? _level;
  LessonModuleModel? _module;
  LessonModel? _lesson;

  /// Whether a write is in flight, so row controls can be disabled.
  bool _busy = false;

  /// Runs [action], refreshes the tree on success and reports any failure.
  ///
  /// Returns `true` when the write succeeded.
  Future<bool> _mutate(Future<void> Function() action) async {
    if (mounted) setState(() => _busy = true);

    try {
      await action();
    } catch (error) {
      if (mounted) _notify('$error', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    invalidateCurriculum(ref);
    return true;
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : null,
        ),
      );
  }

  Future<void> _create(CurriculumEntity entity) async {
    final result = await showCurriculumEditorSheet(
      context,
      entity: entity,
      heading: 'New ${_singular(entity)}',
      level: entity == CurriculumEntity.level
          ? const LevelDraft(name: '', description: '')
          : null,
      module: entity == CurriculumEntity.module && _level != null
          ? ModuleDraft(levelId: _level!.id, title: '', description: '')
          : null,
      lesson: entity == CurriculumEntity.lesson && _module != null
          ? LessonDraft(moduleId: _module!.id, title: '', description: '')
          : null,
      sign: entity == CurriculumEntity.sign && _lesson != null
          ? SignDraft(
              lessonId: _lesson!.id,
              title: '',
              description: '',
              aiLabel: '',
            )
          : null,
    );

    if (result == null || !mounted) return;

    final service = ref.read(adminServiceProvider);

    final ok = await _mutate(() async {
      switch (result) {
        case LevelEditorResult(:final draft):
          await service.createLevel(draft);
        case ModuleEditorResult(:final draft):
          await service.createModule(draft);
        case LessonEditorResult(:final draft):
          await service.createLesson(draft);
        case SignEditorResult(:final draft):
          await service.createSign(draft);
      }
    });

    if (ok) _notify('Created.');
  }

  /// Confirms a destructive delete, warning about the cascade.
  Future<void> _delete({
    required String table,
    required Object id,
    required String label,
    required String cascadeWarning,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          '“$label” will be deleted, together with everything under it. '
          '$cascadeWarning\n\n'
          'This cannot be undone. To take a sign out of circulation without '
          'losing data, deactivate it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ok = await _mutate(
      () => ref.read(adminServiceProvider).deleteRow(table, id),
    );

    if (!ok || !mounted) return;

    // Deleting the row the drill-down is standing on would leave the
    // breadcrumb pointing at a parent that no longer exists, so step back.
    setState(() {
      if (table == _tableLessons) {
        _lesson = null;
      } else if (table == _tableModules) {
        _lesson = null;
        _module = null;
      } else if (table == _tableLevels) {
        _lesson = null;
        _module = null;
        _level = null;
      }
    });
  }

  Future<void> _toggleSign(LessonSignModel sign) async {
    try {
      await ref
          .read(adminServiceProvider)
          .setSignActive(sign.id, !sign.isActive);
    } catch (error) {
      if (!mounted) return;
      _notify('$error', isError: true);
      return;
    }

    if (!mounted) return;
    invalidateCurriculum(ref);
  }

  /// Moves the row at [index] by [offset] and persists the new ordering.
  ///
  /// Ids are [Object]s rather than strings because `lesson_levels.id` is an
  /// integer column; PostgREST must filter on the value's real type.
  Future<void> _reorder({
    required String table,
    required List<Object> orderedIds,
    required int index,
    required int offset,
    String? parentColumn,
    Object? parentValue,
  }) async {
    final target = index + offset;
    if (target < 0 || target >= orderedIds.length) return;

    final next = List<Object>.of(orderedIds);
    next.insert(target, next.removeAt(index));

    final ok = await _mutate(
      () => ref
          .read(adminServiceProvider)
          .reorderRows(
            table,
            next,
            parentColumn: parentColumn,
            parentValue: parentValue,
          ),
    );

    if (ok) _notify('Order updated.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Breadcrumb(
          level: _level,
          module: _module,
          lesson: _lesson,
          onRoot: () => setState(() {
            _level = null;
            _module = null;
            _lesson = null;
          }),
          onSelectLevel: (value) => setState(() {
            _level = value;
            _module = null;
            _lesson = null;
          }),
          onSelectModule: (value) => setState(() {
            _module = value;
            _lesson = null;
          }),
          onSelectLesson: (value) => setState(() => _lesson = value),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    final lesson = _lesson;
    if (lesson != null) {
      return _SignList(
        lesson: lesson,
        busy: _busy,
        onAdd: () => _create(CurriculumEntity.sign),
        onEdit: _editSign,
        onDelete: (sign) => _delete(
          table: _tableSigns,
          id: sign.id,
          label: sign.title,
          cascadeWarning: 'Learner progress recorded against it is lost.',
        ),
        onToggle: _toggleSign,
        onMove: (index, offset) => _reorderSign(lesson.id, index, offset),
      );
    }

    final module = _module;
    if (module != null) {
      return _LessonList(
        module: module,
        busy: _busy,
        onAdd: () => _create(CurriculumEntity.lesson),
        onSelect: (value) => setState(() => _lesson = value),
        onEdit: (value) => _editLesson(value),
        onDelete: (value) => _delete(
          table: _tableLessons,
          id: value.id,
          label: value.title,
          cascadeWarning: 'Its signs and their learner progress are removed.',
        ),
        onMove: (index, offset) => _reorderLesson(module.id, index, offset),
      );
    }

    final level = _level;
    if (level != null) {
      return _ModuleList(
        level: level,
        busy: _busy,
        onAdd: () => _create(CurriculumEntity.module),
        onSelect: (value) => setState(() => _module = value),
        onEdit: (value) => _editModule(value),
        onDelete: (value) => _delete(
          table: _tableModules,
          id: value.id,
          label: value.title,
          cascadeWarning: 'All of its lessons and signs are removed.',
        ),
        onMove: (index, offset) => _reorderModule(level.id, index, offset),
      );
    }

    return _LevelList(
      busy: _busy,
      onAdd: () => _create(CurriculumEntity.level),
      onSelect: (value) => setState(() => _level = value),
      onEdit: (value) => _editLevel(value),
      onDelete: (value) => _delete(
        table: _tableLevels,
        id: value.id,
        label: value.name,
        cascadeWarning: 'All of its modules, lessons and signs are removed.',
      ),
      onMove: _reorderLevel,
    );
  }

  Future<void> _editLevel(LessonLevelModel level) async {
    final result = await showCurriculumEditorSheet(
      context,
      entity: CurriculumEntity.level,
      heading: 'Edit level',
      level: LevelDraft.fromModel(
        name: level.name,
        description: level.description,
        sortOrder: level.sortOrder,
      ),
    );

    if (result is! LevelEditorResult || !mounted) return;

    final ok = await _mutate(
      () => ref.read(adminServiceProvider).updateLevel(level.id, result.draft),
    );
    if (ok) _notify('Saved.');
  }

  Future<void> _editModule(LessonModuleModel module) async {
    final result = await showCurriculumEditorSheet(
      context,
      entity: CurriculumEntity.module,
      heading: 'Edit module',
      module: ModuleDraft.fromModel(
        levelId: module.levelId,
        title: module.title,
        description: module.description,
        icon: module.icon,
        sortOrder: module.sortOrder,
      ),
    );

    if (result is! ModuleEditorResult || !mounted) return;

    final ok = await _mutate(
      () =>
          ref.read(adminServiceProvider).updateModule(module.id, result.draft),
    );
    if (ok) _notify('Saved.');
  }

  Future<void> _editLesson(LessonModel lesson) async {
    final result = await showCurriculumEditorSheet(
      context,
      entity: CurriculumEntity.lesson,
      heading: 'Edit lesson',
      lesson: LessonDraft.fromModel(
        moduleId: lesson.moduleId,
        title: lesson.title,
        description: lesson.description,
        estimatedMinutes: lesson.estimatedMinutes,
        sortOrder: lesson.sortOrder,
      ),
    );

    if (result is! LessonEditorResult || !mounted) return;

    final ok = await _mutate(
      () => ref.read(adminServiceProvider).updateLesson(lesson.id, result.draft),
    );
    if (ok) _notify('Saved.');
  }

  Future<void> _editSign(LessonSignModel sign) async {
    final result = await showCurriculumEditorSheet(
      context,
      entity: CurriculumEntity.sign,
      heading: 'Edit sign',
      sign: SignDraft.fromModel(
        lessonId: sign.lessonId,
        title: sign.title,
        description: sign.description,
        aiLabel: sign.aiLabel,
        isActive: sign.isActive,
        sortOrder: sign.sortOrder,
      ),
    );

    if (result is! SignEditorResult || !mounted) return;

    final ok = await _mutate(
      () => ref.read(adminServiceProvider).updateSign(sign.id, result.draft),
    );
    if (ok) _notify('Saved.');
  }

  // The reorder helpers read the current ordering from the provider cache so
  // the row widgets only have to report an index and a direction.
  Future<void> _reorderLevel(int index, int offset) {
    // Level ids stay integers: `lesson_levels.id` is an integer column, and
    // PostgREST has to filter on the value's real type.
    final ids = (ref.read(adminLevelsProvider).valueOrNull ?? const [])
        .map((level) => level.id)
        .toList(growable: false);

    return _reorder(
      table: _tableLevels,
      orderedIds: ids,
      index: index,
      offset: offset,
    );
  }

  Future<void> _reorderModule(int levelId, int index, int offset) {
    final ids = (ref.read(adminModulesProvider(levelId)).valueOrNull ?? const [])
        .map((module) => module.id)
        .toList(growable: false);

    return _reorder(
      table: _tableModules,
      orderedIds: ids,
      index: index,
      offset: offset,
      parentColumn: 'level_id',
      parentValue: levelId,
    );
  }

  Future<void> _reorderLesson(String moduleId, int index, int offset) {
    final ids =
        (ref.read(adminLessonsProvider(moduleId)).valueOrNull ?? const [])
            .map((lesson) => lesson.id)
            .toList(growable: false);

    return _reorder(
      table: _tableLessons,
      orderedIds: ids,
      index: index,
      offset: offset,
      parentColumn: 'module_id',
      parentValue: moduleId,
    );
  }

  Future<void> _reorderSign(String lessonId, int index, int offset) {
    final ids = (ref.read(adminSignsProvider(lessonId)).valueOrNull ?? const [])
        .map((sign) => sign.id)
        .toList(growable: false);

    return _reorder(
      table: _tableSigns,
      orderedIds: ids,
      index: index,
      offset: offset,
      parentColumn: 'lesson_id',
      parentValue: lessonId,
    );
  }

  static String _singular(CurriculumEntity entity) => switch (entity) {
        CurriculumEntity.level => 'level',
        CurriculumEntity.module => 'module',
        CurriculumEntity.lesson => 'lesson',
        CurriculumEntity.sign => 'sign',
      };
}

// ==========================================================
// BREADCRUMB
// ==========================================================

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.level,
    required this.module,
    required this.lesson,
    required this.onRoot,
    required this.onSelectLevel,
    required this.onSelectModule,
    required this.onSelectLesson,
  });

  final LessonLevelModel? level;
  final LessonModuleModel? module;
  final LessonModel? lesson;
  final VoidCallback onRoot;
  final ValueChanged<LessonLevelModel> onSelectLevel;
  final ValueChanged<LessonModuleModel> onSelectModule;
  final ValueChanged<LessonModel> onSelectLesson;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _Crumb(
            label: 'Levels',
            icon: Icons.layers_outlined,
            selected: level == null,
            onTap: onRoot,
          ),
          if (level != null) ...[
            const _CrumbSeparator(),
            _Crumb(
              label: level!.name,
              icon: Icons.layers_outlined,
              selected: module == null,
              onTap: () => onSelectLevel(level!),
            ),
          ],
          if (module != null) ...[
            const _CrumbSeparator(),
            _Crumb(
              label: module!.title,
              icon: Icons.widgets_outlined,
              selected: lesson == null,
              onTap: () => onSelectModule(module!),
            ),
          ],
          if (lesson != null) ...[
            const _CrumbSeparator(),
            _Crumb(
              label: lesson!.title,
              icon: Icons.back_hand_outlined,
              selected: true,
              onTap: () => onSelectLesson(lesson!),
            ),
          ],
        ],
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : AppColors.subtitle,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrumbSeparator extends StatelessWidget {
  const _CrumbSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.chevron_right, size: 18, color: AppColors.subtitle),
    );
  }
}

// ==========================================================
// SHARED LIST CHROME
// ==========================================================

/// Frames one drill-down level of the tree.
///
/// The add button is pinned below the content rather than placed inside the
/// list, so it stays reachable when the level being edited has no rows yet —
/// which is exactly when it is most needed.
class _EntityPanel extends StatelessWidget {
  const _EntityPanel({
    required this.addLabel,
    required this.onAdd,
    required this.busy,
    required this.content,
  });

  final String addLabel;
  final VoidCallback onAdd;
  final bool busy;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: content),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: FilledButton.icon(
                onPressed: busy ? null : onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(addLabel),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single row in a drill-down list.
///
/// [onTap] moves deeper into the tree; it is omitted for leaf rows such as
/// signs, which have nothing below them.
class _EntityTile extends StatelessWidget {
  const _EntityTile({
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
    this.meta,
    this.onTap,
    this.onMoveUp,
    this.onMoveDown,
    this.trailing,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final String? meta;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  /// Extra control rendered before the overflow menu, e.g. an active switch.
  final Widget? trailing;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: busy ? null : onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subtitle,
                        ),
                      ),
                    ],
                    if (meta != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.subtitle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
          PopupMenuButton<String>(
            tooltip: 'Actions for $title',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'up':
                  onMoveUp?.call();
                case 'down':
                  onMoveDown?.call();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ],
                ),
              ),
              if (onMoveUp != null)
                const PopupMenuItem(
                  value: 'up',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 18),
                      SizedBox(width: 10),
                      Text('Move up'),
                    ],
                  ),
                ),
              if (onMoveDown != null)
                const PopupMenuItem(
                  value: 'down',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_downward, size: 18),
                      SizedBox(width: 10),
                      Text('Move down'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 10),
                    Text('Delete'),
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

// ==========================================================
// LEVELS
// ==========================================================

class _LevelList extends ConsumerWidget {
  const _LevelList({
    required this.onAdd,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.busy,
  });

  final VoidCallback onAdd;
  final ValueChanged<LessonLevelModel> onSelect;
  final ValueChanged<LessonLevelModel> onEdit;
  final void Function(LessonLevelModel) onDelete;
  final void Function(int index, int offset) onMove;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminLevelsProvider);
    final levels = async.valueOrNull ?? const <LessonLevelModel>[];

    return _EntityPanel(
      addLabel: 'Add level',
      onAdd: onAdd,
      busy: busy,
      content: AdminStatusView(
        isLoading: async.isLoading,
        error: async.hasError ? async.error : null,
        isEmpty: levels.isEmpty,
        onRetry: () => ref.invalidate(adminLevelsProvider),
        emptyIcon: Icons.layers_outlined,
        emptyMessage: 'No levels yet. Add one to start building the curriculum.',
        builder: (context) => _rows(
          items: levels,
          onRefresh: () async {
            ref.invalidate(adminLevelsProvider);
            await ref
                .read(adminLevelsProvider.future)
                .catchError((_) => const <LessonLevelModel>[]);
          },
          itemBuilder: (context, level, index) => _EntityTile(
            title: level.name,
            subtitle: level.description,
            meta: 'Order ${level.sortOrder}',
            busy: busy,
            onTap: () => onSelect(level),
            onEdit: () => onEdit(level),
            onDelete: () => onDelete(level),
            onMoveUp: index > 0 ? () => onMove(index, -1) : null,
            onMoveDown:
                index < levels.length - 1 ? () => onMove(index, 1) : null,
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// MODULES
// ==========================================================

class _ModuleList extends ConsumerWidget {
  const _ModuleList({
    required this.level,
    required this.onAdd,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.busy,
  });

  final LessonLevelModel level;
  final VoidCallback onAdd;
  final ValueChanged<LessonModuleModel> onSelect;
  final ValueChanged<LessonModuleModel> onEdit;
  final void Function(LessonModuleModel) onDelete;
  final void Function(int index, int offset) onMove;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminModulesProvider(level.id));
    final modules = async.valueOrNull ?? const <LessonModuleModel>[];

    return _EntityPanel(
      addLabel: 'Add module',
      onAdd: onAdd,
      busy: busy,
      content: AdminStatusView(
        isLoading: async.isLoading,
        error: async.hasError ? async.error : null,
        isEmpty: modules.isEmpty,
        onRetry: () => ref.invalidate(adminModulesProvider(level.id)),
        emptyIcon: Icons.widgets_outlined,
        emptyMessage: 'No modules in “${level.name}” yet.',
        builder: (context) => _rows(
          items: modules,
          onRefresh: () async {
            ref.invalidate(adminModulesProvider(level.id));
            await ref
                .read(adminModulesProvider(level.id).future)
                .catchError((_) => const <LessonModuleModel>[]);
          },
          itemBuilder: (context, module, index) => _EntityTile(
            title: module.title,
            subtitle: module.description,
            meta: '${module.totalLessons} '
                '${module.totalLessons == 1 ? "lesson" : "lessons"}',
            busy: busy,
            onTap: () => onSelect(module),
            onEdit: () => onEdit(module),
            onDelete: () => onDelete(module),
            onMoveUp: index > 0 ? () => onMove(index, -1) : null,
            onMoveDown:
                index < modules.length - 1 ? () => onMove(index, 1) : null,
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// LESSONS
// ==========================================================

class _LessonList extends ConsumerWidget {
  const _LessonList({
    required this.module,
    required this.onAdd,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.busy,
  });

  final LessonModuleModel module;
  final VoidCallback onAdd;
  final ValueChanged<LessonModel> onSelect;
  final ValueChanged<LessonModel> onEdit;
  final void Function(LessonModel) onDelete;
  final void Function(int index, int offset) onMove;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminLessonsProvider(module.id));
    final lessons = async.valueOrNull ?? const <LessonModel>[];

    return _EntityPanel(
      addLabel: 'Add lesson',
      onAdd: onAdd,
      busy: busy,
      content: AdminStatusView(
        isLoading: async.isLoading,
        error: async.hasError ? async.error : null,
        isEmpty: lessons.isEmpty,
        onRetry: () => ref.invalidate(adminLessonsProvider(module.id)),
        emptyIcon: Icons.menu_book_outlined,
        emptyMessage: 'No lessons in “${module.title}” yet.',
        builder: (context) => _rows(
          items: lessons,
          onRefresh: () async {
            ref.invalidate(adminLessonsProvider(module.id));
            await ref
                .read(adminLessonsProvider(module.id).future)
                .catchError((_) => const <LessonModel>[]);
          },
          itemBuilder: (context, lesson, index) => _EntityTile(
            title: lesson.title,
            subtitle: lesson.description,
            meta: '${lesson.totalSigns} signs · '
                '${lesson.estimatedMinutes} min · order ${lesson.sortOrder}',
            busy: busy,
            onTap: () => onSelect(lesson),
            onEdit: () => onEdit(lesson),
            onDelete: () => onDelete(lesson),
            onMoveUp: index > 0 ? () => onMove(index, -1) : null,
            onMoveDown:
                index < lessons.length - 1 ? () => onMove(index, 1) : null,
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// SIGNS
// ==========================================================

class _SignList extends ConsumerWidget {
  const _SignList({
    required this.lesson,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onMove,
    required this.busy,
  });

  final LessonModel lesson;
  final VoidCallback onAdd;
  final ValueChanged<LessonSignModel> onEdit;
  final void Function(LessonSignModel) onDelete;
  final ValueChanged<LessonSignModel> onToggle;
  final void Function(int index, int offset) onMove;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminSignsProvider(lesson.id));
    final signs = async.valueOrNull ?? const <LessonSignModel>[];

    return _EntityPanel(
      addLabel: 'Add sign',
      onAdd: onAdd,
      busy: busy,
      content: AdminStatusView(
        isLoading: async.isLoading,
        error: async.hasError ? async.error : null,
        isEmpty: signs.isEmpty,
        onRetry: () => ref.invalidate(adminSignsProvider(lesson.id)),
        emptyIcon: Icons.back_hand_outlined,
        emptyMessage: 'No signs in “${lesson.title}” yet.',
        builder: (context) => _rows(
          items: signs,
          onRefresh: () async {
            ref.invalidate(adminSignsProvider(lesson.id));
            await ref
                .read(adminSignsProvider(lesson.id).future)
                .catchError((_) => const <LessonSignModel>[]);
          },
          itemBuilder: (context, sign, index) => _EntityTile(
            title: sign.title,
            subtitle: sign.description,
            meta: 'AI label: ${sign.aiLabel.isEmpty ? "—" : sign.aiLabel}',
            busy: busy,
            onEdit: () => onEdit(sign),
            onDelete: () => onDelete(sign),
            onMoveUp: index > 0 ? () => onMove(index, -1) : null,
            onMoveDown:
                index < signs.length - 1 ? () => onMove(index, 1) : null,
            trailing: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Switch.adaptive(
                    value: sign.isActive,
                    onChanged: busy ? null : (_) => onToggle(sign),
                  ),
                  Text(
                    sign.isActive ? 'Active' : 'Hidden',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.subtitle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pull-to-refresh list shared by all four drill-down levels.
Widget _rows<T>({
  required List<T> items,
  required Future<void> Function() onRefresh,
  required Widget Function(BuildContext context, T item, int index) itemBuilder,
}) {
  return RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => itemBuilder(context, items[index], index),
    ),
  );
}
