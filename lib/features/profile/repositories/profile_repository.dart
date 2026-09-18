import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';

class ProfileRepository {
  ProfileRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<ProfileModel> getProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in.');
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        return ProfileModel.fromMap(
          Map<String, dynamic>.from(response),
        );
      }
    } on PostgrestException catch (error) {
      throw Exception(
        'Failed to load profile: ${error.message}',
      );
    }

    // No profiles row exists yet.
    // Fall back to Supabase Auth information so the
    // profile screen can still work.
    final metadata = user.userMetadata ?? <String, dynamic>{};

    final fullName =
        (metadata['full_name'] as String?)?.trim().isNotEmpty == true
            ? (metadata['full_name'] as String).trim()
            : ((metadata['name'] as String?)?.trim().isNotEmpty == true
                ? (metadata['name'] as String).trim()
                : 'User');

    final email = user.email ?? '';

    DateTime createdAt;

    try {
      createdAt = DateTime.parse(user.createdAt);
    } catch (_) {
      createdAt = DateTime.now();
    }

    return ProfileModel(
      id: user.id,
      fullName: fullName,
      email: email,
      avatarUrl: null,
      createdAt: createdAt,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}