import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/biomechanics/phase_metric_accumulator.dart'; 

void main() {
  test('Contract: Production PhaseMetricAccumulator computes all strategies precisely', () {
    final accumulator = PhaseMetricAccumulator();

    accumulator.record('elbow_angle', 20.0);
    accumulator.record('elbow_angle', 30.0);
    accumulator.record('elbow_angle', 40.0);

    expect(accumulator.minimum('elbow_angle'), 20.0);
    expect(accumulator.maximum('elbow_angle'), 40.0);
    expect(accumulator.average('elbow_angle'), 30.0);
    expect(accumulator.latest('elbow_angle'), 40.0);

    expect(accumulator.getAggregatedValue('elbow_angle', 'minimum'), 20.0);
    expect(accumulator.getAggregatedValue('elbow_angle', 'maximum'), 40.0);
    expect(accumulator.getAggregatedValue('elbow_angle', 'average'), 30.0);
    expect(accumulator.getAggregatedValue('elbow_angle', 'latest'), 40.0);

    // ✅ Edge case: Nonexistent metric correctly returns null in production
    expect(accumulator.getAggregatedValue('nonexistent', 'minimum'), isNull);
  });
}