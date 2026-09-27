import '../../models/landmark.dart';
import 'alphabet_poses.dart';
import 'number_poses.dart';

/// Reference handshapes for every sign the camera can check.
///
/// A learner practising "RED" does not need a separate red reference hand: FSL
/// uses the X hand for red, the B hand for blue, and so on, so the colour and
/// animal signs reuse the letter and digit handshapes wholesale. That is why
/// this table covers 47 signs with only 35 distinct poses, and why adding
/// corrective feedback for colours and animals needed no new pose data.
///
/// [handshapeFor] resolves any of the 47 sign labels to the letter or digit
/// whose pose it should be compared against, or null if the sign is not
/// handshape-based (the everyday motion signs, which are handled elsewhere).
class ReferenceSigns {
  /// Every label that has a handshape reference, i.e. every sign the
  /// corrective-feedback engine can comment on.
  static const Map<String, String> handshapeByLabel = {
    // Letters. FSL's alphabet has no J.
    'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D', 'E': 'E', 'F': 'F', 'G': 'G',
    'H': 'H', 'I': 'I', 'K': 'K', 'L': 'L', 'M': 'M', 'N': 'N', 'O': 'O',
    'P': 'P', 'Q': 'Q', 'R': 'R', 'S': 'S', 'T': 'T', 'U': 'U', 'V': 'V',
    'W': 'W', 'X': 'X', 'Y': 'Y', 'Z': 'Z',

    // Numbers.
    '0': '0', '1': '1', '2': '2', '3': '3', '4': '4',
    '5': '5', '6': '6', '7': '7', '8': '8', '9': '9',

    // Colors, which are held as letters.
    'RED': 'X',
    'BLUE': 'B',
    'GREEN': 'G',
    'ORANGE': 'C',
    'PURPLE': 'P',
    'YELLOW': 'Y',

    // Animals, also held as letters or digits.
    'BIRD': 'G',
    'CAT': 'F',
    'COW': 'Y',
    'FROG': 'V',
    'LION': 'C',
    'FISH': '5',
  };

  /// Number words, which the curriculum stores in this form.
  static const Map<String, String> numberWords = {
    'ZERO': '0',
    'ONE': '1',
    'TWO': '2',
    'THREE': '3',
    'FOUR': '4',
    'FIVE': '5',
    'SIX': '6',
    'SEVEN': '7',
    'EIGHT': '8',
    'NINE': '9',
  };

  static final Map<String, String> _resolved = {
    for (final entry in handshapeByLabel.entries) entry.key: entry.value,
    for (final entry in numberWords.entries) entry.key: entry.value,
  };

  /// Every label [landmarksFor] can serve, i.e. the full 47-sign feedback
  /// scope: 25 letters, 10 numbers, 6 colors, 6 animals.
  static Set<String> get supportedLabels => _resolved.keys.toSet();

  /// The letter or digit a sign is made with, or null if it is not
  /// handshape-based.
  static String? handshapeFor(String label) =>
      _resolved[label.trim().toUpperCase()];

  static bool isSupported(String label) => handshapeFor(label) != null;

  /// The reference 21-landmark hand for [label], or null if unsupported.
  ///
  /// Poses are built fresh on each call rather than cached, so a caller cannot
  /// mutate the shared reference data.
  static List<Landmark>? landmarksFor(String label) {
    final shape = handshapeFor(label);
    if (shape == null) return null;
    return _poseFor(shape);
  }

  static List<Landmark>? _poseFor(String shape) {
    if (shape.length == 1) {
      final code = shape.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) {
        return _number(shape.codeUnitAt(0) - 0x30);
      }
      return _letter(shape);
    }
    return null;
  }

  static List<Landmark> _letter(String upper) {
    switch (upper) {
      case 'A':
        return AlphabetPoses.a();
      case 'B':
        return AlphabetPoses.b();
      case 'C':
        return AlphabetPoses.c();
      case 'D':
        return AlphabetPoses.d();
      case 'E':
        return AlphabetPoses.e();
      case 'F':
        return AlphabetPoses.f();
      case 'G':
        return AlphabetPoses.g();
      case 'H':
        return AlphabetPoses.h();
      case 'I':
        return AlphabetPoses.i();
      case 'K':
        return AlphabetPoses.k();
      case 'L':
        return AlphabetPoses.l();
      case 'M':
        return AlphabetPoses.m();
      case 'N':
        return AlphabetPoses.n();
      case 'O':
        return AlphabetPoses.o();
      case 'P':
        return AlphabetPoses.p();
      case 'Q':
        return AlphabetPoses.q();
      case 'R':
        return AlphabetPoses.r();
      case 'S':
        return AlphabetPoses.s();
      case 'T':
        return AlphabetPoses.t();
      case 'U':
        return AlphabetPoses.u();
      case 'V':
        return AlphabetPoses.v();
      case 'W':
        return AlphabetPoses.w();
      case 'X':
        return AlphabetPoses.x();
      case 'Y':
        return AlphabetPoses.y();
      case 'Z':
        return AlphabetPoses.z();
      default:
        throw ArgumentError('No reference pose for letter "$upper"');
    }
  }

  static List<Landmark> _number(int digit) {
    switch (digit) {
      case 0:
        return NumberPoses.zero();
      case 1:
        return NumberPoses.one();
      case 2:
        return NumberPoses.two();
      case 3:
        return NumberPoses.three();
      case 4:
        return NumberPoses.four();
      case 5:
        return NumberPoses.five();
      case 6:
        return NumberPoses.six();
      case 7:
        return NumberPoses.seven();
      case 8:
        return NumberPoses.eight();
      case 9:
        return NumberPoses.nine();
      default:
        throw ArgumentError('No reference pose for digit $digit');
    }
  }
}
