class NormalizedLandmark {
  final double x;
  final double y;
  final double z;

  const NormalizedLandmark({
    required this.x,
    required this.y,
    required this.z,
  });

  @override
  String toString() {
    return '($x, $y, $z)';
  }
}