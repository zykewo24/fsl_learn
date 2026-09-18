class HandLandmark {
  final double x;
  final double y;
  final double z;

  const HandLandmark({
    required this.x,
    required this.y,
    required this.z,
  });

  factory HandLandmark.fromMap(
    Map<String, dynamic> map,
  ) {
    return HandLandmark(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'z': z,
    };
  }
}