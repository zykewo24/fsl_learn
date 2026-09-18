import '../models/gesture_debug_data.dart';

class ACalibrationTracker {
  final List<GestureDebugData> _samples = [];

  void addSample(GestureDebugData sample) {
    _samples.add(sample);
  }

  void clear() {
    _samples.clear();
  }

  int get sampleCount => _samples.length;

  double get minThumbToIndex {
    if (_samples.isEmpty) return 0;

    return _samples
        .map((sample) => sample.thumbToIndex)
        .reduce((a, b) => a < b ? a : b);
  }

  double get maxThumbToIndex {
    if (_samples.isEmpty) return 0;

    return _samples
        .map((sample) => sample.thumbToIndex)
        .reduce((a, b) => a > b ? a : b);
  }

  double get minThumbToPinky {
    if (_samples.isEmpty) return 0;

    return _samples
        .map((sample) => sample.thumbToPinky)
        .reduce((a, b) => a < b ? a : b);
  }

  double get maxThumbToPinky {
    if (_samples.isEmpty) return 0;

    return _samples
        .map((sample) => sample.thumbToPinky)
        .reduce((a, b) => a > b ? a : b);
  }

  double get averageThumbToIndex {
    if (_samples.isEmpty) return 0;

    final total = _samples.fold<double>(
      0,
      (sum, sample) => sum + sample.thumbToIndex,
    );

    return total / _samples.length;
  }

  double get averageThumbToPinky {
    if (_samples.isEmpty) return 0;

    final total = _samples.fold<double>(
      0,
      (sum, sample) => sum + sample.thumbToPinky,
    );

    return total / _samples.length;
  }

  double get matchRate {
    if (_samples.isEmpty) return 0;

    final matches =
        _samples.where((sample) => sample.matchesA).length;

    return matches / _samples.length;
  }
}