/// Canonicalisation of the curriculum's sign labels.
///
/// The stored `ai_label` is not consistent across the curriculum: numbers
/// appear both as digits and as words, everyday signs appear both with spaces
/// and with underscores, and colours and animals are stored as words while the
/// hand that makes them is a letter.
///
/// The practice screen and the quiz must agree exactly on what a label means,
/// or a sign the learner performs in the quiz will not match the one they were
/// taught. This lives in one place so they cannot drift.
library;

/// Word signs that are performed with a letter or digit handshape.
///
/// Colours and animals are held as letters in FSL - RED is the X hand, FROG is
/// V, FISH is 5 - so recognising them through the camera means recognising the
/// underlying handshape.
const Map<String, String> shapeLabelByWord = {
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
  // Colors (static handshapes)
  'RED': 'X',
  'BLUE': 'B',
  'GREEN': 'G',
  'ORANGE': 'C',
  'PURPLE': 'P',
  'YELLOW': 'Y',
  // Animals (static handshapes)
  'BIRD': 'G',
  'CAT': 'F',
  'COW': 'Y',
  'FROG': 'V',
  'LION': 'C',
  'FISH': '5',
};

/// Reduces a raw label to the form the recognisers speak: upper case, with
/// whitespace collapsed to underscores so that both `'Excuse Me'` and
/// `'EXCUSE_ME'` resolve to `EXCUSE_ME`.
///
/// Word signs that are performed with a letter or digit are additionally
/// mapped to that handshape.
String canonicalSignLabel(String raw) {
  final value = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');
  return shapeLabelByWord[value] ?? value;
}

/// True when the label names a colour or animal, which the camera recognises
/// as the letter handshape it is performed with.
bool isWordShapedSign(String raw) {
  final value = raw.trim().toUpperCase();
  return value == 'RED' ||
      value == 'BLUE' ||
      value == 'GREEN' ||
      value == 'ORANGE' ||
      value == 'PURPLE' ||
      value == 'YELLOW' ||
      value == 'BIRD' ||
      value == 'CAT' ||
      value == 'COW' ||
      value == 'FROG' ||
      value == 'LION' ||
      value == 'FISH';
}
