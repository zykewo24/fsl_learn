import '../../../features/ai_practice/models/finger_state.dart';

import '../gesture_definition.dart';

const letterA = GestureDefinition(
  id: 'A',
  displayName: 'Letter A',
  type: GestureType.alphabet,
  expectedFingerState: FingerState(
    thumbOpen: false,
    indexOpen: false,
    middleOpen: false,
    ringOpen: false,
    pinkyOpen: false,
  ),
);