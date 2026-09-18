class LessonModuleModel {
  final String id;
  final int levelId;
  final String title;
  final String description;
  final String? icon;
  final int totalLessons;
  final int sortOrder;

  const LessonModuleModel({
    required this.id,
    required this.levelId,
    required this.title,
    required this.description,
    this.icon,
    required this.totalLessons,
    required this.sortOrder,
  });

  factory LessonModuleModel.fromJson(Map<String, dynamic> json) {
    return LessonModuleModel(
      id: json['id'],
      levelId: json['level_id'],
      title: json['title'],
      description: json['description'] ?? '',
      icon: json['icon'],
      totalLessons: json['total_lessons'] ?? 0,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}