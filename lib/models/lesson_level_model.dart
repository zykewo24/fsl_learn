class LessonLevelModel {
  final int id;
  final String name;
  final String description;
  final int sortOrder;

  const LessonLevelModel({
    required this.id,
    required this.name,
    required this.description,
    required this.sortOrder,
  });

  factory LessonLevelModel.fromJson(Map<String, dynamic> json) {
    return LessonLevelModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}