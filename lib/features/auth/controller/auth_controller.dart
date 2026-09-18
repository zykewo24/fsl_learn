import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>(
  (ref) => AuthController(ref.read(authServiceProvider)),
);

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._authService)
      : super(const AsyncData(null));

  final AuthService _authService;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _authService.signIn(
        email: email,
        password: password,
      );
    });
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _authService.signUp(
        fullName: fullName,
        email: email,
        password: password,
      );
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _authService.signOut();
    });
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _authService.resetPassword(email);
    });
  }

  /// Starts Google OAuth sign-in. The authenticated session returns
  /// asynchronously via the `fsllearn://callback` deep link; until then the
  /// controller shows a loading state so the UI can disable the button.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_authService.signInWithGoogle);
  }

  /// Starts Facebook OAuth sign-in (see [signInWithGoogle]).
  Future<void> signInWithFacebook() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_authService.signInWithFacebook);
  }
}