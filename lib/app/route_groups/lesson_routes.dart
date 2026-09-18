import 'package:go_router/go_router.dart';

import '../../features/lessons/presentation/lesson_details_screen.dart';
import '../../models/lesson_model.dart';
import '../routes.dart';

class LessonRoutes {
  LessonRoutes._();

  static final List<RouteBase> routes = [
    GoRoute(
      path: AppRoutes.lessonDetails,
      builder: (context, state) {
        final lesson = state.extra as LessonModel;

        return LessonDetailsScreen(
          lesson: lesson,
        );
      },
    ),
  ];
}