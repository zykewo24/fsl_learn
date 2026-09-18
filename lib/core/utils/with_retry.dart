import 'package:supabase_flutter/supabase_flutter.dart';

/// Retries a Supabase read a few times when PostgREST briefly rejects a valid
/// JWT with the transient "JWT issued at future" error (code PGRST303).
///
/// This is a known PostgREST server-side clock-skew bug
/// (https://github.com/PostgREST/postgrest/issues/5196) — the identical request
/// succeeds on a retry about a second later. The device/app clock is not the
/// cause; it is the validator's short-lived wrong time. Used for reads only so
/// failed writes are never silently duplicated.
Future<T> withTransientJwtRetry<T>(
  Future<T> Function() action, {
  int attempts = 3,
  Duration firstDelay = const Duration(milliseconds: 400),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      return await action();
    } catch (error) {
      final isTransient =
          error is PostgrestException && error.code == 'PGRST303';
      if (!isTransient || attempt == attempts - 1) rethrow;
      await Future<void>.delayed(firstDelay * (attempt + 1));
    }
  }
  throw StateError('Unreachable');
}