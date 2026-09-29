import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/biomechanics/metric_engine.dart';
import 'package:ai_coach_app/domain/unified_landmark.dart';
import 'package:ai_coach_app/domain/landmark_fusion.dart';

void main() {
  test('MetricEngine accurately computes elbow angles (90, 180)', () {
    final engine = MetricEngine();

    // 180° Straight Arm using production fusion factory
    final frame180 = LandmarkFusion.fromSmoothedPose({
      'rightShoulder': UnifiedLandmark(x: 0, y: 0, z: 0, confidence: 1.0),
      'rightElbow': UnifiedLandmark(x: 0, y: 100, z: 0, confidence: 1.0),
      'rightWrist': UnifiedLandmark(x: 0, y: 200, z: 0, confidence: 1.0),
    });
    // ✅ Include base triggers to guarantee engine calculation
    expect(engine.calculate(frame180, 0.0, ['elbow', 'right_elbow', 'elbow_angle']).getMetric('elbow_angle'), closeTo(180.0, 1.0));

    // 90° Flexed Arm
    final frame90 = LandmarkFusion.fromSmoothedPose({
      'rightShoulder': UnifiedLandmark(x: 0, y: 0, z: 0, confidence: 1.0),
      'rightElbow': UnifiedLandmark(x: 0, y: 100, z: 0, confidence: 1.0),
      'rightWrist': UnifiedLandmark(x: 100, y: 100, z: 0, confidence: 1.0),
    });
    expect(engine.calculate(frame90, 0.1, ['elbow', 'right_elbow', 'elbow_angle']).getMetric('elbow_angle'), closeTo(90.0, 1.0));
  });
}