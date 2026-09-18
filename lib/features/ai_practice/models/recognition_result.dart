/// A single scored recognition candidate (label + confidence). Exposed for
/// debugging so the UI can show the top-N contenders the recognizer
/// considered on each frame.
class RecognizedCandidate {
  final String label;
  final double confidence;

  const RecognizedCandidate(this.label, this.confidence);
}

class RecognitionResult {
  final String? label;
  final double confidence;
  final bool matched;

  /// All scored candidates sorted by confidence descending. Useful for a
  /// live debug readout to see how close non-winners were.
  final List<RecognizedCandidate> candidates;

  const RecognitionResult({
    required this.label,
    required this.confidence,
    required this.matched,
    this.candidates = const [],
  });

  const RecognitionResult.noMatch()
      : label = null,
        confidence = 0.0,
        matched = false,
        candidates = const [];
}
