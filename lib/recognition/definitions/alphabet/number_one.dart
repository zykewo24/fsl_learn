import '../../../features/ai_practice/models/finger_state.dart';

import '../gesture_definition.dart';

const numberOne = GestureDefinition(
  id: '1',
  displayName: 'Number 1',
  type: GestureType.number,
  expectedFingerState: FingerState(
    thumbOpen: false,
    indexOpen: true,
    middleOpen: false,
    ringOpen: false,
    pinkyOpen: false,
  ),
);