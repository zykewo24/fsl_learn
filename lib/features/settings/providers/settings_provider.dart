import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/settings_controller.dart';
import '../models/settings_state.dart';

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);
