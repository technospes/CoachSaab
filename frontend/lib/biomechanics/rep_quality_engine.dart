import '../domain/movement_phase.dart';
import 'deviation_tracker.dart';
import 'models/attempt_result.dart'; 
import 'package:flutter/foundation.dart';

class RepQualityEngine {
  int _attemptCount = 0;
  double? _attemptStartSec;
  double? _currentPhaseStartSec;
  MovementPhase _lastPhase = MovementPhase.idle;

  final Map<String, double> _phaseDurationsSec = {};
  final Map<String, ConfirmedDeviation> _accumulatedDeviations = {};

  void accumulate(MovementPhase currentPhase, List<ConfirmedDeviation> activeDeviations, double timestampSec) {
    if (_attemptStartSec == null) {
      _attemptStartSec = timestampSec;
      _currentPhaseStartSec = timestampSec;
    }

    if (currentPhase != _lastPhase && _currentPhaseStartSec != null) {
      double duration = timestampSec - _currentPhaseStartSec!;
      _phaseDurationsSec[_lastPhase.name] = (_phaseDurationsSec[_lastPhase.name] ?? 0.0) + duration;
      _currentPhaseStartSec = timestampSec;
    }
    _lastPhase = currentPhase;

    // 🚀 FIX: The tracker has already resolved aggregation. Trust its latest snapshot.
    for (var dev in activeDeviations) {
      _accumulatedDeviations[dev.type] = dev;
    }
  }

  AttemptResult finalizeAttempt(bool reachedTop, double timestampSec) {
    if (_currentPhaseStartSec != null) {
      double duration = timestampSec - _currentPhaseStartSec!;
      _phaseDurationsSec[_lastPhase.name] = (_phaseDurationsSec[_lastPhase.name] ?? 0.0) + duration;
    }

    _attemptCount++;
    
    final List<RepDeviation> serializableDeviations = _accumulatedDeviations.values.map((d) => RepDeviation(
      type: d.type, 
      worstZone: d.worstZoneLabel, 
      lowestScore: d.lowestScore, 
      worstObservedValue: d.worstObservedValue, 
      worstPhase: d.phase, 
      durationMs: d.durationMs.round(), // ✅ Explicitly converted double to int
    )).toList();

    final scoreInfo = _calculateScore(_accumulatedDeviations.values.toList(), reachedTop);

    final result = AttemptResult(
      attemptNumber: _attemptCount,
      outcome: scoreInfo.outcome,
      qualityScore: scoreInfo.score,
      totalDurationMs: ((timestampSec - (_attemptStartSec ?? timestampSec)) * 1000).round(), // ✅ Explicitly converted double to int
      phaseDurationsMs: _phaseDurationsSec.map((k, v) => MapEntry(k, v * 1000)),
      deviations: serializableDeviations,
    );

    _attemptStartSec = null;
    _currentPhaseStartSec = null;
    _phaseDurationsSec.clear();
    _accumulatedDeviations.clear();
    return result;
  }

  _ScoreInfo _calculateScore(List<ConfirmedDeviation> deviations, bool reachedTop) {
    if (!reachedTop) return _ScoreInfo(score: 0, outcome: AttemptOutcome.incomplete);

    double totalWeightedScore = 0.0;
    double totalWeight = 0.0;
    
    AttemptOutcome finalOutcome = AttemptOutcome.good;

    // 🔍 TELEMETRY TRACE: Inspect every active deviation driving the score
    debugPrint("🔍 --- EVALUATING ATTEMPT DEVIATIONS (${deviations.length}) ---");
    for (var dev in deviations) {
      debugPrint(
        "   Type: ${dev.type} | "
        "Phase: ${dev.phase} | "
        "Worst Zone: ${dev.worstZoneLabel} | "
        "Lowest Score: ${dev.lowestScore} | "
        "Worst Value: ${dev.worstObservedValue.toStringAsFixed(1)} | "
        "Weight: ${dev.weight}"
      );

      totalWeightedScore += (dev.lowestScore * dev.weight);
      totalWeight += dev.weight;

      if (dev.worstZoneLabel == 'poor' || dev.worstZoneLabel == 'imperfect') {
        finalOutcome = AttemptOutcome.imperfect;
      }
    }

    int finalScore = 100;
    if (totalWeight > 0) {
      finalScore = (totalWeightedScore / totalWeight).clamp(0.0, 100.0).round();
    }
    debugPrint("🔍 --- RESULT: Score = $finalScore | Outcome = ${finalOutcome.name} ---");

    return _ScoreInfo(score: finalScore, outcome: finalOutcome);
  }
  void resetSession() {
    _attemptCount = 0;
    _lastPhase = MovementPhase.idle;
    _attemptStartSec = null;
    _phaseDurationsSec.clear();
    _accumulatedDeviations.clear();
  }
}

class _ScoreInfo {
  final int score;
  final AttemptOutcome outcome;
  _ScoreInfo({required this.score, required this.outcome});
}