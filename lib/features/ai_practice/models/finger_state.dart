class FingerState {
  final bool thumbOpen;
  final bool indexOpen;
  final bool middleOpen;
  final bool ringOpen;
  final bool pinkyOpen;

  const FingerState({
    required this.thumbOpen,
    required this.indexOpen,
    required this.middleOpen,
    required this.ringOpen,
    required this.pinkyOpen,
  });

  @override
  String toString() {
    return '''
Thumb : ${thumbOpen ? "Open" : "Closed"}
Index : ${indexOpen ? "Open" : "Closed"}
Middle: ${middleOpen ? "Open" : "Closed"}
Ring  : ${ringOpen ? "Open" : "Closed"}
Pinky : ${pinkyOpen ? "Open" : "Closed"}
''';
  }
}