enum MovementPhase { top, descending, bottom, ascending }

class RepTracker {
  int reps = 0;
  int get totalAttempts => reps; // Added getter to resolve undefined getter error
  MovementPhase currentPhase = MovementPhase.top;

  double topThreshold;
  double enterBottomThreshold;
  double leaveBottomThreshold;

  RepTracker({
    this.topThreshold = 160.0,         
    this.enterBottomThreshold = 120.0, 
    this.leaveBottomThreshold = 130.0, 
  });

  bool processAngle(double primaryAngle) {
    bool repCompleted = false;

    switch (currentPhase) {
      case MovementPhase.top:
        if (primaryAngle < topThreshold - 10.0) {
          currentPhase = MovementPhase.descending;
        }
        break;

      case MovementPhase.descending:
        if (primaryAngle <= enterBottomThreshold) {
          currentPhase = MovementPhase.bottom;
        }
        break;

      case MovementPhase.bottom:
        if (primaryAngle >= leaveBottomThreshold) {
          currentPhase = MovementPhase.ascending;
        }
        break;

      case MovementPhase.ascending:
        if (primaryAngle >= topThreshold) {
          reps++;
          currentPhase = MovementPhase.top;
          repCompleted = true;
        }
        break;
    }

    return repCompleted;
  }

  void reset() {
    reps = 0;
    currentPhase = MovementPhase.top;
  }
}