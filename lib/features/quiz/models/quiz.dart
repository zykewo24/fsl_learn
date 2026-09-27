import '../../../models/lesson_sign_model.dart';

/// A sign's name as a learner should read it, e.g. `Red` or `Excuse Me`.
///
/// Lives here rather than on [QuizQuestion] because both quiz modes now show
/// words: sign-it prompts with the word to be produced, and identify-it offers
/// words as the options. If the two modes each derived their own label they
/// could disagree about what a sign is called, and the quiz would mark a
/// correct answer wrong.
String readableSignLabel(LessonSignModel sign) {
  final title = sign.title.trim();
  if (title.isNotEmpty) return title;

  // Fall back to the recogniser's own label, which is shouty and underscored
  // ("EXCUSE_ME"), and make it read as a word.
  final raw = sign.aiLabel.trim();
  final words = raw
      .toLowerCase()
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  // A label made only of separators would render a blank card, leaving the
  // learner asked to produce a sign with nothing to go on.
  if (words.isNotEmpty) return words;
  return raw.isNotEmpty ? raw : 'This sign';
}

/// How a quiz question is answered.
enum QuizMode {
  /// The learner is shown the sign's *name* and asked to produce it. Verified by
  /// the camera, using the same recognisers, hold-to-confirm buffer and
  /// corrective feedback as practice.
  signIt,

  /// The learner is shown the sign's *picture* and asked to name it, choosing
  /// from several words. Tests reception rather than production, and needs no
  /// camera.
  identifyIt,
}

extension QuizModeX on QuizMode {
  String get title => switch (this) {
        QuizMode.signIt => 'Sign it',
        QuizMode.identifyIt => 'Identify it',
      };

  String get blurb => switch (this) {
        // Wording matters here: this used to promise a picture, and the picture
        // is exactly what was removed.
        QuizMode.signIt => "You'll see the word, not the sign. Produce it.",
        // Was "pick the sign that matches the picture", which described the old
        // image-for-image grid. The options are words now.
        QuizMode.identifyIt => 'See the sign, name what it means',
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

  /// The word shown to the learner in [QuizMode.signIt], e.g. `Red`.
  ///
  /// Deliberately text only. Showing the reference image would turn the question
  /// into an imitation exercise: a learner can copy the picture without having
  /// recalled anything, so the quiz measures their ability to follow a
  /// reference rather than their knowledge of the sign. Naming the sign and
  /// asking for it back is what actually tests production.
  ///
  /// The image is still shown *after* they answer, in the verdict, where seeing
  /// it teaches rather than gives away.
  String get promptLabel => readableSignLabel(sign);
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
