class LessonSignModel {
  final String id;
  final String lessonId;
  final String title;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final String aiLabel;
  final String difficulty;
  final bool isActive;
  final int sortOrder;

  const LessonSignModel({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.description,
    this.imageUrl,
    this.videoUrl,
    required this.aiLabel,
    required this.difficulty,
    required this.isActive,
    required this.sortOrder,
  });

  factory LessonSignModel.fromMap(Map<String, dynamic> map) {
    return LessonSignModel(
      id: map['id'] as String,
      lessonId: map['lesson_id'] as String,
      title: map['title'] as String,
      description: map['description'] ?? '',
      imageUrl: map['image_url'] as String?,
      videoUrl: map['video_url'] as String?,
      aiLabel: map['ai_label'] ?? '',
      difficulty: map['difficulty'] ?? 'easy',
      isActive: map['is_active'] ?? true,
      sortOrder: map['sort_order'] ?? 0,
    );
  }
}