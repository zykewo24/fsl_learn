import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/sign_asset.dart';
import '../../../models/lesson_model.dart';
import '../../../models/lesson_sign_model.dart';
import '../../../providers/lesson_provider.dart';
import '../controllers/quiz_controller.dart';
import '../models/quiz.dart';
import '../widgets/quiz_camera.dart';

/// A short quiz over a lesson's signs, in either mode.
class QuizScreen extends ConsumerStatefulWidget {
  final LessonModel lesson;

  /// Restricts the quiz to a single sign, e.g. when launched from one sign's
  /// practice card.
  final String? focusSignId;

  const QuizScreen({super.key, required this.lesson, this.focusSignId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final Random _random = Random();

  @override
  Widget build(BuildContext context) {
    final signsAsync = ref.watch(lessonSignsProvider(widget.lesson.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz: ${widget.lesson.title}'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(quizProvider);
              if (state.status != QuizStatus.inProgress) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'Question ${state.index + 1} of ${state.questions.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: signsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorPane(message: 'Could not load signs: $e'),
        data: (signs) {
          final usable = widget.focusSignId == null
              ? signs
              : signs
                  .where((s) => s.id == widget.focusSignId)
                  .toList(growable: false);

          if (usable.isEmpty) {
            return const _ErrorPane(message: 'This lesson has no signs yet.');
          }

          final state = ref.watch(quizProvider);
          return switch (state.status) {
            QuizStatus.notStarted => _ModePicker(
                signs: usable,
                onStart: (mode) => ref
                    .read(quizProvider.notifier)
                    .start(usable, mode, random: _random),
              ),
            QuizStatus.inProgress => _QuestionPane(
                state: state,
                onAnswered: () => ref.read(quizProvider.notifier).next(),
                onSkip: () {
                  ref.read(quizProvider.notifier).skipCurrent();
                  ref.read(quizProvider.notifier).next();
                },
              ),
            QuizStatus.finished => _ResultPane(
                state: state,
                onRetry: () => ref.read(quizProvider.notifier).reset(),
              ),
          };
        },
      ),
    );
  }
}

/// Lets the learner choose how they want to be tested.
class _ModePicker extends StatelessWidget {
  final List<LessonSignModel> signs;
  final void Function(QuizMode) onStart;

  const _ModePicker({required this.signs, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'How would you like to be tested on ${signs.length} '
          'sign${signs.length == 1 ? '' : 's'}?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        for (final mode in QuizMode.values) ...[
          Card(
            child: ListTile(
              leading: Icon(
                mode == QuizMode.signIt
                    ? Icons.videocam_outlined
                    : Icons.image_outlined,
                size: 32,
              ),
              title: Text(mode.title),
              subtitle: Text(
                // Identify-it needs four visibly different signs to build a
                // question, so say so rather than starting a quiz that cannot
                // produce a single question.
                mode == QuizMode.identifyIt && signs.length < 4
                    ? 'Needs at least 4 signs in this lesson'
                    : mode.blurb,
              ),
              enabled: mode != QuizMode.identifyIt || signs.length >= 4,
              onTap: () => onStart(mode),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// One question, in whichever mode is active.
class _QuestionPane extends ConsumerWidget {
  final QuizState state;
  final VoidCallback onAnswered;
  final VoidCallback onSkip;

  const _QuestionPane({
    required this.state,
    required this.onAnswered,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = state.current;
    if (question == null) {
      return const _ErrorPane(message: 'No question to show.');
    }

    // The most recent answer belongs to the current question once it has been
    // given, which is what reveals the result and enables Next.
    final answered =
        state.answers.length > state.index ? state.answers.last : null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  state.mode == QuizMode.signIt
                      ? 'Show me this sign'
                      : 'Which sign is this?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                // Production is prompted by the word, never by the picture.
                // Reception (identify it) still needs the picture, because
                // naming a sign you can see is the whole point of that mode.
                if (state.mode == QuizMode.signIt)
                  _WordPrompt(label: question.promptLabel)
                else
                  _SignImage(sign: question.sign, size: 180),
                const SizedBox(height: 20),
                if (state.mode == QuizMode.signIt)
                  QuizCamera(
                    key: ValueKey('cam-${question.sign.id}'),
                    onRecognised: (label) => ref
                        .read(quizProvider.notifier)
                        .answerWithRecognition(label),
                  )
                else
                  _OptionGrid(
                    question: question,
                    enabled: answered == null,
                    onPick: (i) =>
                        ref.read(quizProvider.notifier).answerWithOption(i),
                  ),
                if (answered != null) ...[
                  const SizedBox(height: 16),
                  _Verdict(answer: answered, question: question),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: answered == null ? onSkip : null,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: answered == null ? null : onAnswered,
                  child: Text(
                    state.isLastQuestion ? 'See results' : 'Next',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The four sign images to choose from.
class _OptionGrid extends StatelessWidget {
  final QuizQuestion question;
  final bool enabled;
  final void Function(int) onPick;

  const _OptionGrid({
    required this.question,
    required this.enabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        for (var i = 0; i < question.options.length; i++)
          InkWell(
            onTap: enabled ? () => onPick(i) : null,
            borderRadius: BorderRadius.circular(12),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _SignImage(sign: question.options[i], size: 120),
              ),
            ),
          ),
      ],
    );
  }
}

/// Right/wrong feedback for the question just answered.
class _Verdict extends StatelessWidget {
  final QuizAnswer answer;
  final QuizQuestion question;

  const _Verdict({required this.answer, required this.question});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              answer.correct ? Icons.check_circle : Icons.cancel,
              color: answer.correct ? AppColors.success : AppColors.danger,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              answer.correct
                  ? 'Correct'
                  : 'The answer was ${question.sign.title}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        answer.correct ? AppColors.success : AppColors.danger,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SignImage(sign: question.sign, size: 140),
      ],
    );
  }
}

/// Final score.
class _ResultPane extends StatelessWidget {
  final QuizState state;
  final VoidCallback onRetry;

  const _ResultPane({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final percent = state.percentCorrect ?? 0;
    final total = state.questions.length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              percent >= 0.8
                  ? Icons.emoji_events
                  : percent >= 0.5
                      ? Icons.thumb_up
                      : Icons.refresh,
              size: 72,
              color: percent >= 0.8 ? AppColors.success : AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '${state.correctCount} of $total',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${(percent * 100).round()}% correct',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < state.answers.length; i++)
                  Chip(
                    avatar: Icon(
                      state.answers[i].correct
                          ? Icons.check
                          : Icons.close,
                      size: 18,
                      color: state.answers[i].correct
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    label: Text(_labelFor(state, i)),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.replay),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  /// The title of the sign a given answer was about.
  String _labelFor(QuizState state, int i) {
    if (i < state.questions.length) return state.questions[i].sign.title;
    return 'Sign ${i + 1}';
  }
}

/// The sign's name, shown instead of its picture in [QuizMode.signIt].
///
/// Sized and weighted to be the focal point of the screen, since it is the
/// only information the learner gets before producing the sign.
class _WordPrompt extends StatelessWidget {
  final String label;

  const _WordPrompt({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No reference picture - recall the handshape',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.75,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A sign's bundled reference image, or a neutral placeholder.
class _SignImage extends StatelessWidget {
  final LessonSignModel sign;
  final double size;

  const _SignImage({required this.sign, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = resolveSignAssetPath(sign.aiLabel);

    Widget child;
    if (asset != null) {
      child = Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else if (sign.imageUrl != null) {
      child = Image.network(
        sign.imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else {
      child = _placeholder();
    }

    return SizedBox(width: size, height: size, child: child);
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.image, size: size * 0.4, color: Colors.grey.shade500),
      );
}

class _ErrorPane extends StatelessWidget {
  final String message;

  const _ErrorPane({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
