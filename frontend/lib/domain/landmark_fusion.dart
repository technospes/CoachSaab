import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import 'joint_mapper.dart';
import 'unified_landmark.dart';

/// Fuses the latest ML Kit Pose result and the latest MediaPipe Hand
/// result (if hand tracking is active for the current activity) into one
/// UnifiedFrame that RuleEngine can evaluate without knowing which
/// detector produced which point.
class LandmarkFusion {
  /// Builds a UnifiedFrame from a single ML Kit [Pose].
  /// Pass null when no pose was detected this frame.
  static UnifiedFrame fromPose(Pose? pose) {
    if (pose == null) return UnifiedFrame.empty;

    final points = <String, UnifiedLandmark>{};
    pose.landmarks.forEach((type, landmark) {
      final ul = UnifiedLandmark(
        x: landmark.x,
        y: landmark.y,
        z: landmark.z,
        confidence: landmark.likelihood,
      );
      
      // 1. New Architecture (MediaPipe/Running) expects 'leftShoulder'
      points[type.name] = ul; 
      
      // 2. Old Architecture (Rep Engine) expects 'pose.leftShoulder'
      points['pose.${type.name}'] = ul; 
    });
    
    return UnifiedFrame(points: points);
  }

  /// Builds a UnifiedFrame from the latest MediaPipe [hands] result.
  /// Pass an empty list when no hands were detected this frame, or when
  /// hand tracking isn't active for the current activity.
  ///
  /// NOTE: `hand_landmarker`'s `Landmark` model exposes no per-point
  /// confidence/visibility score — only x/y/z. We set `confidence: 1.0`
  /// for every hand point as a placeholder so UnifiedLandmark's shape
  /// stays uniform across sources. Any rule relying on hand-point
  /// confidence thresholds (the way pose rules use `likelihood`) will
  /// currently never filter out low-confidence hand points — the hand
  /// simply won't appear in `hands` at all if MediaPipe's own internal
  /// detection confidence (minHandDetectionConfidence) wasn't met.
  static UnifiedFrame fromHands(List<Hand> hands) {
    if (hands.isEmpty) return UnifiedFrame.empty;

    final points = <String, UnifiedLandmark>{};
    for (int handSlot = 0; handSlot < hands.length; handSlot++) {
      final landmarks = hands[handSlot].landmarks;
      for (int i = 0; i < landmarks.length; i++) {
        final l = landmarks[i];
        points[JointMapper.handKey(handSlot, i)] = UnifiedLandmark(
          x: l.x,
          y: l.y,
          z: l.z,
          confidence: 1.0,
        );
      }
    }
    return UnifiedFrame(points: points);
  }

  /// Builds a UnifiedFrame from an ALREADY-SMOOTHED landmark map, as
  /// produced by PoseSmoother.smooth(). Use this instead of fromPose()
  /// wherever jitter/noise matters for the consumer — RuleEngine's angle
  /// math in particular. fromPose() is kept for callers that explicitly
  /// want the raw, unfiltered detector output (e.g. a debug overlay
  /// comparing raw vs smoothed).
  // 🚀 Update signature to accept Map<String, UnifiedLandmark>
  static UnifiedFrame fromSmoothedPose(Map<String, UnifiedLandmark>? smoothedLandmarks) {
    if (smoothedLandmarks == null || smoothedLandmarks.isEmpty) {
      return UnifiedFrame.empty;
    }

    final points = <String, UnifiedLandmark>{};
    smoothedLandmarks.forEach((key, landmark) {
      points[key] = landmark;
    });
    return UnifiedFrame(points: points);
  }

  /// Combines a pose frame and a hand frame into one fused frame for this
  /// tick. Either input may be `UnifiedFrame.empty`.
  static UnifiedFrame fuse(UnifiedFrame poseFrame, UnifiedFrame handFrame) {
    return poseFrame.merge(handFrame);
  }
}