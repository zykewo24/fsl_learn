enum LessonCategory {
  alphabet,
  number,
}

class Lesson {
  final String id;
  final String title;
  final LessonCategory category;

  /// Example: assets/fsl/alphabet/a.png
  final String imageAsset;

  final String description;

  const Lesson({
    required this.id,
    required this.title,
    required this.category,
    required this.imageAsset,
    required this.description,
  });
}