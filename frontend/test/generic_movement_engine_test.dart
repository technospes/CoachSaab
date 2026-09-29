import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/biomechanics/movement_engine.dart';
import 'package:ai_coach_app/biomechanics/metric_engine.dart';
import 'package:ai_coach_app/domain/exercise_definition.dart';

void main() {
  test('MovementEngine processes arbitrary state machines purely via configuration', () {
    final definition = MovementDefinition(
      initialState: 'idle',
      parameters: {},
      phases: [
        MovementPhaseDefinition(id: 'idle', transitions: [
          TransitionRule(targetPhase: 'flexing', metric: 'custom_val', condition: 'less_than', value: 140.0)
        ]),
        MovementPhaseDefinition(id: 'flexing', transitions: [
          TransitionRule(targetPhase: 'peak', metric: 'custom_val', condition: 'reversal_increase', value: 5.0)
        ]),
        MovementPhaseDefinition(id: 'peak', transitions: [
          TransitionRule(targetPhase: 'completed', metric: 'custom_val', condition: 'greater_than', value: 145.0)
        ]),
      ],
    );

    final engine = MovementEngine(definition);

    // Initial state
    expect(engine.currentPhase, 'idle');

    // Sequence simulation with required parameters for ExerciseMetrics
    expect(engine.process(ExerciseMetrics(jointAngles: {}, customMetrics: {'custom_val': 150.0}, timestampSeconds: 0.0, confidences: {})), 'idle');
    expect(engine.process(ExerciseMetrics(jointAngles: {}, customMetrics: {'custom_val': 130.0}, timestampSeconds: 0.1, confidences: {})), 'flexing');
    expect(engine.process(ExerciseMetrics(jointAngles: {}, customMetrics: {'custom_val': 120.0}, timestampSeconds: 0.2, confidences: {})), 'flexing'); // Deepest point
    expect(engine.process(ExerciseMetrics(jointAngles: {}, customMetrics: {'custom_val': 128.0}, timestampSeconds: 0.3, confidences: {})), 'peak'); // Reversal detected (+8)
    expect(engine.process(ExerciseMetrics(jointAngles: {}, customMetrics: {'custom_val': 150.0}, timestampSeconds: 0.4, confidences: {})), 'completed');
  });
}