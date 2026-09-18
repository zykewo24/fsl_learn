import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';

class ProfileController {
  ProfileController()
      : _repository = ProfileRepository(
          Supabase.instance.client,
        );

  final ProfileRepository _repository;

  Future<ProfileModel> loadProfile() {
    return _repository.getProfile();
  }

  Future<void> logout() {
    return _repository.signOut();
  }
}