import 'dart:math';

import '../../../core/utils/sign_asset.dart';
import '../../../models/lesson_sign_model.dart';
import '../../ai_practice/recognition/sign_label.dart';
import '../models/quiz.dart';

/// Builds a quiz out of the signs in a lesson.
///
/// Kept as plain functions over an injected [Random] so the question order and
/// the distractor choices are deterministic under test. A quiz that shuffles
/// with the global generator is a quiz that cannot be tested.
class QuizBuilder {
  /// How many options an [QuizMode.identifyIt] question offers, including the
  /// correct one.
  static const int optionCount = 4;

  /// Builds up to [count] questions from [signs].
  ///
  /// Returns fewer than [count] if the lesson is smaller, and an empty list if
  /// there are no usable signs. A lesson of one sign cannot make a meaningful
  /// multiple-choice question - every option would be the same picture - so
  /// [QuizMode.identifyIt] yields nothing for it rather than a question whose
  /// distractors are duplicates.
  static List<QuizQuestion> build(
    List<LessonSignModel> signs,
    QuizMode mode, {
    int count = 5,
    Random? random,
  }) {
    if (signs.isEmpty || count <= 0) return const [];

    final rng = random ?? Random();
    final pool = List<LessonSignModel>.from(signs);
    pool.shuffle(rng);

    final take = min(count, pool.length);
    final questions = <QuizQuestion>[];

    for (final sign in pool.take(take)) {
      if (mode == QuizMode.signIt) {
        questions.add(QuizQuestion(sign: sign));
        continue;
      }

      final options = _optionsFor(sign, pool, rng);
      if (options == null) continue;
      questions.add(options);
    }

    return questions;
  }

  /// Picks [optionCount] options for [sign] from [pool], including [sign]
  /// itself, shuffled. Returns null when there are not enough distinct signs to
  /// fill the options.
  static QuizQuestion? _optionsFor(
    LessonSignModel sign,
    List<LessonSignModel> pool,
    Random rng,
  ) {
    final candidates = <LessonSignModel>[
      sign,
      // Distinct by asset rather than by id: two signs can share a picture
      // (a letter and a colour performed with the same hand), and offering the
      // same image twice would make a question unanswerable.
      ...pool.where(
        (s) => s.id != sign.id && _distinguishesFrom(s, sign),
      ),
    ];

    if (candidates.length < optionCount) return null;

    // Take the distractors first and add the target afterwards. Shuffling the
    // combined list and then taking the first N can silently drop the target
    // altogether, which leaves a question whose correctIndex is -1 and no
    // option that can ever be right.
    final distractors = candidates.where((s) => s.id != sign.id).toList()
      ..shuffle(rng);

    final chosen = <LessonSignModel>[
      ...distractors.take(optionCount - 1),
      sign,
    ]..shuffle(rng);

    return QuizQuestion(
      sign: sign,
      options: chosen,
      correctIndex: chosen.indexWhere((s) => s.id == sign.id),
    );
  }

  /// Whether [other] would be visually distinguishable from [sign].
  ///
  /// Compares the bundled image, since that is what the learner actually sees.
  /// Falls back to the canonical handshape for signs with no image. Comparing
  /// the pictures is what stops a question offering the same image twice -
  /// which happens easily here, because a letter and a colour are frequently
  /// performed with the same hand and therefore share a reference pose.
  static bool _distinguishesFrom(LessonSignModel other, LessonSignModel sign) {
    final otherAsset = resolveSignAssetPath(other.aiLabel);
    final signAsset = resolveSignAssetPath(sign.aiLabel);
    if (otherAsset != null && signAsset != null) {
      return otherAsset != signAsset;
    }
    return canonicalSignLabel(other.aiLabel) !=
        canonicalSignLabel(sign.aiLabel);
  }
}
