import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/ai_session_controller.dart';
import '../models/ai_session_state.dart';

final aiSessionProvider =
    NotifierProvider<AiSessionController, AiSessionState?>(
  AiSessionController.new,
);