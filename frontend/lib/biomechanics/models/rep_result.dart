class RepDeviation {
  final String type;
  final double maxSeverity;
  final double maxObservedValue;
  final String worstPhase;
  final double durationMs;

  RepDeviation({
    required this.type,
    required this.maxSeverity,
    required this.maxObservedValue,
    required this.worstPhase,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'severity': double.parse(maxSeverity.toStringAsFixed(1)),
    'observed_value': double.parse(maxObservedValue.toStringAsFixed(1)),
    'phase': worstPhase,
    'duration_ms': durationMs.round(),
  };
}

class RepResult {
  final int repNumber;
  final bool isValid;
  final int qualityScore;
  final double totalDurationMs;
  final Map<String, double> phaseDurationsMs;
  final List<RepDeviation> deviations;

  RepResult({
    required this.repNumber,
    required this.isValid,
    required this.qualityScore,
    required this.totalDurationMs,
    required this.phaseDurationsMs,
    required this.deviations,
  });

  Map<String, dynamic> toJson() => {
    'rep_number': repNumber,
    'is_valid': isValid,
    'quality_score': qualityScore,
    'duration_ms': totalDurationMs.round(),
    'phases_ms': phaseDurationsMs.map((k, v) => MapEntry(k, v.round())),
    'deviations': deviations.map((d) => d.toJson()).toList(),
  };
}