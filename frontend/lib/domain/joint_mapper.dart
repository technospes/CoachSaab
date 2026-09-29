import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// MediaPipe's standard 21-point hand landmark index ordering.
/// Source: https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker
/// The `hand_landmarker` package returns hands as a plain ordered
/// `List<Landmark>` (no enum), so joints are addressed by index here,
/// unlike pose joints which use ML Kit's `PoseLandmarkType` enum.
class HandLandmarkIndex {
  static const int wrist = 0;
  static const int thumbCmc = 1;
  static const int thumbMcp = 2;
  static const int thumbIp = 3;
  static const int thumbTip = 4;
  static const int indexMcp = 5;
  static const int indexPip = 6;
  static const int indexDip = 7;
  static const int indexTip = 8;
  static const int middleMcp = 9;
  static const int middlePip = 10;
  static const int middleDip = 11;
  static const int middleTip = 12;
  static const int ringMcp = 13;
  static const int ringPip = 14;
  static const int ringDip = 15;
  static const int ringTip = 16;
  static const int pinkyMcp = 17;
  static const int pinkyPip = 18;
  static const int pinkyDip = 19;
  static const int pinkyTip = 20;
}

class JointMapper {
  // === POSE JOINTS (ML Kit, unchanged from original) ===
  // [Point A, Vertex, Point C] — vertex is the middle element, matching
  // MathUtils.calculateAngle's (a, b, c) signature where b is the joint.
  static const Map<String, List<PoseLandmarkType>> mediapipeMappings = {
    'knee': [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    'left_knee': [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    'right_knee': [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],

    'activeKnee': [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    
    // ✅ Added exact mappings for elbows
    'elbow': [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    'left_elbow': [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    'right_elbow': [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
  };

  static List<PoseLandmarkType>? getIndicesForJoint(String joint) {
    // ✅ Strip '_angle' so a request for 'elbow_angle' successfully finds 'elbow'
    String normalized = joint.replaceAll('_angle', '');
    return mediapipeMappings[normalized] ?? mediapipeMappings[joint];
  }

  // === HAND JOINTS (MediaPipe HandLandmarker, index-based) ===
  // Same [Point A, Vertex, Point C] convention. Finger joint names are
  // prefixed so they never collide with pose joint keys once both are
  // fused into a UnifiedFrame (see landmark_fusion.dart).
  static const Map<String, List<int>> handJointMappings = {
    'index_finger': [HandLandmarkIndex.indexMcp, HandLandmarkIndex.indexPip, HandLandmarkIndex.indexTip],
    'thumb': [HandLandmarkIndex.thumbMcp, HandLandmarkIndex.thumbIp, HandLandmarkIndex.thumbTip],
    'middle_finger': [HandLandmarkIndex.middleMcp, HandLandmarkIndex.middlePip, HandLandmarkIndex.middleTip],
    'wrist_flex': [HandLandmarkIndex.middleMcp, HandLandmarkIndex.wrist, HandLandmarkIndex.indexMcp],
  };

  static List<int>? getIndicesForHandJoint(String joint) {
    return handJointMappings[joint];
  }

  // === UNIFIED KEY NAMESPACING ===
  // UnifiedFrame keys pose points as "pose.<PoseLandmarkType.name>" and
  // hand points as "hand.<handSlot>.<landmarkIndex>". RuleEngine and
  // LandmarkFusion both use these helpers so the key format only lives
  // in one place.
  //
  // NOTE: the `hand_landmarker` package's `Hand` model (v3.0.1) does not
  // expose a left/right handedness field — only an ordered `landmarks`
  // list per detected hand. So `handSlot` here is the hand's index within
  // the returned `List<Hand>` (0, 1, ...), NOT true left/right handedness.
  // For single-hand activities (numHands: 1) this is a non-issue. For
  // two-hand activities, slot order is not guaranteed stable frame-to-frame
  // — do not build rules that assume slot 0 is always the same physical
  // hand without adding your own tracking/handedness heuristic later.
  static String poseKey(PoseLandmarkType type) => 'pose.${type.name}';

  static String handKey(int handSlot, int landmarkIndex) =>
      'hand.$handSlot.$landmarkIndex';
}