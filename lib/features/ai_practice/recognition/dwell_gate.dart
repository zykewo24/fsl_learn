import 'dart:math' as math;

/// Where a [DwellGate] hold currently stands.
enum DwellStage {
  /// Nothing is being held.
  idle,

  /// The sign is currently being held and the timer is running.
  holding,

  /// The match was lost briefly. Partial progress is preserved and resumes if
  /// the same sign comes back inside the grace window.
  paused,

  /// The hold is complete. Latched until [DwellGate.reset].
  complete,
}

/// Result of one [DwellGate.feed] call.
class DwellUpdate {
  final DwellStage stage;

  /// Fraction of the required hold accumulated so far, clamped to `0..1`.
  final double progress;

  /// True on exactly the frame the hold completed. Edge-triggered: it does not
  /// remain true on later frames of the same hold, so a caller can commit
  /// exactly once without keeping its own "already done" flag.
  final bool justCompleted;

  const DwellUpdate(
    this.stage,
    this.progress, {
    this.justCompleted = false,
  });

  static const DwellUpdate idle =
      DwellUpdate(DwellStage.idle, 0, justCompleted: false);
}

/// Requires a sign to be *held* rather than merely seen before it counts as
/// completed.
///
/// The practice screen used to complete a sign on the second consecutive frame
/// that matched, which at the ~20fps detection rate is only 50-100ms. A sign
/// that flashed past during a hand transition was therefore enough to mark a
/// sign mastered. [feed] turns that into a dwell: the match has to survive for
/// [requiredHold] before it commits.
///
/// Two details matter for real use:
///
///  * **Grace on dropouts.** MediaPipe drops frames. A naive timer would reset
///    to zero every time tracking hiccups, so a learner who held the sign for
///    1.9s could be sent back to the start by one bad frame. Losing the match
///    pauses instead, and the partial progress is restored if the same sign
///    returns within [grace]. The paused span itself is not credited.
///  * **Injectable clock.** [_clock] drives every timestamp, so the timing
///    behaviour is testable without real delays.
///
/// A [requiredHold] of zero degrades to the old behaviour - it completes on the
/// first frame it is told about - which is why the caller keeps its existing
/// two-frame debounce in front of this rather than replacing it.
class DwellGate {
  /// How long a lost match is tolerated before partial progress is discarded.
  static const Duration defaultGrace = Duration(milliseconds: 300);

  final DateTime Function() _clock;
  final Duration grace;

  Duration _requiredHold;

  /// Identity of the sign currently being held, or null when nothing is held.
  String? _signId;

  /// Active hold time accumulated across segments, excluding paused spans.
  int _heldMs = 0;

  /// Start of the current *active* segment, or null while paused.
  DateTime? _segmentStart;

  /// When the match was last lost. Null while the match is live.
  DateTime? _lostAt;

  bool _completed = false;

  DwellGate({
    required Duration requiredHold,
    Duration? grace,
    DateTime Function()? clock,
  })  : _requiredHold = requiredHold,
        grace = grace ?? defaultGrace,
        _clock = clock ?? DateTime.now;

  Duration get requiredHold => _requiredHold;

  /// True when the hold time is zero, i.e. completion is immediate.
  bool get isInstant => _requiredHold <= Duration.zero;

  /// Accumulated hold progress, `0..1`. Readable by the UI between frames.
  double get progress {
    final total = _requiredHold.inMilliseconds;
    if (total <= 0) return isLatchedComplete ? 1 : 0;
    return math.min(1.0, _heldMs / total);
  }

  /// The sign being held, or null.
  String? get heldSignId => _signId;

  /// Whether the hold has already completed and not yet been reset.
  bool get isLatchedComplete => _completed;

  /// Changes the required hold. Resets any hold in progress, because partial
  /// progress measured against a different duration is meaningless.
  void setRequiredHold(Duration value) {
    if (value == _requiredHold) return;
    _requiredHold = value;
    reset();
  }

  /// Advances the gate by one frame.
  ///
  /// [signId] identifies the sign the recogniser currently credits the user
  /// with, or null when there is no credible match this frame (no hand, low
  /// confidence, unstable label, or a sign already completed). Passing null is
  /// what makes the hold pause rather than blindly accumulating.
  DwellUpdate feed({required String? signId}) {
    final now = _clock();
    final DwellUpdate base;

    if (signId == null) {
      _closeSegment(now);

      if (_signId == null) return DwellUpdate.idle;

      _lostAt ??= now;
      if (now.difference(_lostAt!) >= grace) {
        // The dropout outlived the grace window; start over from scratch.
        reset();
        return DwellUpdate.idle;
      }
      base = DwellUpdate(DwellStage.paused, progress);
    } else if (_signId != signId) {
      // A different sign voids the previous hold outright - the learner moved
      // on rather than stumbled, so carrying progress over would be wrong.
      _closeSegment(now);
      _signId = signId;
      _segmentStart = now;
      _lostAt = null;
      _completed = false;
      _heldMs = 0;

      if (isInstant) {
        _completed = true;
        return const DwellUpdate(DwellStage.complete, 1, justCompleted: true);
      }
      base = const DwellUpdate(DwellStage.holding, 0);
    } else if (_lostAt != null) {
      // Same sign as before, but the match had been lost. Decide whether the
      // dropout was short enough to resume.
      if (now.difference(_lostAt!) >= grace) {
        _heldMs = 0;
        _lostAt = null;
        _segmentStart = now;
        base = const DwellUpdate(DwellStage.holding, 0);
      } else {
        // Resumed in time. The paused span is deliberately not credited.
        _lostAt = null;
        _segmentStart = now;
        base = DwellUpdate(DwellStage.holding, progress);
      }
    } else {
      _closeSegmentTo(now);
      base = DwellUpdate(DwellStage.holding, progress);
    }

    // Completion is checked in exactly one place, so a hold that satisfied the
    // duration across a dropout still reports it on the resuming frame rather
    // than showing 100% and committing a frame late.
    if (base.stage == DwellStage.holding &&
        !_completed &&
        _heldMs >= _requiredHold.inMilliseconds) {
      _completed = true;
      return DwellUpdate(DwellStage.holding, 1, justCompleted: true);
    }

    return base;
  }

  /// Credits elapsed time to the current segment and closes it, so a subsequent
  /// pause cannot keep accruing.
  void _closeSegment(DateTime now) {
    if (_segmentStart == null) return;
    final delta = now.difference(_segmentStart!).inMilliseconds;
    if (delta > 0) _heldMs += delta;
    _segmentStart = null;
  }

  /// Credits elapsed time but leaves the segment open, for consecutive frames
  /// of a live match.
  void _closeSegmentTo(DateTime now) {
    if (_segmentStart == null) {
      _segmentStart = now;
      return;
    }
    final delta = now.difference(_segmentStart!).inMilliseconds;
    if (delta > 0) _heldMs += delta;
    _segmentStart = now;
  }

  /// Drops all hold state. Called after a commit, and when the user changes
  /// the configured hold time.
  void reset() {
    _signId = null;
    _heldMs = 0;
    _segmentStart = null;
    _lostAt = null;
    _completed = false;
  }
}
