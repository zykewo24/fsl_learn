import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/lesson_sign_model.dart';
import '../../ai_practice/recognition/sign_label.dart';
import '../models/quiz.dart';
import 'quiz_builder.dart';

/// Holds one quiz attempt.
///
/// A plain [Notifier] with no Flutter or camera dependency, so the whole
/// scoring path is unit-testable. The screen observes it and pushes user
/// gestures in; it never mutates the state itself.
class QuizController extends Notifier<QuizState> {
  /// Number of questions a quiz asks for by default.
  static const int defaultQuestionCount = 5;

  @override
  QuizState build() => const QuizState();

  /// Starts a fresh quiz over [signs].
  ///
  /// [count] is capped at the number of signs available, so asking for ten
  /// questions from a four-sign lesson yields four rather than failing.
  void start(
    List<LessonSignModel> signs,
    QuizMode mode, {
    int count = defaultQuestionCount,
    Random? random,
  }) {
    final questions = QuizBuilder.build(
      signs,
      mode,
      count: count,
      random: random,
    );

    if (questions.isEmpty) {
      state = const QuizState();
      return;
    }

    state = QuizState(
      status: QuizStatus.inProgress,
      mode: mode,
      questions: questions,
      index: 0,
    );
  }

  /// Records an answer to the current [QuizMode.identifyIt] question.
  ///
  /// Returns false if there is no current question, the question is not
  /// multiple choice, or it has already been answered - the last of which
  /// stops a double tap from scoring the same question twice.
  bool answerWithOption(int optionIndex) {
    final question = state.current;
    if (question == null ||
        question.correctIndex == null ||
        _alreadyAnswered) {
      return false;
    }

    final given =
        optionIndex >= 0 && optionIndex < question.options.length
            ? question.options[optionIndex]
            : null;

    state = state.copyWith(
      answers: [
        ...state.answers,
        QuizAnswer(
          signId: question.sign.id,
          givenSignId: given?.id,
          correct: given != null && given.id == question.sign.id,
        ),
      ],
    );
    return true;
  }

  /// Records what the camera recognised for the current [QuizMode.signIt]
  /// question.
  ///
  /// [recognisedLabel] is a recogniser label such as `A` or `EXCUSE_ME`; it is
  /// compared against the target's canonical label so a colour sign is matched
  /// by the letter hand it is performed with.
  bool answerWithRecognition(String? recognisedLabel) {
    final question = state.current;
    if (question == null || state.mode != QuizMode.signIt) return false;
    if (_alreadyAnswered) return false;
    // A blank label means the recogniser saw nothing recognisable, which is not
    // the same as the learner producing a wrong sign. Scoring it as an answer
    // would fail a question they never actually attempted.
    if (recognisedLabel == null || recognisedLabel.trim().isEmpty) return false;

    final expected = canonicalSignLabel(question.sign.aiLabel);
    final given = canonicalSignLabel(recognisedLabel);

    state = state.copyWith(
      answers: [
        ...state.answers,
        QuizAnswer(
          signId: question.sign.id,
          givenSignId: recognisedLabel,
          correct: expected == given,
        ),
      ],
    );
    return true;
  }

  /// Records a [QuizMode.signIt] question the learner skipped or ran out of
  /// time on. Always allowed once per question.
  void skipCurrent() {
    final question = state.current;
    if (question == null || _alreadyAnswered) return;

    state = state.copyWith(
      answers: [
        ...state.answers,
        QuizAnswer(signId: question.sign.id, correct: false),
      ],
    );
  }

  bool get _alreadyAnswered => state.answers.length > state.index;

  /// Advances to the next question, finishing the quiz after the last.
  void next() {
    if (state.status != QuizStatus.inProgress) return;
    if (!_alreadyAnswered) return;

    if (state.isLastQuestion) {
      state = state.copyWith(status: QuizStatus.finished);
      return;
    }
    state = state.copyWith(index: state.index + 1);
  }

  /// Clears the attempt back to its initial state.
  void reset() => state = const QuizState();
}

/// The quiz attempt currently being taken. A single global attempt is
/// deliberate: a quiz is a transient, single-focus activity, and keeping it
/// global avoids threading quiz state through every navigation path.
final quizProvider =
    NotifierProvider<QuizController, QuizState>(QuizController.new);
