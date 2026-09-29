import 'dart:collection';
import '../domain/unified_landmark.dart';

class CadenceDetector {
  static const double _windowSeconds = 8.0;
  static const double _cooldownSec = 0.30;

  final ListQueue<double> _strikeTimestamps = ListQueue();

  final _AnkleTracker _left = _AnkleTracker();
  final _AnkleTracker _right = _AnkleTracker();

  double _lastLeftStrike = 0.0;
  double _lastRightStrike = 0.0;
  
  int totalSteps = 0;
  final List<int> _cadenceHistory = [];

  int process(Map<String, UnifiedLandmark> landmarks, double timestampSec) {
    _cleanOldStrikes(timestampSec);

    final leftY = landmarks['leftAnkle']?.y;
    final rightY = landmarks['rightAnkle']?.y;

    if (leftY != null && _left.update(leftY) &&
        timestampSec - _lastLeftStrike > _cooldownSec) {
      _strikeTimestamps.addLast(timestampSec);
      _lastLeftStrike = timestampSec;
      totalSteps++;
    }

    if (rightY != null && _right.update(rightY) &&
        timestampSec - _lastRightStrike > _cooldownSec) {
      _strikeTimestamps.addLast(timestampSec);
      _lastRightStrike = timestampSec;
      totalSteps++;
    }

    if (_strikeTimestamps.length < 3) return 0;

    final activeWindow = timestampSec - _strikeTimestamps.first;
    if (activeWindow < 2.0) return 0;

    final currentCadence = ((_strikeTimestamps.length / activeWindow) * 60.0).round();

    // 🚀 Clean single-source filter: drop warm-up lag or noise spikes
    if (currentCadence >= 60 && currentCadence <= 220) {
      _cadenceHistory.add(currentCadence);
    }

    return currentCadence;
  }

  int get averageCadence {
    if (_cadenceHistory.isEmpty) return 0;
    return (_cadenceHistory.reduce((a, b) => a + b) / _cadenceHistory.length).round();
  }

  void _cleanOldStrikes(double now) {
    while (_strikeTimestamps.isNotEmpty &&
           now - _strikeTimestamps.first > _windowSeconds) {
      _strikeTimestamps.removeFirst();
    }
  }

  void reset() {
    _strikeTimestamps.clear();
    _left.reset();
    _right.reset();
    _lastLeftStrike = 0.0;
    _lastRightStrike = 0.0;
    totalSteps = 0;
    _cadenceHistory.clear();
  }
}

class _AnkleTracker {
  static const double _minDescentPx = 12.0;

  double? _prevY;
  bool _wasDescending = false;
  int _consecutiveDescendingFrames = 0;
  double _descentPeakY = 0.0;
  double _descentStartY = 0.0;

  bool update(double y) {
    if (_prevY == null) {
      _prevY = y;
      return false;
    }

    final delta = y - _prevY!;
    _prevY = y;

    final isDescending = delta > 0;
    final isAscending = delta < 0;

    bool strike = false;

    if (isDescending) {
      if (_consecutiveDescendingFrames == 0) {
        _descentStartY = y;
        _descentPeakY = y;
      } else if (y > _descentPeakY) {
        _descentPeakY = y;
      }
      _consecutiveDescendingFrames++;
      _wasDescending = true;
    } else if (isAscending) {
      final descentMagnitude = _descentPeakY - _descentStartY;

      if (_wasDescending &&
          _consecutiveDescendingFrames >= 3 &&
          descentMagnitude >= _minDescentPx) {
        strike = true;
      }
      _wasDescending = false;
      _consecutiveDescendingFrames = 0;
    }

    return strike;
  }

  void reset() {
    _prevY = null;
    _wasDescending = false;
    _consecutiveDescendingFrames = 0;
    _descentPeakY = 0.0;
    _descentStartY = 0.0;
  }
}