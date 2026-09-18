import '../models/lesson.dart';

class AlphabetRepository {
  AlphabetRepository._();

  static const lessons = [
    Lesson(
      id: 'A',
      title: 'Letter A',
      category: LessonCategory.alphabet,
      imageAsset: 'assets/fsl/alphabet/a.png',
      description:
          'Make a closed fist while keeping the thumb positioned according to the reference image.',
    ),
  ];
}