enum AttemptOutcome { good, imperfect, incomplete }

class RepDeviation {
  final String type;
  final String worstZone;
  final double lowestScore;
  final double worstObservedValue;
  final String worstPhase;
  final int durationMs;

  RepDeviation({
    required this.type,
    required this.worstZone,
    required this.lowestScore,
    required this.worstObservedValue,
    required this.worstPhase,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'worstZone': worstZone,
    'lowestScore': lowestScore,
    'worstObservedValue': worstObservedValue,
    'worstPhase': worstPhase,
    'durationMs': durationMs,
  };
}

class AttemptResult {
  final int attemptNumber;
  final AttemptOutcome outcome;
  final int qualityScore; // Matches int expected by session summary
  final int totalDurationMs; // Matches int conversion
  final Map<String, double> phaseDurationsMs;
  final List<RepDeviation> deviations;

  AttemptResult({
    required this.attemptNumber,
    required this.outcome,
    required this.qualityScore,
    required this.totalDurationMs,
    required this.phaseDurationsMs,
    required this.deviations,
  });

  Map<String, dynamic> toJson() => {
    'attemptNumber': attemptNumber,
    'outcome': outcome.name,
    'qualityScore': qualityScore,
    'totalDurationMs': totalDurationMs,
    'phaseDurationsMs': phaseDurationsMs,
    'deviations': deviations.map((d) => d.toJson()).toList(),
  };
}