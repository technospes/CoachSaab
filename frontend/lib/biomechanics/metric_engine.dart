import '../domain/unified_landmark.dart';
import '../domain/math_utils.dart';
import '../domain/joint_mapper.dart';
import '../domain/metric_smoother.dart';

class ExerciseMetrics {
  final double timestampSeconds;
  final Map<String, double> jointAngles;
  final Map<String, double> jointVelocities; 
  final Map<String, double> confidences;
  final Map<String, double> customMetrics;

  ExerciseMetrics({
    required this.timestampSeconds,
    required this.jointAngles,
    Map<String, double>? jointVelocities,
    required this.confidences,
    Map<String, double>? customMetrics,
  })  : jointVelocities = jointVelocities ?? {},
        customMetrics = customMetrics ?? {};

  double? getMetric(String id) {
    if (customMetrics.containsKey(id)) return customMetrics[id];
    if (jointAngles.containsKey(id)) return jointAngles[id];
    
    String baseId = id.replaceAll('_angle', '');
    
    if (jointAngles.containsKey(baseId)) return jointAngles[baseId];
    if (jointAngles.containsKey('${baseId}_angle')) return jointAngles['${baseId}_angle'];
    
    if (jointAngles.containsKey('right_$baseId')) return jointAngles['right_$baseId'];
    if (jointAngles.containsKey('left_$baseId')) return jointAngles['left_$baseId'];
    if (jointAngles.containsKey('right_${baseId}_angle')) return jointAngles['right_${baseId}_angle'];
    if (jointAngles.containsKey('left_${baseId}_angle')) return jointAngles['left_${baseId}_angle'];
    
    return null;
  }

  double? getAngle(String joint) => jointAngles[joint];
  double? getVelocity(String joint) => jointVelocities[joint];
  double? get primaryKneeAngle => jointAngles['right_knee'] ?? jointAngles['knee'];
}

class MetricEngine {
  ExerciseMetrics? _previousMetrics;
  
  final Map<String, MetricSmoother> _smoothers = {};

  ExerciseMetrics calculate(UnifiedFrame frame, double timestampSeconds, List<String> requiredAngles) {
    final Map<String, double> angles = {};
    final Map<String, double> velocities = {};
    final Map<String, double> confidences = {};

    if (frame.isEmpty) {
      return ExerciseMetrics(timestampSeconds: timestampSeconds, jointAngles: angles, confidences: confidences);
    }

    for (var joint in requiredAngles) {
      
      // ✅ Handle Segment Deviations (e.g., upper_arm_vertical_deviation)
      if (joint.contains('vertical_deviation')) {
        // 🚀 DECOUPLED: Use String Keys directly. Default to 'active' if available, otherwise check left/right.
        String shoulderKey = 'activeShoulder';
        String elbowKey = 'activeElbow';

        if (!frame.points.containsKey(shoulderKey)) {
          bool isLeft = joint.contains('left');
          shoulderKey = isLeft ? 'leftShoulder' : 'rightShoulder';
          elbowKey = isLeft ? 'leftElbow' : 'rightElbow';
        }

        final shoulder = frame.points[shoulderKey];
        final elbow = frame.points[elbowKey];

        if (shoulder == null || elbow == null) {
          confidences[joint] = 0.0;
          continue;
        }

        confidences[joint] = shoulder.confidence < elbow.confidence ? shoulder.confidence : elbow.confidence;
        if (confidences[joint]! < 0.6) continue;

        final rawDeviation = MathUtils.angleToVertical(shoulder.x, shoulder.y, elbow.x, elbow.y);
        
        _smoothers.putIfAbsent(joint, () => MetricSmoother(windowSize: 5));
        angles[joint] = _smoothers[joint]!.smooth(rawDeviation);
        
        velocities[joint] = 0.0;
        continue;
      }

      // --- Standard Joint Angle Logic ---
      UnifiedLandmark? pointA;
      UnifiedLandmark? pointB;
      UnifiedLandmark? pointC;

      // 🚀 DECOUPLED: Look for 'active' joints for elbow_angle
      if (joint == 'elbow_angle') {
        pointA = frame.points['activeShoulder'];
        pointB = frame.points['activeElbow'];
        pointC = frame.points['activeWrist'];
      } else if (joint == 'knee_angle') {
        // 🚀 Squat / lunge / deadlift support: explicit right-side keys.
        // Active-side injection for lower body isn't wired yet — use concrete
        // right-side landmarks that always exist in frame.points.
        pointA = frame.points['rightHip'];
        pointB = frame.points['rightKnee'];
        pointC = frame.points['rightAnkle'];
      } else {
        // Fallback for non-auto-laterality joints (like squat knees)
        final poseIndices = JointMapper.getIndicesForJoint(joint);
        if (poseIndices == null) continue;
        pointA = frame.points[JointMapper.poseKey(poseIndices[0])];
        pointB = frame.points[JointMapper.poseKey(poseIndices[1])];
        pointC = frame.points[JointMapper.poseKey(poseIndices[2])];
      }

      if (pointA == null || pointB == null || pointC == null) {
        confidences[joint] = 0.0;
        continue;
      }

      confidences[joint] = [pointA.confidence, pointB.confidence, pointC.confidence]
          .reduce((a, b) => a < b ? a : b);

      if (confidences[joint]! < 0.6) continue;

      final rawAngle = MathUtils.calculateAngle(
        pointA.x, pointA.y,
        pointB.x, pointB.y,
        pointC.x, pointC.y,
      );
      
      _smoothers.putIfAbsent(joint, () => MetricSmoother(windowSize: 1));
      final stableAngle = _smoothers[joint]!.smooth(rawAngle);
      
      angles[joint] = stableAngle;

      if (_previousMetrics != null && _previousMetrics!.jointAngles.containsKey(joint)) {
        final double prevAngle = _previousMetrics!.jointAngles[joint]!;
        final double dt = timestampSeconds - _previousMetrics!.timestampSeconds;
        if (dt > 0) {
          velocities[joint] = (stableAngle - prevAngle) / dt;
        }
      } else {
        velocities[joint] = 0.0;
      }
    } 

    final currentMetrics = ExerciseMetrics(
      timestampSeconds: timestampSeconds,
      jointAngles: angles,
      jointVelocities: velocities,
      confidences: confidences,
    );

    _previousMetrics = currentMetrics;
    return currentMetrics;
  }

  void reset() {
    _previousMetrics = null;
    for (var smoother in _smoothers.values) {
      smoother.reset();
    }
  }
}