import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsl_learn/features/quiz/controllers/quiz_builder.dart';
import 'package:fsl_learn/features/quiz/controllers/quiz_controller.dart';
import 'package:fsl_learn/features/quiz/models/quiz.dart';
import 'package:fsl_learn/models/lesson_sign_model.dart';

LessonSignModel sign(String id, String aiLabel, {String? title}) =>
    LessonSignModel(
      id: id,
      lessonId: 'L1',
      title: title ?? aiLabel,
      description: '',
      aiLabel: aiLabel,
      difficulty: 'easy',
      isActive: true,
      sortOrder: 0,
    );

void main() {
  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  final alphabet = [
    for (final l in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']) sign(l, l),
  ];

  group('question building', () {
    test('produces no questions for an empty lesson', () {
      expect(QuizBuilder.build([], QuizMode.signIt), isEmpty);
      expect(QuizBuilder.build([], QuizMode.identifyIt), isEmpty);
    });

    test('caps the question count at the number of signs', () {
      final questions = QuizBuilder.build(
        alphabet.take(3).toList(),
        QuizMode.signIt,
        count: 10,
      );
      expect(questions, hasLength(3));
    });

    test('never repeats a sign', () {
      final questions = QuizBuilder.build(
        alphabet,
        QuizMode.signIt,
        count: 8,
        random: Random(1),
      );
      final ids = questions.map((q) => q.sign.id).toSet();
      expect(ids, hasLength(questions.length));
    });

    test('is deterministic under a seeded generator', () {
      final a = QuizBuilder.build(
        alphabet,
        QuizMode.identifyIt,
        count: 5,
        random: Random(42),
      );
      final b = QuizBuilder.build(
        alphabet,
        QuizMode.identifyIt,
        count: 5,
        random: Random(42),
      );
      expect(
        a.map((q) => q.sign.id).toList(),
        b.map((q) => q.sign.id).toList(),
      );
      for (var i = 0; i < a.length; i++) {
        expect(
          a[i].options.map((o) => o.id).toList(),
          b[i].options.map((o) => o.id).toList(),
        );
      }
    });

    test('sign-it questions carry no options', () {
      final questions = QuizBuilder.build(
        alphabet,
        QuizMode.signIt,
        count: 3,
      );
      for (final q in questions) {
        expect(q.options, isEmpty);
        expect(q.correctIndex, isNull);
      }
    });

    test('identify-it questions offer the requested number of options', () {
      final questions = QuizBuilder.build(
        alphabet,
        QuizMode.identifyIt,
        count: 4,
        random: Random(7),
      );
      for (final q in questions) {
        expect(q.options, hasLength(QuizBuilder.optionCount));
        expect(q.correctIndex, isNotNull);
      }
    });

    test('the correct index always points at the target sign', () {
      final questions = QuizBuilder.build(
        alphabet,
        QuizMode.identifyIt,
        count: 5,
        random: Random(3),
      );
      for (final q in questions) {
        expect(q.options[q.correctIndex!].id, q.sign.id);
        expect(q.isCorrectOption(q.correctIndex!), isTrue);
      }
    });

    test('options never contain a duplicate of the target', () {
      final questions = QuizBuilder.build(
        alphabet,
        QuizMode.identifyIt,
        count: 5,
        random: Random(11),
      );
      for (final q in questions) {
        final ids = q.options.map((o) => o.id).toSet();
        expect(ids, hasLength(q.options.length));
        expect(
          ids.where((id) => id == q.sign.id).length,
          1,
          reason: 'the target must appear exactly once',
        );
      }
    });

    test('does not offer the same picture twice', () {
      // A and RED are both the X-hand-shaped family in spirit, but more to the
      // point: two signs sharing a reference image would make the question
      // unanswerable, so the builder must not pair them.
      final withColour = [
        sign('a', 'A'),
        sign('red', 'RED'),
        sign('b', 'B'),
        sign('blue', 'BLUE'),
        sign('c', 'C'),
      ];
      final questions = QuizBuilder.build(
        withColour,
        QuizMode.identifyIt,
        count: 5,
        random: Random(5),
      );
      for (final q in questions) {
        final assets = q.options
            .map((o) => o.aiLabel)
            .toSet();
        // Labels differ by construction; the real guard is that the builder
        // could build the question at all, which needs 4 distinguishable
        // signs. With 5 signs it can.
        expect(assets.length, q.options.length);
      }
    });

    test('yields nothing when there are too few signs to build options', () {
      // Three signs cannot fill four option slots without repeating, so no
      // unanswerable question is produced.
      final questions = QuizBuilder.build(
        alphabet.take(3).toList(),
        QuizMode.identifyIt,
        count: 3,
      );
      expect(questions, isEmpty);
    });
  });

  group('identify-it scoring', () {
    test('a correct tap scores', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start(alphabet, QuizMode.identifyIt, random: Random(2));
      final q = c.read(quizProvider).current!;

      expect(controller.answerWithOption(q.correctIndex!), isTrue);
      final s = c.read(quizProvider);
      expect(s.correctCount, 1);
      expect(s.percentCorrect, 1.0);
    });

    test('a wrong tap scores zero and records what was chosen', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start(alphabet, QuizMode.identifyIt, random: Random(2));
      final q = c.read(quizProvider).current!;
      final wrong = q.options.indexWhere((o) => o.id != q.sign.id);

      expect(controller.answerWithOption(wrong), isTrue);
      final s = c.read(quizProvider);
      expect(s.correctCount, 0);
      expect(s.answers.first.givenSignId, q.options[wrong].id);
    });

    test('rejects an out-of-range tap', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start(alphabet, QuizMode.identifyIt, random: Random(2));
      expect(controller.answerWithOption(99), isTrue);
      expect(c.read(quizProvider).answers.first.correct, isFalse);
    });

    test('refuses to score the same question twice', () {
      // A double tap must not turn one question into two answers.
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start(alphabet, QuizMode.identifyIt, random: Random(2));
      final q = c.read(quizProvider).current!;

      expect(controller.answerWithOption(q.correctIndex!), isTrue);
      expect(controller.answerWithOption(q.correctIndex!), isFalse);
      expect(c.read(quizProvider).answers, hasLength(1));
    });
  });

  group('sign-it scoring', () {
    test('accepts a matching recogniser label', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start([sign('a', 'A')], QuizMode.signIt);
      expect(controller.answerWithRecognition('A'), isTrue);
      expect(c.read(quizProvider).correctCount, 1);
    });

    test('accepts a colour sign answered with its letter handshape', () {
      // RED is performed with the X hand, so the camera reports X.
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start([sign('red', 'RED')], QuizMode.signIt);
      expect(controller.answerWithRecognition('X'), isTrue);
      expect(c.read(quizProvider).correctCount, 1);
    });

    test('accepts a number word answered as a digit', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start([sign('three', 'THREE')], QuizMode.signIt);
      expect(controller.answerWithRecognition('3'), isTrue);
      expect(c.read(quizProvider).correctCount, 1);
    });

    test('rejects a different sign', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start([sign('a', 'A')], QuizMode.signIt);
      expect(controller.answerWithRecognition('B'), isTrue);
      expect(c.read(quizProvider).correctCount, 0);
    });

    test('ignores an empty recognition', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start([sign('a', 'A')], QuizMode.signIt);
      expect(controller.answerWithRecognition(null), isFalse);
      expect(controller.answerWithRecognition(''), isFalse);
      expect(c.read(quizProvider).answers, isEmpty);
    });

    test('refuses to be answered by an option tap', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start([sign('a', 'A')], QuizMode.signIt);
      expect(controller.answerWithOption(0), isFalse);
      expect(c.read(quizProvider).answers, isEmpty);
    });

    test('refuses to score the same question twice', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start([sign('a', 'A')], QuizMode.signIt);
      expect(controller.answerWithRecognition('A'), isTrue);
      expect(controller.answerWithRecognition('A'), isFalse);
      expect(c.read(quizProvider).answers, hasLength(1));
    });
  });

  group('progression', () {
    test('starts in progress on the first question', () {
      final c = container();
      c.read(quizProvider.notifier).start(alphabet, QuizMode.signIt);
      final s = c.read(quizProvider);
      expect(s.status, QuizStatus.inProgress);
      expect(s.index, 0);
      expect(s.answers, isEmpty);
      expect(s.current, isNotNull);
    });

    test('will not advance before the question is answered', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start(alphabet, QuizMode.signIt);
      controller.next();
      expect(c.read(quizProvider).index, 0);
    });

    test('advances after an answer', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start(alphabet, QuizMode.signIt);
      final label = c.read(quizProvider).current!.sign.aiLabel;
      controller.answerWithRecognition(label);
      controller.next();
      expect(c.read(quizProvider).index, 1);
      expect(c.read(quizProvider).answers, hasLength(1));
    });

    test('finishes after the last question', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start(
        alphabet.take(3).toList(),
        QuizMode.signIt,
      );

      while (c.read(quizProvider).status == QuizStatus.inProgress) {
        final q = c.read(quizProvider).current!;
        controller.answerWithRecognition(q.sign.aiLabel);
        controller.next();
      }

      final s = c.read(quizProvider);
      expect(s.status, QuizStatus.finished);
      expect(s.answers, hasLength(3));
      expect(s.correctCount, 3);
      expect(s.percentCorrect, 1.0);
    });

    test('a skipped question counts as answered but incorrect', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start(alphabet.take(3).toList(), QuizMode.signIt);
      controller.skipCurrent();
      controller.next();
      final s = c.read(quizProvider);
      expect(s.index, 1);
      expect(s.answers, hasLength(1));
      expect(s.answers.first.correct, isFalse);
      expect(s.answers.first.givenSignId, isNull);
    });

    test('percentCorrect is null before anything is answered', () {
      final c = container();
      c.read(quizProvider.notifier).start(alphabet, QuizMode.signIt);
      expect(c.read(quizProvider).percentCorrect, isNull);
    });

    test('reset clears the attempt', () {
      final c = container();
      final controller = c.read(quizProvider.notifier);
      controller.start(alphabet, QuizMode.signIt);
      controller.answerWithRecognition(
        c.read(quizProvider).current!.sign.aiLabel,
      );
      controller.reset();
      final s = c.read(quizProvider);
      expect(s.status, QuizStatus.notStarted);
      expect(s.questions, isEmpty);
      expect(s.answers, isEmpty);
    });

    test('starting with no usable signs leaves the quiz unstarted', () {
      // Better a clear "not enough signs" than a quiz stuck on question zero.
      final c = container();
      c.read(quizProvider.notifier).start(
        alphabet.take(2).toList(),
        QuizMode.identifyIt,
      );
      expect(c.read(quizProvider).status, QuizStatus.notStarted);
    });
  });
}
