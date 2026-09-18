class Landmark {
  final double x;
  final double y;
  final double z;

  const Landmark({
    required this.x,
    required this.y,
    required this.z,
  });

  factory Landmark.fromMap(Map<dynamic, dynamic> map) {
    return Landmark(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
    );
  }
}