import '../biomechanics/models/attempt_result.dart';

class SessionTracker {
  // ✅ Single source of truth for all recorded attempts
  final List<AttemptResult> _attempts = [];
  final Map<String, int> _deviationTallies = {};
  final Stopwatch _stopwatch = Stopwatch()..start();

  List<AttemptResult> get attempts => _attempts;
  List<AttemptResult> get repResults => _attempts;

  int continuousTotalSteps = 0;
  int continuousAverageCadence = 0;
  int continuousDurationSeconds = 0;

  void recordAttempt(AttemptResult result) {
    addAttempt(result);
  }

  void addAttempt(AttemptResult result) {
    _attempts.add(result);
    for (var dev in result.deviations) {
      if (dev.lowestScore < 85.0) {
        _deviationTallies[dev.type] = (_deviationTallies[dev.type] ?? 0) + 1;
      }
    }
  }

  // ✅ Only count completed reps (good or imperfect)
  int get totalAttempts => _attempts.where((a) => a.outcome != AttemptOutcome.incomplete).length;
  
  int get goodAttempts => _attempts.where((a) => a.outcome == AttemptOutcome.good).length;
  int get goodReps => goodAttempts;
  
  int get imperfectAttempts => _attempts.where((a) => a.outcome == AttemptOutcome.imperfect).length;
  int get imperfectReps => imperfectAttempts;
  
  int get incompleteAttempts => _attempts.where((a) => a.outcome == AttemptOutcome.incomplete).length;

  double get formAccuracy {
    if (totalAttempts == 0) return 0.0;
    return (goodAttempts / totalAttempts) * 100.0;
  }
  
  int get durationSeconds => _stopwatch.elapsed.inSeconds;

  String get formattedDuration {
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int get formScore {
    final validAttempts = _attempts.where((r) => r.outcome != AttemptOutcome.incomplete);
    if (validAttempts.isEmpty) return 0;
    return (validAttempts.fold(0.0, (sum, r) => sum + r.qualityScore) / validAttempts.length).round();
  }

  String? get dominantDeviation => _deviationTallies.isEmpty ? null : _deviationTallies.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  Map<String, dynamic> get deviationTallies => _deviationTallies;

  void endSession() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
  }

  void reset() { 
    _stopwatch.reset(); 
    _stopwatch.start(); 
    _attempts.clear(); 
    _deviationTallies.clear(); 
  }
}