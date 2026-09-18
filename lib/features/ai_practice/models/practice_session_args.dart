import '../../../models/lesson_model.dart';

/// Arguments for opening an AI practice session. When [signId] is
/// provided, only that single sign is practiced; otherwise the whole
/// lesson is practiced.
class PracticeSessionArgs {
  final LessonModel lesson;
  final String? signId;

  const PracticeSessionArgs({
    required this.lesson,
    this.signId,
  });
}