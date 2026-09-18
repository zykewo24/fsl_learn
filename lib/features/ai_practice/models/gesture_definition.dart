class GestureDefinition {
  final String label;

  final bool thumbOpen;
  final bool indexOpen;
  final bool middleOpen;
  final bool ringOpen;
  final bool pinkyOpen;

  const GestureDefinition({
    required this.label,
    required this.thumbOpen,
    required this.indexOpen,
    required this.middleOpen,
    required this.ringOpen,
    required this.pinkyOpen,
  });
}