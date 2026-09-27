/// Re-exports the canonical reference-pose data, which now lives in `lib/` so
/// production code can use it. The synthesised hands are compared against live
/// camera landmarks, so the test fixtures and the app must read the exact same
/// data - keeping a second copy here is how they would drift apart.
library;

export '../../lib/features/ai_practice/recognition/reference/number_poses.dart';
