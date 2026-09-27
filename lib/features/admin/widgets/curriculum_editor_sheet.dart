import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/curriculum_drafts.dart';

/// What an editor sheet produced. Returned from `showCurriculumEditorSheet` so
/// the caller can dispatch to the right service method without re-inspecting
/// the form.
sealed class CurriculumEditorResult {
  const CurriculumEditorResult();
}

class LevelEditorResult extends CurriculumEditorResult {
  const LevelEditorResult(this.draft);
  final LevelDraft draft;
}

class ModuleEditorResult extends CurriculumEditorResult {
  const ModuleEditorResult(this.draft);
  final ModuleDraft draft;
}

class LessonEditorResult extends CurriculumEditorResult {
  const LessonEditorResult(this.draft);
  final LessonDraft draft;
}

class SignEditorResult extends CurriculumEditorResult {
  const SignEditorResult(this.draft);
  final SignDraft draft;
}

/// Opens the create/edit form for [entity] and resolves to the edited draft, or
/// `null` if the user cancelled.
///
/// Exactly one of the draft arguments must be supplied: the pre-filled draft to
/// edit, or an empty one carrying the parent id for a create. A mismatch
/// throws [ArgumentError] rather than silently opening a form bound to a null
/// parent.
Future<CurriculumEditorResult?> showCurriculumEditorSheet(
  BuildContext context, {
  required CurriculumEntity entity,
  required String heading,
  LevelDraft? level,
  ModuleDraft? module,
  LessonDraft? lesson,
  SignDraft? sign,
}) {
  final child = switch (entity) {
    CurriculumEntity.level => _LevelForm(
        heading: heading,
        draft: _require(level, entity),
      ),
    CurriculumEntity.module => _ModuleForm(
        heading: heading,
        draft: _require(module, entity),
      ),
    CurriculumEntity.lesson => _LessonForm(
        heading: heading,
        draft: _require(lesson, entity),
      ),
    CurriculumEntity.sign => _SignForm(
        heading: heading,
        draft: _require(sign, entity),
      ),
  };

  return showModalBottomSheet<CurriculumEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      // Lift the sheet above the keyboard so the focused field stays visible.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: child,
    ),
  );
}

/// Unwraps the draft for [entity], failing loudly if the caller passed the
/// wrong one.
T _require<T>(T? draft, CurriculumEntity entity) {
  if (draft == null) {
    throw ArgumentError('A ${entity.label} draft is required, but was null.');
  }
  return draft;
}

/// Chrome shared by all four forms: a title, the fields and a save button
/// wired to [FormState.validate].
abstract class _EditorScaffold extends StatefulWidget {
  const _EditorScaffold({required this.heading});

  final String heading;
}

abstract class _EditorScaffoldState<T extends _EditorScaffold> extends State<T> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Validates and closes the sheet with [_result].
  void submit(CurriculumEditorResult? result) {
    if (result == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              widget.heading,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: buildFields(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: FilledButton(
              onPressed: () => submit(buildResult()),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  /// The form's inputs. Implemented by each subclass.
  Widget buildFields();

  /// Reads the controllers into a draft. Must not validate.
  CurriculumEditorResult? buildResult();
}

/// Labelled text input used by the editor forms.
class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              helperText: helper,
              helperMaxLines: 3,
              isDense: true,
            ),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}

/// Whole-number input with a numeric keyboard, for `sort_order` and
/// `estimated_minutes`.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(helperText: helper, isDense: true),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'Required';
              final parsed = int.tryParse(text);
              if (parsed == null) return 'Enter a whole number';
              if (parsed < 0) return 'Cannot be negative';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

int _readInt(TextEditingController controller, int fallback) =>
    int.tryParse(controller.text.trim()) ?? fallback;

// ==========================================================
// LEVEL
// ==========================================================

class _LevelForm extends _EditorScaffold {
  const _LevelForm({required super.heading, required this.draft});

  final LevelDraft draft;

  @override
  State<_LevelForm> createState() => _LevelFormState();
}

class _LevelFormState extends _EditorScaffoldState<_LevelForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.draft.name);
  late final TextEditingController _description =
      TextEditingController(text: widget.draft.description);
  late final TextEditingController _sortOrder =
      TextEditingController(text: '${widget.draft.sortOrder}');

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorField(
          label: 'Name',
          hint: 'e.g. Advanced',
          controller: _name,
        ),
        _EditorField(
          label: 'Description',
          hint: 'What learners achieve at this level',
          controller: _description,
          maxLines: 3,
        ),
        _NumberField(
          label: 'Sort order',
          controller: _sortOrder,
          helper: 'Lower numbers appear first.',
        ),
      ],
    );
  }

  @override
  CurriculumEditorResult buildResult() {
    return LevelEditorResult(
      LevelDraft(
        name: _name.text,
        description: _description.text,
        sortOrder: _readInt(_sortOrder, widget.draft.sortOrder),
      ),
    );
  }
}

// ==========================================================
// MODULE
// ==========================================================

class _ModuleForm extends _EditorScaffold {
  const _ModuleForm({required super.heading, required this.draft});

  final ModuleDraft draft;

  @override
  State<_ModuleForm> createState() => _ModuleFormState();
}

class _ModuleFormState extends _EditorScaffoldState<_ModuleForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.draft.title);
  late final TextEditingController _description =
      TextEditingController(text: widget.draft.description);
  late final TextEditingController _icon =
      TextEditingController(text: widget.draft.icon);
  late final TextEditingController _sortOrder =
      TextEditingController(text: '${widget.draft.sortOrder}');

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _icon.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorField(
          label: 'Title',
          hint: 'e.g. Emergency Signs',
          controller: _title,
        ),
        _EditorField(
          label: 'Description',
          controller: _description,
          maxLines: 3,
        ),
        _EditorField(
          label: 'Icon name',
          hint: 'Material icon, e.g. warning',
          controller: _icon,
          helper: 'Optional. Rendered as a Material icon on the module card.',
        ),
        _NumberField(label: 'Sort order', controller: _sortOrder),
      ],
    );
  }

  @override
  CurriculumEditorResult buildResult() {
    return ModuleEditorResult(
      ModuleDraft(
        levelId: widget.draft.levelId,
        title: _title.text,
        description: _description.text,
        icon: _icon.text,
        sortOrder: _readInt(_sortOrder, widget.draft.sortOrder),
      ),
    );
  }
}

// ==========================================================
// LESSON
// ==========================================================

class _LessonForm extends _EditorScaffold {
  const _LessonForm({required super.heading, required this.draft});

  final LessonDraft draft;

  @override
  State<_LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends _EditorScaffoldState<_LessonForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.draft.title);
  late final TextEditingController _description =
      TextEditingController(text: widget.draft.description);
  late final TextEditingController _minutes =
      TextEditingController(text: '${widget.draft.estimatedMinutes}');
  late final TextEditingController _sortOrder =
      TextEditingController(text: '${widget.draft.sortOrder}');

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _minutes.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorField(
          label: 'Title',
          hint: 'e.g. Emergency Signs A-Z',
          controller: _title,
        ),
        _EditorField(
          label: 'Description',
          controller: _description,
          maxLines: 3,
        ),
        _NumberField(
          label: 'Estimated minutes',
          controller: _minutes,
          helper: 'Shown to learners before they start.',
        ),
        _NumberField(
          label: 'Sort order',
          controller: _sortOrder,
          helper: 'Sign count is calculated automatically.',
        ),
      ],
    );
  }

  @override
  CurriculumEditorResult buildResult() {
    return LessonEditorResult(
      LessonDraft(
        moduleId: widget.draft.moduleId,
        title: _title.text,
        description: _description.text,
        estimatedMinutes: _readInt(_minutes, widget.draft.estimatedMinutes),
        sortOrder: _readInt(_sortOrder, widget.draft.sortOrder),
      ),
    );
  }
}

// ==========================================================
// SIGN
// ==========================================================

class _SignForm extends _EditorScaffold {
  const _SignForm({required super.heading, required this.draft});

  final SignDraft draft;

  @override
  State<_SignForm> createState() => _SignFormState();
}

class _SignFormState extends _EditorScaffoldState<_SignForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.draft.title);
  late final TextEditingController _description =
      TextEditingController(text: widget.draft.description);
  late final TextEditingController _aiLabel =
      TextEditingController(text: widget.draft.aiLabel);
  late final TextEditingController _sortOrder =
      TextEditingController(text: '${widget.draft.sortOrder}');

  late bool _isActive = widget.draft.isActive;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _aiLabel.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorField(
          label: 'Title',
          hint: 'e.g. Thank you',
          controller: _title,
        ),
        _EditorField(
          label: 'Description',
          controller: _description,
          maxLines: 3,
        ),
        _EditorField(
          label: 'AI label',
          hint: 'e.g. THANK_YOU',
          controller: _aiLabel,
          helper:
              'Must be a label the on-device recogniser can detect, otherwise '
              'this sign cannot be passed in practice.',
        ),
        _NumberField(label: 'Sort order', controller: _sortOrder),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Active',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Inactive signs are hidden from learners but keep their progress.',
            style: TextStyle(fontSize: 12),
          ),
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
        ),
      ],
    );
  }

  @override
  CurriculumEditorResult buildResult() {
    return SignEditorResult(
      SignDraft(
        lessonId: widget.draft.lessonId,
        title: _title.text,
        description: _description.text,
        aiLabel: _aiLabel.text,
        isActive: _isActive,
        sortOrder: _readInt(_sortOrder, widget.draft.sortOrder),
      ),
    );
  }
}
