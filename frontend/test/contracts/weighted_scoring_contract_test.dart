import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/biomechanics/deviation_tracker.dart';
import 'package:ai_coach_app/biomechanics/rep_quality_engine.dart';
import 'package:ai_coach_app/biomechanics/models/attempt_result.dart';
import 'package:ai_coach_app/domain/movement_phase.dart'; // ✅ Imported proper phase path

void main() {
  test('Contract: Weighted scoring calculates exact mathematical outcome', () {
    final repQualityEngine = RepQualityEngine();

    final deviations = [
      ConfirmedDeviation(
        type: 'bad_angle',
        phase: 'bottom',
        lowestScore: 100.0,
        worstZoneLabel: 'excellent',
        worstObservedValue: 20.0,
        weight: 0.7,
        durationMs: 500,
      ),
      ConfirmedDeviation(
        type: 'bad_stability',
        phase: 'bottom',
        lowestScore: 0.0,
        worstZoneLabel: 'poor',
        worstObservedValue: 45.0,
        weight: 0.3,
        durationMs: 500,
      ),
    ];

    for (var dev in deviations) {
      repQualityEngine.accumulate(MovementPhase.bottom, [dev], 1.0);
    }

    AttemptResult result = repQualityEngine.finalizeAttempt(true, 2.0);

    expect(result.qualityScore, 70, reason: "Weighted score must be mathematically exact: (100*0.7 + 0*0.3) = 70");
    expect(result.outcome, AttemptOutcome.imperfect, reason: 'A poor zone deviation must downgrade the outcome');
  });
}