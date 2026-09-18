import '../../features/ai_practice/models/finger_state.dart';

enum GestureType {
  alphabet,
  number,
}

class GestureDefinition {
  final String id;

  final String displayName;

  final GestureType type;

  final FingerState expectedFingerState;

  const GestureDefinition({
    required this.id,
    required this.displayName,
    required this.type,
    required this.expectedFingerState,
  });
}