import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
// ❌ REMOVED: google_mlkit_pose_detection.dart
import 'package:ai_coach_app/domain/unified_landmark.dart'; // 🚀 ADDED: To use UnifiedFrame
import 'package:ai_coach_app/tracking/live_biomechanics_controller.dart';
import 'package:ai_coach_app/tracking/session_config.dart';
import 'package:ai_coach_app/domain/movement_phase.dart';
import 'package:ai_coach_app/domain/exercise_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 🚀 REPLACED: Constructs a UnifiedFrame with String keys instead of an ML Kit Pose
  UnifiedFrame createFrameForElbowAngle(double angleDegrees) {
    final double rad = angleDegrees * (pi / 180.0);
    final double wristX = 100.0 + (100.0 * sin(rad));
    final double wristY = 200.0 - (100.0 * cos(rad)); 

    return UnifiedFrame(
      points: {
        'rightShoulder': UnifiedLandmark(x: 100, y: 100, confidence: 1.0),
        'rightElbow': UnifiedLandmark(x: 100, y: 200, confidence: 1.0),
        'rightWrist': UnifiedLandmark(x: wristX, y: wristY, confidence: 1.0),
        'rightHip': UnifiedLandmark(x: 100, y: 400, confidence: 1.0),
        
        'leftShoulder': UnifiedLandmark(x: 200, y: 100, confidence: 1.0),
        'leftElbow': UnifiedLandmark(x: 200, y: 200, confidence: 1.0),
        'leftWrist': UnifiedLandmark(x: 200.0 + (100.0 * sin(rad)), y: 200.0 - (100.0 * cos(rad)), confidence: 1.0),
        'leftHip': UnifiedLandmark(x: 200, y: 400, confidence: 1.0),
      }
    );
  }

  // 🚀 REPLACED: Feeds the engine using the new `processSmoothedFrame` pipeline
  void feedAngle(
    LiveBiomechanicsController controller,
    double angle,
    int frames,
    double Function() nextTime,
  ) {
    for (var i = 0; i < frames; i++) {
      final timestampSec = nextTime();
      final frame = createFrameForElbowAngle(angle);
      
      // 1. Smooth the frame (just like CameraView does)
      final smoothed = controller.smoothPose(frame, timestampSec);
      
      // 2. Feed it to the engine
      controller.processSmoothedFrame(
        smoothed,
        timestampSec,
        (timestampSec * 1000000).toInt(), // timestamp in microseconds
        const Size(720, 1280), // Fake image size for the test
        [], // Empty hands list
      );
    }
  }

  test('LiveBiomechanicsController navigates state machine accounting for smoothing', () async {
    final controller = LiveBiomechanicsController();
    
    // ✅ Clean load without dead code or null-aware fallbacks
    final exerciseDef = await ExerciseRepository().loadExercise('bicep_curl');
    
    controller.initialize(SessionConfig(
      sessionId: 'test_session',
      exercise: exerciseDef,
    ));
    
    expect(controller.isInitialized, isTrue);
    
    double currentTime = 0.0;
    double nextTime() {
      currentTime += 0.033;
      return currentTime;
    }

    feedAngle(controller, 170.0, 20, nextTime);
    expect(controller.currentPhase, MovementPhase.idle);

    feedAngle(controller, 120.0, 20, nextTime);
    expect(controller.currentPhase, MovementPhase.descending);

    feedAngle(controller, 30.0, 25, nextTime);
    feedAngle(controller, 45.0, 20, nextTime);
    expect(controller.currentPhase, MovementPhase.bottom);

    feedAngle(controller, 70.0, 20, nextTime);
    expect(controller.currentPhase, MovementPhase.ascending);

    feedAngle(controller, 150.0, 25, nextTime);
    
    expect(controller.completedReps, 1);
    expect(controller.lastAttemptResult, isNotNull);
  });
}