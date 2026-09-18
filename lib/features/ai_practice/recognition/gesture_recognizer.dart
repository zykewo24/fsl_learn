import '../models/detection_result.dart';
import '../models/gesture_debug_data.dart';
import '../models/recognition_result.dart';
import 'hand_geometry.dart';

class _Candidate {
  final String label;
  final double confidence;

  const _Candidate(this.label, this.confidence);
}

/// Rule-based recognizer for the FSL (Filipino Sign Language) manual
/// alphabet A-Z plus numbers 0-9 based on MediaPipe hand landmarks.
///
/// Every frame is converted into a [HandGeometry] (palm-size-normalized
/// features). Each sign is then scored independently and the highest
/// scoring candidate above [minConfidence] wins. Because some numbers
/// (0/2/3/4) share identical handshapes with letters (O/S, U/V, W, B),
/// letters are preferred on near-ties and the equivalent shapes are
/// exposed via [familyOf] so lessons can match them by context.
class GestureRecognizer {
  GestureDebugData? lastDebugData;

  /// Minimum confidence for a candidate to be reported as a match. Also
  /// the threshold the practice flow uses to count a sign as completed.
  static const double minConfidence = 0.5;

  /// Margin under which a near-identical letter handshape wins over a
  /// number candidate.
  static const double _letterTieMargin = 0.10;

  /// Handshape families shared between numbers and letters. Used to keep
  /// lesson completion working when the recognizer emits the letter label
  /// for a number that shares the same static handshape.
  static const Map<String, Set<String>> sharedHandshapeFamilies = {
    '0': {'0', 'O', 'S'},
    '1': {'1', 'D'},
    '2': {'2', 'U', 'V'},
    '3': {'3', 'W'},
    '4': {'4', 'B'},
    '9': {'9', 'F'},
  };

  /// Returns the set of labels that are statically identical to [label].
  static Set<String> familyOf(String label) {
    final normalized = label.trim().toUpperCase();
    for (final family in sharedHandshapeFamilies.values) {
      if (family.contains(normalized)) return family;
    }
    return {normalized};
  }

  static bool _isLetter(String label) =>
      label.length == 1 &&
      label.codeUnitAt(0) >= 65 &&
      label.codeUnitAt(0) <= 90;

  static bool _isNumber(String label) =>
      label.length == 1 &&
      label.codeUnitAt(0) >= 48 &&
      label.codeUnitAt(0) <= 57;

  /// When the best candidate is a number that could just as easily be a
  /// letter (identical handshape), prefer the letter so fingerspelling
  /// stays consistent. The practice screen resolves the ambiguity through
  /// [familyOf].
  _Candidate _preferLetterOnTie(
    _Candidate best,
    List<_Candidate> candidates,
  ) {
    if (!_isNumber(best.label)) {
      return best;
    }

    final numberFamily = familyOf(best.label);

    _Candidate? letter;
    for (final candidate in candidates) {
      if (!_isLetter(candidate.label)) continue;
      // Only letters that share the number's handshape family count as a
      // tie; otherwise the number keeps its higher confidence.
      if (!numberFamily.contains(candidate.label)) continue;
      if (letter == null ||
          candidate.confidence > letter.confidence) {
        letter = candidate;
      }
    }

    if (letter != null &&
        letter.confidence >= best.confidence - _letterTieMargin) {
      return letter;
    }

    return best;
  }

  RecognitionResult recognize(
    DetectionResult detection,
  ) {
    lastDebugData = null;

    if (!_hasValidHand(detection)) {
      return const RecognitionResult.noMatch();
    }

    final g = HandGeometry.fromLandmarks(detection.landmarks);

    final candidates = <_Candidate>[];

    _scoreA(g, candidates);
    _scoreB(g, candidates);
    _scoreC(g, candidates);
    _scoreD(g, candidates);
    _scoreE(g, candidates);
    _scoreF(g, candidates);
    _scoreG(g, candidates);
    _scoreH(g, candidates);
    _scoreI(g, candidates);
    _scoreJ(g, candidates);
    _scoreK(g, candidates);
    _scoreL(g, candidates);
    _scoreM(g, candidates);
    _scoreN(g, candidates);
    _scoreO(g, candidates);
    _scoreP(g, candidates);
    _scoreQ(g, candidates);
    _scoreR(g, candidates);
    _scoreS(g, candidates);
    _scoreT(g, candidates);
    _scoreU(g, candidates);
    _scoreV(g, candidates);
    _scoreW(g, candidates);
    _scoreX(g, candidates);
    _scoreY(g, candidates);
    _scoreZ(g, candidates);
    _score0(g, candidates);
    _score1(g, candidates);
    _score2(g, candidates);
    _score3(g, candidates);
    _score4(g, candidates);
    _score5(g, candidates);
    _score6(g, candidates);
    _score7(g, candidates);
    _score8(g, candidates);
    _score9(g, candidates);

    if (candidates.isEmpty) {
      return const RecognitionResult.noMatch();
    }

    var best = candidates.first;
    for (var i = 1; i < candidates.length; i++) {
      final candidate = candidates[i];
      if (candidate.confidence > best.confidence) {
        best = candidate;
      }
    }

    if (best.confidence < minConfidence) {
      return const RecognitionResult.noMatch();
    }

    best = _preferLetterOnTie(best, candidates);

    final ranked = [...candidates]..sort(
        (a, b) => b.confidence.compareTo(a.confidence),
      );

    return RecognitionResult(
      label: best.label,
      confidence: best.confidence,
      matched: true,
      candidates: [
        for (final c in ranked)
          RecognizedCandidate(c.label, c.confidence),
      ],
    );
  }

  bool _hasValidHand(
    DetectionResult detection,
  ) {
    return detection.handCount == 1 &&
        detection.landmarks.length == 21;
  }

  void _add(
    List<_Candidate> out,
    String label,
    double confidence,
  ) {
    if (confidence <= 0) return;
    out.add(_Candidate(label, confidence.clamp(0.0, 1.0)));
  }

  double _centerScore(
    double value, {
    required double min,
    required double max,
  }) {
    if (value <= min || value >= max) {
      return 0.0;
    }

    final center = (min + max) / 2;
    final halfRange = (max - min) / 2;
    final distance = (value - center).abs();

    return (1.0 - (distance / halfRange)).clamp(0.0, 1.0);
  }

  double _lowScore(
    double value, {
    required double max,
  }) {
    if (value <= 0) return 1.0;
    if (value >= max) return 0.0;
    return 1.0 - (value / max);
  }

  double _closedFourScore(HandGeometry g) {
    var score = 0.0;
    if (!g.indexExtended) score += 0.2;
    if (!g.middleExtended) score += 0.2;
    if (!g.ringExtended) score += 0.2;
    if (!g.pinkyExtended) score += 0.2;
    if (!g.allFourExtended) score += 0.2;
    return score.clamp(0.0, 1.0);
  }

  double _boolScore(bool value) => value ? 1.0 : 0.0;

  // ================================================================
  // A
  // ================================================================

  void _scoreA(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    final thumbOpen = g.thumbExtended;
    final indexOpen = g.indexExtended;
    final middleOpen = g.middleExtended;
    final ringOpen = g.ringExtended;
    final pinkyOpen = g.pinkyExtended;

    final thumbToIndex = g.thumbToIndexMcp;
    final thumbToPinky = g.thumbToPinkyMcp;

    final matchesA =
        thumbOpen &&
        !indexOpen &&
        !middleOpen &&
        !ringOpen &&
        !pinkyOpen &&
        thumbToIndex < 1.0 &&
        thumbToPinky < 1.5;

    lastDebugData = GestureDebugData(
      thumbOpen: thumbOpen,
      indexOpen: indexOpen,
      middleOpen: middleOpen,
      ringOpen: ringOpen,
      pinkyOpen: pinkyOpen,
      thumbToIndex: thumbToIndex,
      thumbToPinky: thumbToPinky,
      palmWidth: g.rawPalmWidth,
      matchesA: matchesA,
      confidence: _calculateAConfidence(
        thumbOpen: thumbOpen,
        indexOpen: indexOpen,
        middleOpen: middleOpen,
        ringOpen: ringOpen,
        pinkyOpen: pinkyOpen,
      ),
    );

    if (!matchesA) {
      return;
    }

    _add(out, 'A', _calculateAConfidence(
      thumbOpen: thumbOpen,
      indexOpen: indexOpen,
      middleOpen: middleOpen,
      ringOpen: ringOpen,
      pinkyOpen: pinkyOpen,
    ));
  }

  double _calculateAConfidence({
    required bool thumbOpen,
    required bool indexOpen,
    required bool middleOpen,
    required bool ringOpen,
    required bool pinkyOpen,
  }) {
    var score = 0.0;

    if (thumbOpen) score += 0.2;
    if (!indexOpen) score += 0.2;
    if (!middleOpen) score += 0.2;
    if (!ringOpen) score += 0.2;
    if (!pinkyOpen) score += 0.2;

    return score.clamp(0.0, 1.0);
  }

  // ================================================================
  // B
  // ================================================================

  void _scoreB(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    final fourFingersOpen =
        g.indexExtended &&
        g.middleExtended &&
        g.ringExtended &&
        g.pinkyExtended;

    final thumbFolded = !g.thumbExtended;

    if (!fourFingersOpen || !thumbFolded) {
      return;
    }

    final fingersCloseTogether =
        g.indexMiddleGap < 0.55 &&
        g.middleRingGap < 0.55 &&
        g.ringPinkyGap < 0.65;

    if (!fingersCloseTogether) {
      return;
    }

    final thumbToPalm = g.thumbToMidPalm;
    final thumbToPinky = g.thumbToPinkyMcp;

    final thumbAcrossPalm =
        thumbToPalm < 1.25 && thumbToPinky < 1.55;

    if (!thumbAcrossPalm) {
      return;
    }

    _add(out, 'B', 1.0);
  }

  // ================================================================
  // C
  // ================================================================

  void _scoreC(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    final averageFingerDistance = g.averageFingerTipDist;

    final thumbIndexGap = g.thumbToIndexTip;
    final thumbMiddleGap = g.thumbToMiddleTip;

    final hasOpening =
        thumbIndexGap > 0.25 && thumbIndexGap < 2.25;

    final hasThumbSeparation =
        thumbMiddleGap > 0.30 && thumbMiddleGap < 2.50;

    final intermediateHandSize =
        averageFingerDistance > 0.45 &&
        averageFingerDistance < 2.40;

    final notClosedFist = averageFingerDistance > 0.65;

    final notFullyOpen = averageFingerDistance < 1.90;

    final matchesC =
        hasOpening &&
        hasThumbSeparation &&
        intermediateHandSize &&
        notClosedFist &&
        notFullyOpen;

    if (!matchesC) {
      return;
    }

    _add(out, 'C', _calculateCConfidence(
      averageFingerDistance,
      thumbIndexGap,
      thumbMiddleGap,
    ));
  }

  double _calculateCConfidence(
    double fingerDistance,
    double thumbIndexGap,
    double thumbMiddleGap,
  ) {
    final fingerScore = _centerScore(
      fingerDistance,
      min: 0.45,
      max: 2.40,
    );

    final indexGapScore = _centerScore(
      thumbIndexGap,
      min: 0.25,
      max: 2.25,
    );

    final middleGapScore = _centerScore(
      thumbMiddleGap,
      min: 0.30,
      max: 2.50,
    );

    return (
          fingerScore * 0.40 +
          indexGapScore * 0.35 +
          middleGapScore * 0.25
        )
        .clamp(0.0, 1.0);
  }

  // ================================================================
  // D
  // ================================================================

  void _scoreD(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (g.middleExtended || g.ringExtended || g.pinkyExtended) {
      return;
    }

    var confidence = 0.0;

    confidence += 0.25 * _boolScore(g.indexExtended);
    confidence += 0.15 * _boolScore(!g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.15 * _boolScore(g.thumbExtended);
    confidence += 0.10 * _boolScore(g.indexUp && !g.thumbSideways);
    confidence += 0.05 * _lowScore(g.thumbToIndexPip, max: 1.6);

    _add(out, 'D', confidence);
  }

  // ================================================================
  // E
  // ================================================================

  void _scoreE(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    final fingersDeepTucked =
        g.indexTipDist < 0.85 &&
        g.middleTipDist < 0.85 &&
        g.ringTipDist < 0.85 &&
        g.pinkyTipDist < 0.85;

    confidence += 0.4 * _closedFourScore(g);
    confidence += 0.3 * _boolScore(!g.thumbExtended);
    confidence += 0.3 * _boolScore(fingersDeepTucked);

    _add(out, 'E', confidence);
  }

  // ================================================================
  // F
  // ================================================================

  void _scoreF(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    // F is a thumb/index "OK-like" pinch with the three other fingers
    // extended. The index curls down to meet the thumb, so it is NOT
    // extended far from the wrist.
    final pinch = g.thumbToIndexTip < 0.70;
    if (!pinch) {
      return;
    }

    var confidence = 0.0;

    confidence += 0.25 * _boolScore(g.thumbToIndexTip < 0.40);
    confidence += 0.20 * _boolScore(!g.indexExtended);
    confidence += 0.20 * _boolScore(g.middleExtended);
    confidence += 0.20 * _boolScore(g.ringExtended);
    confidence += 0.15 * _boolScore(g.pinkyExtended);

    _add(out, 'F', confidence);
  }

  // ================================================================
  // G
  // ================================================================

  void _scoreG(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (!g.indexForward) {
      return;
    }

    var confidence = 0.0;

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.15 * _boolScore(!g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.15 * _boolScore(g.indexForward);
    confidence += 0.10 * _boolScore(g.thumbExtended);
    confidence += 0.10 * _lowScore(g.thumbToIndexPip, max: 1.1);

    _add(out, 'G', confidence);
  }

  // ================================================================
  // H
  // ================================================================

  void _scoreH(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.20 * _boolScore(g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.15 * _lowScore(g.indexMiddleGap, max: 0.4);
    confidence += 0.15 * _boolScore(g.indexForward);

    _add(out, 'H', confidence);
  }

  // ================================================================
  // I / J
  // ================================================================

  void _scoreI(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    confidence += 0.25 * _boolScore(g.pinkyExtended);
    confidence += 0.15 * _boolScore(!g.indexExtended);
    confidence += 0.15 * _boolScore(!g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.30 * _boolScore(!g.thumbExtended);

    _add(out, 'I', confidence);
  }

  void _scoreJ(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    _scoreI(g, out);
  }

  void _scoreK(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    final fingersSpread =
        _centerScore(g.indexMiddleGap, min: 0.30, max: 1.2);

    final thumbBetween =
        _lowScore(g.thumbToIndexMiddlePipMid, max: 0.7);

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.20 * _boolScore(g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.15 * fingersSpread;
    confidence += 0.15 * thumbBetween;

    _add(out, 'K', confidence);
  }

  // ================================================================
  // L
  // ================================================================

  void _scoreL(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (g.middleExtended) {
      return;
    }

    var confidence = 0.0;

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.10 * _boolScore(!g.middleExtended);
    confidence += 0.10 * _boolScore(!g.ringExtended);
    confidence += 0.10 * _boolScore(!g.pinkyExtended);
    confidence += 0.15 * _boolScore(g.thumbExtended);
    confidence += 0.10 * _boolScore(g.indexUp);
    confidence += 0.35 * _boolScore(g.thumbSideways);

    _add(out, 'L', confidence);
  }

  // ================================================================
  // M / N
  // ================================================================

  void _scoreM(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    final threeOverThumb =
        g.indexTipDist > 1.2 &&
        g.middleTipDist > 1.1 &&
        g.ringTipDist > 1.05 &&
        g.pinkyTipDist < 0.95 &&
        g.thumbToIndexTip < 0.8 &&
        g.thumbToMiddleTip < 0.8;

    confidence += 0.55 * _boolScore(threeOverThumb);
    confidence += 0.25 * _boolScore(!g.thumbExtended);
    confidence += 0.20 * _boolScore(g.pinkyTipDist < 0.95);

    _add(out, 'M', confidence);
  }

  void _scoreN(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    final twoOverThumb =
        g.indexTipDist > 1.2 &&
        g.middleTipDist > 1.1 &&
        g.ringTipDist < 0.95 &&
        g.pinkyTipDist < 0.95 &&
        g.thumbToIndexTip < 0.8 &&
        g.thumbToMiddleTip < 0.8;

    confidence += 0.55 * _boolScore(twoOverThumb);
    confidence += 0.25 * _boolScore(!g.thumbExtended);
    confidence += 0.20 *
        _boolScore(g.ringTipDist < 0.95 && g.pinkyTipDist < 0.95);

    _add(out, 'N', confidence);
  }

  // ================================================================
  // O
  // ================================================================

  void _scoreO(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    final closing =
        _lowScore(g.thumbToIndexTip, max: 0.55) +
        _lowScore(g.thumbToMiddleTip, max: 0.65) +
        _lowScore(g.thumbToRingTip, max: 0.80) +
        _lowScore(g.thumbToPinkyTip, max: 1.1);

    final closingScore = closing / 4;

    final closedToThumb =
        g.thumbToIndexTip < 0.75 &&
        g.thumbToMiddleTip < 0.85;

    final notFullyOpen = g.averageFingerTipDist < 1.9;

    if (!closedToThumb || !notFullyOpen) {
      return;
    }

    final indexCurled = g.indexTipDist > 0.85 && g.indexTipDist < 1.7;

    confidence += 0.45 * closingScore;
    confidence += 0.35 * _boolScore(indexCurled);
    confidence += 0.20 * _boolScore(g.thumbToIndexTip < 0.55);

    _add(out, 'O', confidence);
  }

  // ================================================================
  // P / Q
  // ================================================================

  void _scoreP(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.20 * _boolScore(g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.15 * _lowScore(g.indexMiddleGap, max: 0.6);
    confidence += 0.15 * _boolScore(g.indexDown);

    _add(out, 'P', confidence);
  }

  void _scoreQ(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.15 * _boolScore(!g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.20 * _boolScore(g.indexDown);
    confidence += 0.15 * _lowScore(g.thumbToIndexPip, max: 1.1);

    _add(out, 'Q', confidence);
  }

  // ================================================================
  // R
  // ================================================================

  void _scoreR(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (!g.indexMiddleCrossed) {
      return;
    }

    var confidence = 0.0;

    confidence += 0.25 * _boolScore(g.indexExtended);
    confidence += 0.25 * _boolScore(g.middleExtended);
    confidence += 0.20 * _boolScore(g.indexMiddleCrossed);
    confidence += 0.15 * _boolScore(g.indexMiddleGap < 0.6);
    confidence += 0.15 * _boolScore(g.indexUp);

    _add(out, 'R', confidence);
  }

  // ================================================================
  // S
  // ================================================================

  void _scoreS(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    final thumbTucked =
        g.thumbTipDist < 1.0 && g.thumbToPalmCenter < 0.8;

    final indexNearPalm = g.indexTipToPalmCenter < 0.70;

    confidence += 0.45 * _closedFourScore(g);
    confidence += 0.30 * _boolScore(!g.thumbExtended);
    confidence += 0.25 * _boolScore(thumbTucked && indexNearPalm);

    _add(out, 'S', confidence);
  }

  // ================================================================
  // T
  // ================================================================

  void _scoreT(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    final thumbProtrudes =
        g.thumbTipDist >= 0.30 && g.thumbTipDist <= 1.35;

    final thumbVertical =
        g.thumbUp && g.indexTipToPalmCenter < 0.70;

    final fistLike =
        g.averageFingerTipDist > 0.85;

    confidence += 0.35 * _closedFourScore(g);
    confidence += 0.25 * _boolScore(fistLike);
    confidence += 0.20 * _boolScore(thumbProtrudes);
    confidence += 0.20 * _boolScore(thumbVertical);

    _add(out, 'T', confidence);
  }

  // ================================================================
  // U / V
  // ================================================================

  void _scoreU(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (g.ringExtended || g.pinkyExtended || g.thumbExtended) {
      return;
    }

    var confidence = 0.0;

    final together = _lowScore(g.indexMiddleGap, max: 0.4);
    final thumbAway = g.thumbToIndexMiddlePipMid > 0.5;

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.20 * _boolScore(g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.15 * together;
    confidence += 0.15 * _boolScore(thumbAway);

    _add(out, 'U', confidence);
  }

  void _scoreV(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (g.ringExtended || g.pinkyExtended || g.thumbExtended) {
      return;
    }

    var confidence = 0.0;

    final spread =
        _centerScore(g.indexMiddleGap, min: 0.40, max: 1.6);

    final thumbAway = g.thumbToIndexMiddlePipMid > 0.5;

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.20 * _boolScore(g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.15 * spread;
    confidence += 0.15 * _boolScore(thumbAway);

    _add(out, 'V', confidence);
  }

  // ================================================================
  // W
  // ================================================================

  void _scoreW(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (g.pinkyExtended) {
      return;
    }

    var confidence = 0.0;

    final spread =
        (_centerScore(g.indexMiddleGap, min: 0.25, max: 1.2) +
            _centerScore(g.middleRingGap, min: 0.25, max: 1.2)) /
        2;

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.20 * _boolScore(g.middleExtended);
    confidence += 0.20 * _boolScore(g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.25 * spread;

    _add(out, 'W', confidence);
  }

  // ================================================================
  // X
  // ================================================================

  void _scoreX(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    final hookedIndex =
        g.indexBendRatio >= 0.88 && g.indexBendRatio <= 1.10;

    final indexAwayFromPalm =
        g.indexTipToPalmCenter > 0.30 &&
        g.indexTipDist > 1.05 &&
        g.indexTipDist <= 1.5;

    final thumbTucked = g.thumbTipDist < 1.0;

    confidence += 0.30 * _closedFourScore(g);
    confidence += 0.35 * _boolScore(hookedIndex);
    confidence += 0.25 * _boolScore(indexAwayFromPalm);
    confidence += 0.10 * _boolScore(thumbTucked);

    _add(out, 'X', confidence);
  }

  // ================================================================
  // Y
  // ================================================================

  void _scoreY(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (g.indexExtended || g.middleExtended || g.ringExtended) {
      return;
    }

    var confidence = 0.0;

    final separated =
        g.thumbToPinkyTip > 0.55;

    confidence += 0.20 * _boolScore(g.thumbExtended);
    confidence += 0.20 * _boolScore(g.pinkyExtended);
    confidence += 0.15 * _boolScore(!g.indexExtended);
    confidence += 0.15 * _boolScore(!g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(separated);

    _add(out, 'Y', confidence);
  }

  // ================================================================
  // Z
  // ================================================================

  void _scoreZ(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    confidence += 0.25 * _boolScore(g.indexExtended);
    confidence += 0.15 * _boolScore(!g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.20 * _boolScore(g.indexForward);
    confidence += 0.10 * _boolScore(!g.thumbExtended);

    _add(out, 'Z', confidence);
  }

  // ================================================================
  // NUMBER 0
  // A tight circle: thumb tip meets the index fingertip, fingers curled
  // into a ring. Shares its handshape family with O and S.
  // ================================================================

  void _score0(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    final circleClosed = g.thumbToIndexTip < 0.45;

    final fingersCurled =
        g.averageFingerTipDist > 0.60 &&
        g.averageFingerTipDist < 1.60;

    if (!circleClosed || !fingersCurled) {
      return;
    }

    var confidence = 0.0;

    confidence += 0.40 * _lowScore(g.thumbToIndexTip, max: 0.45);
    confidence += 0.25 * _lowScore(g.thumbToMiddleTip, max: 0.75);
    confidence += 0.20 *
        _centerScore(g.averageFingerTipDist, min: 0.70, max: 1.50);
    confidence += 0.15 * _boolScore(g.thumbToIndexTip < 0.20);

    _add(out, '0', confidence);
  }

  // ================================================================
  // NUMBER 1
  // Only index finger extended, thumb folded
  // Distinct from D: thumb is NOT extended
  // ================================================================

  void _score1(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (g.middleExtended || g.ringExtended || g.pinkyExtended) {
      return;
    }

    var confidence = 0.0;

    final thumbFolded = !g.thumbExtended;

    confidence += 0.25 * _boolScore(g.indexExtended);
    confidence += 0.20 * _boolScore(g.indexUp);
    confidence += 0.15 * _boolScore(!g.middleExtended);
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.10 * _boolScore(thumbFolded);

    _add(out, '1', confidence);
  }

  // ================================================================
  // NUMBER 2
  // Index + middle extended and held together, thumb folded.
  // Shares its handshape family with U and V.
  // ================================================================

  void _score2(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (g.ringExtended || g.pinkyExtended) {
      return;
    }

    var confidence = 0.0;

    final together = _lowScore(g.indexMiddleGap, max: 0.5);
    final thumbFolded = !g.thumbExtended;

    confidence += 0.20 * _boolScore(g.indexExtended);
    confidence += 0.20 * _boolScore(g.middleExtended);
    confidence += 0.20 * together;
    confidence += 0.15 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.10 * _boolScore(thumbFolded);

    _add(out, '2', confidence);
  }

  // ================================================================
  // NUMBER 3
  // Thumb + index + middle extended and spread, ring + pinky folded.
  // Distinct from W (three fingers, thumb folded).
  // ================================================================

  void _score3(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (g.ringExtended || g.pinkyExtended) {
      return;
    }

    var confidence = 0.0;

    final threeOpen =
        g.indexExtended &&
        g.middleExtended &&
        g.thumbExtended;

    if (!threeOpen) {
      return;
    }

    // In "3" the thumb points clearly away from the two fingers; in K it
    // sits between them. Reject when the thumb is tucked against the
    // index/middle knuckles (K's signature).
    if (g.thumbToIndexMiddlePipMid < 0.6) {
      return;
    }

    final fingersSpread =
        _centerScore(g.indexMiddleGap, min: 0.25, max: 1.2);

    final thumbSeparated = g.thumbToIndexTip > 0.35;

    confidence += 0.30 * _boolScore(threeOpen);
    confidence += 0.25 * fingersSpread;
    confidence += 0.20 * _boolScore(!g.ringExtended);
    confidence += 0.15 * _boolScore(!g.pinkyExtended);
    confidence += 0.10 * _boolScore(thumbSeparated);

    _add(out, '3', confidence);
  }

  // ================================================================
  // NUMBER 4
  // All four fingers extended and WIDE APART, thumb folded across palm.
  // Distinct from B (fingers together).
  // ================================================================

  void _score4(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (!g.allFourExtended) {
      return;
    }

    final widelySpread =
        g.indexMiddleGap > 0.40 &&
        g.middleRingGap > 0.40 &&
        g.ringPinkyGap > 0.30;

    final thumbFolded = !g.thumbExtended;

    final thumbAcrossPalm =
        g.thumbToMidPalm < 1.1 &&
        g.thumbToPinkyMcp < 1.4;

    if (!widelySpread) {
      return;
    }

    var confidence = 0.0;

    confidence += 0.25 * _boolScore(g.allFourExtended);
    confidence += 0.25 * _boolScore(widelySpread);
    confidence += 0.20 * _boolScore(thumbFolded);
    confidence += 0.15 * _boolScore(thumbAcrossPalm);
    confidence += 0.15 * _boolScore(g.indexMiddleGap > 0.55);

    _add(out, '4', confidence);
  }

  // ================================================================
  // NUMBER 5
  // All five fingers extended and spread
  // ================================================================

  void _score5(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    var confidence = 0.0;

    final allOpen =
        g.thumbExtended &&
        g.indexExtended &&
        g.middleExtended &&
        g.ringExtended &&
        g.pinkyExtended;

    if (!allOpen) {
      return;
    }

    final fingersSpread =
        g.indexMiddleGap > 0.45 &&
        g.middleRingGap > 0.40 &&
        g.ringPinkyGap > 0.35;

    final thumbSeparate = g.thumbToIndexTip > 0.40;

    if (!fingersSpread) {
      return;
    }

    confidence += 0.30 * _boolScore(allOpen);
    confidence += 0.30 * _boolScore(fingersSpread);
    confidence += 0.20 * _boolScore(thumbSeparate);
    confidence += 0.20 *
        _centerScore(g.averageFingerTipDist, min: 1.2, max: 3.0);

    _add(out, '5', confidence);
  }

  // ================================================================
  // NUMBER 6
  // Thumb touches pinky tip, index + middle + ring extended
  // ================================================================

  void _score6(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (!g.indexExtended ||
        !g.middleExtended ||
        !g.ringExtended ||
        g.pinkyExtended) {
      return;
    }

    // Thumb must actually touch the pinky tip (hard gate). 6 is a tighter
    // stretch than 7/8/9, so allow a little more slack than 0.35.
    final thumbPinkyClosed = g.thumbToPinkyTip < 0.55;

    if (!thumbPinkyClosed) {
      return;
    }

    final thumbClearOfOtherFingers = g.thumbToIndexTip > 0.40;

    var confidence = 0.0;

    confidence += 0.30 * _boolScore(thumbPinkyClosed);
    confidence += 0.15 * _boolScore(g.indexExtended);
    confidence += 0.15 * _boolScore(g.middleExtended);
    confidence += 0.15 * _boolScore(g.ringExtended);
    confidence += 0.10 * _boolScore(thumbClearOfOtherFingers);
    confidence += 0.15 * _boolScore(g.thumbToPinkyTip < 0.35);

    _add(out, '6', confidence);
  }

  // ================================================================
  // NUMBER 7
  // Thumb touches ring tip, others extended/folded as needed
  // ================================================================

  void _score7(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (!g.indexExtended ||
        !g.middleExtended ||
        !g.pinkyExtended ||
        g.ringExtended) {
      return;
    }

    final thumbRingClosed = g.thumbToRingTip < 0.35;

    if (!thumbRingClosed) {
      return;
    }

    final thumbClearOfOtherFingers = g.thumbToIndexTip > 0.50;

    var confidence = 0.0;

    confidence += 0.35 * _boolScore(thumbRingClosed);
    confidence += 0.15 * _boolScore(g.indexExtended);
    confidence += 0.15 * _boolScore(g.middleExtended);
    confidence += 0.10 * _boolScore(!g.ringExtended);
    confidence += 0.10 * _boolScore(g.pinkyExtended);
    confidence += 0.10 * _boolScore(thumbClearOfOtherFingers);
    confidence += 0.05 * _boolScore(!g.thumbExtended);

    _add(out, '7', confidence);
  }

  // ================================================================
  // NUMBER 8
  // Thumb touches middle tip, index + ring + pinky extended
  // ================================================================

  void _score8(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (!g.indexExtended ||
        !g.ringExtended ||
        !g.pinkyExtended ||
        g.middleExtended) {
      return;
    }

    final thumbMiddleClosed = g.thumbToMiddleTip < 0.35;

    if (!thumbMiddleClosed) {
      return;
    }

    final thumbClearOfOtherFingers = g.thumbToIndexTip > 0.50;

    var confidence = 0.0;

    confidence += 0.35 * _boolScore(thumbMiddleClosed);
    confidence += 0.15 * _boolScore(g.indexExtended);
    confidence += 0.10 * _boolScore(!g.middleExtended);
    confidence += 0.15 * _boolScore(g.ringExtended);
    confidence += 0.10 * _boolScore(g.pinkyExtended);
    confidence += 0.10 * _boolScore(thumbClearOfOtherFingers);
    confidence += 0.05 * _boolScore(!g.thumbExtended);

    _add(out, '8', confidence);
  }

  // ================================================================
  // NUMBER 9
  // Thumb touches index tip, middle + ring + pinky extended
  // ================================================================

  void _score9(
    HandGeometry g,
    List<_Candidate> out,
  ) {
    if (!g.middleExtended ||
        !g.ringExtended ||
        !g.pinkyExtended ||
        g.indexExtended) {
      return;
    }

    final thumbIndexClosed = g.thumbToIndexTip < 0.35;

    if (!thumbIndexClosed) {
      return;
    }

    final thumbClearOfOtherFingers = g.thumbToMiddleTip > 0.50;

    var confidence = 0.0;

    confidence += 0.35 * _boolScore(thumbIndexClosed);
    confidence += 0.15 * _boolScore(!g.indexExtended);
    confidence += 0.15 * _boolScore(g.middleExtended);
    confidence += 0.15 * _boolScore(g.ringExtended);
    confidence += 0.10 * _boolScore(g.pinkyExtended);
    confidence += 0.05 * _boolScore(thumbClearOfOtherFingers);
    confidence += 0.05 * _boolScore(!g.thumbExtended);

    _add(out, '9', confidence);
  }
}