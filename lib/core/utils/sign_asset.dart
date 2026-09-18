/// Resolves the bundled reference image for a sign given its raw AI label.
///
/// Letters (A-Z) map to `assets/fsl/alphabet/<letter>.png`, digits (0-9,
/// including plain words like "ONE") map to `assets/fsl/numbers/<digit>.png`,
/// and motion-based FSL greetings map to `assets/fsl/greetings/<label>.png`.
/// Returns `null` when no bundled image exists for the label.
const Map<String, String> _numberWordToDigit = {
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

/// Greeting labels that have a bundled reference image under
/// `assets/fsl/greetings/`. Keys are uppercased AI labels.
const Map<String, String> _greetingAssets = {
  'KUMASTA': 'kumusta',
  'SALAMAT': 'salamat',
  'PAALAM': 'paalam',
};

/// Emergency labels that have a bundled reference image under
/// `assets/fsl/emergency/`. Keys are uppercased AI labels.
const Map<String, String> _emergencyAssets = {
  'HELP': 'help',
  'FIRE': 'fire',
  'DANGER': 'danger',
  'MEDICAL': 'medical',
};

/// Everyday-communication labels that have a bundled reference image
/// under `assets/fsl/everyday/`. Keys are uppercased AI labels.
const Map<String, String> _everydayAssets = {
  'YES': 'yes',
  'NO': 'no',
  'PLEASE': 'please',
  'SORRY': 'sorry',
  'EXCUSE_ME': 'excuse_me',
  'GOOD_MORNING': 'good_morning',
  'GOOD_NIGHT': 'good_night',
  'LOVE': 'love',
  'WELCOME': 'welcome',
  'WATER': 'water',
  'EAT': 'eat',
  'DRINK': 'drink',
};

/// Static-sign labels that have a bundled reference image under
/// `assets/fsl/colors/`. Keys are uppercased AI labels.
const Map<String, String> _colorsAssets = {
  'RED': 'red',
  'BLUE': 'blue',
  'GREEN': 'green',
  'ORANGE': 'orange',
  'PURPLE': 'purple',
  'YELLOW': 'yellow',
};

/// Static-sign labels that have a bundled reference image under
/// `assets/fsl/animals/`. Keys are uppercased AI labels.
const Map<String, String> _animalsAssets = {
  'BIRD': 'bird',
  'CAT': 'cat',
  'COW': 'cow',
  'FROG': 'frog',
  'LION': 'lion',
  'FISH': 'fish',
};

String? resolveSignAssetPath(String rawLabel) {
  final value = rawLabel.trim().toUpperCase();
  final label = _numberWordToDigit[value] ?? value;

  final greeting = _greetingAssets[label];
  if (greeting != null) {
    return 'assets/fsl/greetings/$greeting.png';
  }

  final emergency = _emergencyAssets[label];
  if (emergency != null) {
    return 'assets/fsl/emergency/$emergency.png';
  }

  final everyday = _everydayAssets[label];
  if (everyday != null) {
    return 'assets/fsl/everyday/$everyday.png';
  }

  final color = _colorsAssets[label];
  if (color != null) {
    return 'assets/fsl/colors/$color.png';
  }

  final animal = _animalsAssets[label];
  if (animal != null) {
    return 'assets/fsl/animals/$animal.png';
  }

  if (label.length == 1 &&
      label.codeUnitAt(0) >= 65 &&
      label.codeUnitAt(0) <= 90) {
    return 'assets/fsl/alphabet/${label.toLowerCase()}.png';
  }

  if (label.length == 1 &&
      label.codeUnitAt(0) >= 48 &&
      label.codeUnitAt(0) <= 57) {
    return 'assets/fsl/numbers/$label.png';
  }

  return null;
}
