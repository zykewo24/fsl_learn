import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/controller/auth_controller.dart';
import '../models/profile_model.dart';

final profileProvider = FutureProvider<ProfileModel?>((ref) async {
  final authService = ref.read(authServiceProvider);
  return authService.getProfile();
});