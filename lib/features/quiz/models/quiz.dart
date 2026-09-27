import '../../../models/lesson_sign_model.dart';

/// How a quiz question is answered.
enum QuizMode {
  /// The learner is shown a sign and asked to *produce* it. Verified by the
  /// camera, using the same recognisers, hold-to-confirm buffer and corrective
  /// feedback as practice.
  signIt,

  /// The learner is shown a sign and asked to *identify* it, choosing from
  /// several sign images. Tests reception rather than production, and needs
  /// no camera.
  identifyIt,
}

extension QuizModeX on QuizMode {
  String get title => switch (this) {
        QuizMode.signIt => 'Sign it',
        QuizMode.identifyIt => 'Identify it',
      };

  String get blurb => switch (this) {
        QuizMode.signIt => 'Show the sign with your camera',
        QuizMode.identifyIt => 'Pick the sign that matches the picture',
      };
}

/// Lifecycle of one quiz attempt.
enum QuizStatus { notStarted, inProgress, finished }

/// One question: the sign being asked about, plus the distractors for
/// [QuizMode.identifyIt].
class QuizQuestion {
  final LessonSignModel sign;

  /// The signs the learner may pick from. Contains [sign] exactly once, and is
  /// empty for [QuizMode.signIt] where there is nothing to pick from.
  final List<LessonSignModel> options;

  /// Where [sign] sits in [options], so a correct tap can be scored without
  /// comparing ids. Null for [QuizMode.signIt].
  final int? correctIndex;

  const QuizQuestion({
    required this.sign,
    this.options = const [],
    this.correctIndex,
  });

  bool isCorrectOption(int index) => index == correctIndex;
}

/// One answered question.
class QuizAnswer {
  final String signId;

  /// The sign the learner actually produced or picked, when that is known.
  /// Null when a [QuizMode.signIt] question was skipped or timed out.
  final String? givenSignId;

  final bool correct;

  const QuizAnswer({
    required this.signId,
    required this.correct,
    this.givenSignId,
  });
}

/// The whole state of a quiz attempt.
class QuizState {
  final QuizStatus status;
  final QuizMode mode;

  final List<QuizQuestion> questions;

  /// Index of the question being answered.
  final int index;

  final List<QuizAnswer> answers;

  const QuizState({
    this.status = QuizStatus.notStarted,
    this.mode = QuizMode.signIt,
    this.questions = const [],
    this.index = 0,
    this.answers = const [],
  });

  QuizQuestion? get current =>
      index >= 0 && index < questions.length ? questions[index] : null;

  bool get isLastQuestion => index >= questions.length - 1;

  int get correctCount => answers.where((a) => a.correct).length;

  /// 0..1, or null when nothing has been answered yet. Rounded for display.
  double? get percentCorrect {
    if (answers.isEmpty) return null;
    return correctCount / answers.length;
  }

  QuizState copyWith({
    QuizStatus? status,
    QuizMode? mode,
    List<QuizQuestion>? questions,
    int? index,
    List<QuizAnswer>? answers,
  }) {
    return QuizState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      questions: questions ?? this.questions,
      index: index ?? this.index,
      answers: answers ?? this.answers,
    );
  }
}
