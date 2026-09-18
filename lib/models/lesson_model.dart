class LessonModel {
  final String id;
  final String moduleId;
  final String title;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final int totalSigns;
  final int estimatedMinutes;
  final int sortOrder;

  const LessonModel({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.description,
    this.imageUrl,
    this.videoUrl,
    required this.totalSigns,
    required this.estimatedMinutes,
    required this.sortOrder,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'],
      moduleId: json['module_id'],
      title: json['title'],
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      videoUrl: json['video_url'],
      totalSigns: json['total_signs'] ?? 0,
      estimatedMinutes: json['estimated_minutes'] ?? 0,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}