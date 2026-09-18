class ACalibrationSample {
  final bool thumbOpen;
  final bool indexOpen;
  final bool middleOpen;
  final bool ringOpen;
  final bool pinkyOpen;

  final double thumbToIndex;
  final double thumbToPinky;
  final double palmWidth;

  final bool matched;
  final double confidence;

  const ACalibrationSample({
    required this.thumbOpen,
    required this.indexOpen,
    required this.middleOpen,
    required this.ringOpen,
    required this.pinkyOpen,
    required this.thumbToIndex,
    required this.thumbToPinky,
    required this.palmWidth,
    required this.matched,
    required this.confidence,
  });
}