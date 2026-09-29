import '../domain/movement_phase.dart';

class AttemptState {
  final bool isActive;
  final bool justFinished;
  final bool reachedTop;

  AttemptState({required this.isActive, required this.justFinished, required this.reachedTop});
}

class AttemptTracker {
  bool _isActive = false;

  AttemptState processPhase(MovementPhase phase) {
    return processPhaseString(phase.name);
  }

  AttemptState processPhaseString(String phaseStr) {
    bool justFinished = false;
    bool reachedTop = false;
    String lower = phaseStr.toLowerCase();

    if (!_isActive && (lower == 'descending' || lower == 'flexing' || lower == 'initiating')) {
      _isActive = true;
    } else if (_isActive) {
      if (lower == 'completed') {
        _isActive = false;
        justFinished = true;
        reachedTop = true;
      } else if (lower == 'aborted') {
        _isActive = false;
        justFinished = true;
        reachedTop = false;
      }
    }

    return AttemptState(isActive: _isActive, justFinished: justFinished, reachedTop: reachedTop);
  }

  void reset() => _isActive = false;
}