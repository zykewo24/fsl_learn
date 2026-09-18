import 'package:go_router/go_router.dart';

import '../../features/ai_practice/models/practice_session_args.dart';
import '../../features/ai_practice/presentation/ai_practice_screen.dart';
import '../../features/ai_practice/presentation/media_pipe_test_screen.dart';
import '../../models/lesson_model.dart';
import '../routes.dart';

class PracticeRoutes {
  PracticeRoutes._();

  static final List<RouteBase> routes = [
    GoRoute(
      path: AppRoutes.practiceSession,
      builder: (context, state) {
        final extra = state.extra;

        final lesson = switch (extra) {
          final PracticeSessionArgs args => args.lesson,
          final LessonModel model => model,
          _ => null,
        };

        if (lesson == null) {
          throw StateError(
            'practiceSession requires a LessonModel or '
            'PracticeSessionArgs as extra',
          );
        }

        return AiPracticeScreen(
          lesson: lesson,
          focusSignId: extra is PracticeSessionArgs
              ? extra.signId
              : null,
        );
      },
    ),

    GoRoute(
      path: AppRoutes.cameraTest,
      builder: (context, state) {
        return const MediaPipeTestScreen();
      },
    ),
  ];
}