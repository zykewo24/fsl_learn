enum GestureCategory {
  alphabet,
  number,
}

class Gesture {
  final String id;
  final String displayName;
  final GestureCategory category;

  const Gesture({
    required this.id,
    required this.displayName,
    required this.category,
  });
}