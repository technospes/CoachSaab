import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/biomechanics/metric_engine.dart';
import 'package:ai_coach_app/domain/unified_landmark.dart';
import 'package:ai_coach_app/domain/landmark_fusion.dart';

void main() {
  test('MetricEngine calculates upper_arm_vertical_deviation', () {
    final engine = MetricEngine();

    final frame = LandmarkFusion.fromSmoothedPose({
      'rightShoulder': UnifiedLandmark(x: 100, y: 100, z: 0, confidence: 1.0),
      'rightElbow': UnifiedLandmark(x: 100, y: 200, z: 0, confidence: 1.0),
    });

    final metrics = engine.calculate(frame, 0.0, ['upper_arm_vertical_deviation']);
    
    expect(metrics.getMetric('upper_arm_vertical_deviation'), closeTo(0.0, 0.1));
  });
}