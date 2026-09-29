import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import '../domain/landmark_fusion.dart';
import '../domain/exercise_definition.dart';
import '../domain/unified_landmark.dart';
import '../domain/pipeline_output.dart';
import '../domain/movement_phase.dart';
import '../domain/pose_smoother.dart';
import '../biomechanics/biomechanics_pipeline.dart';
import '../biomechanics/models/attempt_result.dart';
import 'session_tracker.dart';
import 'session_config.dart';
import '../feedback/coaching_manager.dart';
import '../feedback/coaching_event.dart';
import '../biomechanics/running_calibration.dart';
import '../biomechanics/cadence_detector.dart';


enum ActiveSide { left, right, none }

class LiveBiomechanicsController extends ChangeNotifier {
  final PoseSmoother _poseSmoother = PoseSmoother();
  final RunningCalibration _runningCalibration = RunningCalibration();
  final CadenceDetector _cadenceDetector = CadenceDetector();
  int currentCadenceSPM = 0;

  final Stopwatch _warmupStopwatch = Stopwatch();
  static const Duration _warmupDuration = Duration(seconds: 3);
  bool get isWarmedUp => _warmupStopwatch.elapsed >= _warmupDuration;

  final Stopwatch _sessionStopwatch = Stopwatch();
  
  BiomechanicsPipeline? _pipeline;
  ExerciseDefinition? definition;
  SessionConfig? sessionConfig; // 🚀 ADDED: Store the session context

  CoachingManager? coachingManager;

  bool isInitialized = false;
  bool _disposed = false;
  
  Map<String, UnifiedLandmark> latestSmoothedLandmarks = {};
  MovementPhase currentPhase = MovementPhase.idle;
  double? primaryMetric;
  int completedReps = 0;
  AttemptResult? lastAttemptResult;
  
  RunningCalibrationResult? currentCalibrationResult;
  int _frameCount = 0;

  final Stopwatch _validHoldAccumulator = Stopwatch();
  final Stopwatch _invalidDebounceTimer = Stopwatch();
  bool _isCurrentlyHolding = false;

  int _lastEmittedSecond = 0; // 🚀 ADDED: Track per-second hold ticks
  
  double get currentHoldSeconds => _validHoldAccumulator.elapsedMilliseconds / 1000.0;
  double targetHoldSeconds = 30.0; 

  SessionTracker? get sessionTracker {
    // Rep/Hold Mode
    if (_pipeline?.sessionTracker != null) return _pipeline!.sessionTracker;
    
    // 🚀 Continuous Mode
    if (definition?.trackingMode == 'continuous') {
      final mockTracker = SessionTracker();
      mockTracker.continuousTotalSteps = _cadenceDetector.totalSteps;
      mockTracker.continuousAverageCadence = _cadenceDetector.averageCadence;
      mockTracker.continuousDurationSeconds = _sessionStopwatch.elapsed.inSeconds;
      return mockTracker;
    }
    
    return null;
  }

  // 🚀 ACTIVE LIMB SELECTOR STATE
  ActiveSide _activeSide = ActiveSide.none; 
  int _sideLockFrames = 0; 
  int _gracePeriodFrames = 0; 

  void initialize(SessionConfig config) {
    if (_disposed) return;
    isInitialized = false;
    notifyListeners();

    sessionConfig = config; 
    definition = config.exercise;
    
    // 🚀 SYNC THE TARGET: Update the controller's internal limit
    if (config.targetDurationSeconds != null) {
      targetHoldSeconds = config.targetDurationSeconds!.toDouble();
    }
    
    debugPrint('[BIO] init reps=${config.targetReps} duration=${config.targetDurationSeconds} targetHoldSeconds=$targetHoldSeconds'); 

    if (definition != null && definition!.trackingMode != 'continuous') {
      _pipeline = BiomechanicsPipeline(definition!);
    }
    
    _sessionStopwatch.reset();
    _sessionStopwatch.start();
    _warmupStopwatch.reset();
    _warmupStopwatch.start();
    isInitialized = true;
    notifyListeners();
  }

  double _calculateDistance(UnifiedLandmark a, UnifiedLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  Map<String, UnifiedLandmark> smoothPose(UnifiedFrame frame, double timestamp) {
    return _poseSmoother.smooth(frame, timestamp);
  }

  // 1. Safe Scoring Function
  double _limbScore(UnifiedLandmark? shoulder, UnifiedLandmark? elbow, UnifiedLandmark? wrist) {
    if (shoulder == null || elbow == null || wrist == null) return 0.0;
    return (shoulder.confidence + elbow.confidence + wrist.confidence) / 3.0;
  }

  // 2. The Auto-Selector with Hysteresis and Rep-Locking
  void _updateActiveLimb(Map<String, UnifiedLandmark> landmarks) {
    if (definition?.id != 'bicep_curl') return;

    // LOCK: Do not switch arms while a rep is actively in progress
    if (currentPhase != MovementPhase.idle && currentPhase != MovementPhase.completed) {
      return; 
    }

    final leftScore = _limbScore(landmarks['leftShoulder'], landmarks['leftElbow'], landmarks['leftWrist']);
    final rightScore = _limbScore(landmarks['rightShoulder'], landmarks['rightElbow'], landmarks['rightWrist']);

    // HYSTERESIS: Require 15 frames of stability before evaluating a switch
    _sideLockFrames++;
    if (_sideLockFrames < 15) return;

    // Select the best arm, provided it meets a baseline minimum quality
    if (leftScore > rightScore + 0.15 && leftScore > 0.4) {
      if (_activeSide != ActiveSide.left) {
        _activeSide = ActiveSide.left;
        debugPrint("🔄 LIMB SELECTOR: Locked to LEFT arm (Score: ${leftScore.toStringAsFixed(2)})");
      }
      _sideLockFrames = 0;
    } else if (rightScore > leftScore + 0.15 && rightScore > 0.4) {
      if (_activeSide != ActiveSide.right) {
        _activeSide = ActiveSide.right;
        debugPrint("🔄 LIMB SELECTOR: Locked to RIGHT arm (Score: ${rightScore.toStringAsFixed(2)})");
      }
      _sideLockFrames = 0;
    }
  }

  void processSmoothedFrame(
    Map<String, UnifiedLandmark> smoothedLandmarks,
    double timestampSec,
    int timestampUs,
    Size imageSize,
    List<Hand> hands,
  ) {
    if (_disposed || !isInitialized) return;
    latestSmoothedLandmarks = smoothedLandmarks;

    // 🚀 Evaluate and dynamically lock the active limb
    _updateActiveLimb(smoothedLandmarks);

    if (definition?.trackingMode == 'hold') {
      _processHoldState(smoothedLandmarks);
    } else if (definition?.trackingMode == 'continuous') {
      _processContinuousState(smoothedLandmarks, timestampUs, imageSize);
    } else if (_pipeline != null) {
      
      // 🚀 SAFE INJECTION: Clone the map and inject 'active' keys 
      final Map<String, UnifiedLandmark> lateralityInjectedLandmarks = Map.from(smoothedLandmarks);
      
      if (definition?.id == 'bicep_curl' && _activeSide != ActiveSide.none) {
        final prefix = _activeSide == ActiveSide.left ? 'left' : 'right';
        
        final s = smoothedLandmarks['${prefix}Shoulder'];
        final e = smoothedLandmarks['${prefix}Elbow'];
        final w = smoothedLandmarks['${prefix}Wrist'];

        // Only inject if all required joints exist and pass candidate-quality threshold
        if (s != null && e != null && w != null && _limbScore(s, e, w) > 0.3) {
          lateralityInjectedLandmarks['activeShoulder'] = s;
          lateralityInjectedLandmarks['activeElbow'] = e;
          lateralityInjectedLandmarks['activeWrist'] = w;
          _gracePeriodFrames = 0; 
        } else {
          _gracePeriodFrames++;
          // If grace period exceeded, we stop injecting, natively starving the math engine
        }
      }

      final poseFrame = UnifiedFrame(points: lateralityInjectedLandmarks);
      final handFrame = hands.isNotEmpty ? LandmarkFusion.fromHands(hands) : UnifiedFrame.empty;
      final fusedFrame = LandmarkFusion.fuse(poseFrame, handFrame);

      final output = _pipeline!.process(fusedFrame, timestampSec);
      _updateState(output);
    }
    
    _frameCount++;
    // if (primaryMetric != null && definition?.trackingMode != 'continuous') {
    //   final prefix = _activeSide == ActiveSide.left ? 'left' : 'right';
    //   final shoulder = smoothedLandmarks['${prefix}Shoulder'];
    //   final elbow = smoothedLandmarks['${prefix}Elbow'];
    //   final wrist = smoothedLandmarks['${prefix}Wrist'];
      
    //   final sStr = shoulder != null ? "S(${shoulder.x.toStringAsFixed(1)}, ${shoulder.y.toStringAsFixed(1)})" : "S(null)";
    //   final eStr = elbow != null ? "E(${elbow.x.toStringAsFixed(1)}, ${elbow.y.toStringAsFixed(1)})" : "E(null)";
    //   final wStr = wrist != null ? "W(${wrist.x.toStringAsFixed(1)}, ${wrist.y.toStringAsFixed(1)})" : "W(null)";
      
    //   debugPrint(
    //     "Frame $_frameCount | Phase: ${currentPhase.name.toUpperCase()} | "
    //     "Angle: ${primaryMetric!.toStringAsFixed(1)}° "
    //     "($prefix) $sStr $eStr $wStr"
    //   );
    // }
  }

  void _processContinuousState(Map<String, UnifiedLandmark> landmarks, int timestampUs, Size imageSize) {
    if (definition == null) return;
    
    currentCalibrationResult = _runningCalibration.processFrame(
      landmarks: landmarks, 
      imageSize: imageSize,
      timestampUs: timestampUs,
    );

    if (currentCalibrationResult?.status == CalibrationStatus.ready) {
      final timestampSec = timestampUs / 1000000.0;
      
      // 🚀 PROCESS CADENCE
      currentCadenceSPM = _cadenceDetector.process(landmarks, timestampSec);

      // 🚀 LOG METRICS FOR VERIFICATION
      if (_frameCount % 15 == 0) {
        debugPrint('[RUN] cadence=$currentCadenceSPM '
                   'L.y=${landmarks['leftAnkle']?.y.toStringAsFixed(1) ?? "null"} '
                   'R.y=${landmarks['rightAnkle']?.y.toStringAsFixed(1) ?? "null"}');
      }
    } else {
      if (currentCalibrationResult?.reason != null && _frameCount % 10 == 0) {
         debugPrint("CALIBRATION: ${currentCalibrationResult!.reason}");
      }
    }
    notifyListeners();
  }

  void processFrame(UnifiedFrame? frame, List<Hand> hands, double timestampSec) {}

  bool _isExceptionalRep(AttemptResult result) {
    return result.qualityScore >= 95 && result.deviations.isEmpty;
  }

  void _updateState(PipelineOutput output) {
    if (_disposed) return;

    // Update phase/metric for UI feedback even during warm-up
    if (currentPhase != output.phase) currentPhase = output.phase;
    if (primaryMetric != output.primaryMetric) primaryMetric = output.primaryMetric;

    // 🚀 Warm-up gate: suppress rep counting/evaluation for the first 3 seconds
    if (!isWarmedUp) {
      notifyListeners();
      return;
    }

    if (output.attemptFinished && output.completedAttempt != null) {
      final result = output.completedAttempt!;
      lastAttemptResult = result;

      if (result.outcome != AttemptOutcome.incomplete) {
        completedReps++;

        if (coachingManager != null) {
          final activeExerciseId = definition?.id;
          if (activeExerciseId == null || activeExerciseId.isEmpty) return; 

          // 🚀 FIX: Session truth, not exercise truth
          final currentTarget = sessionConfig?.targetReps ?? 10;

          if (result.outcome == AttemptOutcome.good) {
            coachingManager!.processEvent(
              CoachingEvent(
                exerciseId: activeExerciseId,
                type: 'good_rep', 
                priority: CoachingPriority.encouragement,
                score: result.qualityScore.toDouble(),
                isExceptional: _isExceptionalRep(result),
                repNumber: completedReps,
                phase: currentPhase.name,
                repOutcome: RepOutcome.good,
                targetReps: currentTarget, // 🚀 INJECTED
              )
            );
          } else {
            if (result.deviations.isNotEmpty) {
              final worstError = result.deviations.reduce((a, b) => a.lowestScore < b.lowestScore ? a : b);
              coachingManager!.processEvent(
                CoachingEvent(
                  exerciseId: activeExerciseId,
                  type: worstError.type, 
                  priority: CoachingPriority.correction,
                  score: worstError.lowestScore,
                  repNumber: completedReps,
                  phase: currentPhase.name,
                  repOutcome: RepOutcome.imperfect,
                  targetReps: currentTarget, // 🚀 INJECTED
                )
              );
            }
          }
        }
      }
    }
    notifyListeners();
  }

  double _calcAngle(UnifiedLandmark a, UnifiedLandmark b, UnifiedLandmark c) {
    double radians = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
    double angle = (radians * 180.0 / pi).abs();
    if (angle > 180.0) angle = 360.0 - angle;
    return angle;
  }

  void _processHoldState(Map<String, UnifiedLandmark> landmarks) {
    if (definition == null) return;
    bool isPoseValid = false;

    if (definition!.id == 'tree_pose') {
      final lHip = landmarks['leftHip'];
      final lKnee = landmarks['leftKnee'];
      final lAnkle = landmarks['leftAnkle'];
      final rHip = landmarks['rightHip'];
      final rKnee = landmarks['rightKnee'];
      final rAnkle = landmarks['rightAnkle'];

      if (lHip != null && lKnee != null && lAnkle != null && rHip != null && rKnee != null && rAnkle != null) {
        double leftKneeAngle = _calcAngle(lHip, lKnee, lAnkle);
        double rightKneeAngle = _calcAngle(rHip, rKnee, rAnkle);

        bool isLeftStanding = (leftKneeAngle >= 160 && leftKneeAngle <= 180) && (rightKneeAngle >= 30 && rightKneeAngle <= 120);
        bool isRightStanding = (rightKneeAngle >= 160 && rightKneeAngle <= 180) && (leftKneeAngle >= 30 && leftKneeAngle <= 120);
        
        isPoseValid = isLeftStanding || isRightStanding;
      }
    } else {
      isPoseValid = true; 
    }

    if (isPoseValid) {
      _invalidDebounceTimer.reset(); 
      if (!_isCurrentlyHolding) {
        _isCurrentlyHolding = true;
        _validHoldAccumulator.start();
        coachingManager?.processEvent(CoachingEvent(
          exerciseId: definition!.id,
          type: 'form_recovered', 
          priority: CoachingPriority.encouragement
        ));
      }
      final currentSecond = _validHoldAccumulator.elapsed.inSeconds;
      if (currentSecond > _lastEmittedSecond) {
        _lastEmittedSecond = currentSecond;
        _emitHoldTickEvent(currentSecond);
      }
    } else {
      if (_isCurrentlyHolding) {
        _invalidDebounceTimer.start();
        if (_invalidDebounceTimer.elapsedMilliseconds > 500) {
          _isCurrentlyHolding = false;
          _validHoldAccumulator.stop();
          coachingManager?.processEvent(CoachingEvent(
            exerciseId: definition!.id,
            type: 'bent_standing_knee', 
            priority: CoachingPriority.correction
          ));
        }
      }
    }
    notifyListeners(); 
  }

  // 🚀 ADDED: Emitter for per-second hold ticks
  void _emitHoldTickEvent(int elapsedSeconds) {
    if (coachingManager == null || definition == null) return;
    
    coachingManager!.processEvent(CoachingEvent(
      exerciseId: definition!.id,
      type: 'hold_tick',
      priority: CoachingPriority.encouragement,
      repNumber: 0,
      elapsedSeconds: elapsedSeconds,
      targetDurationSeconds: sessionConfig?.targetDurationSeconds,
      phase: currentPhase.name,
      repOutcome: RepOutcome.good,
    ));
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionStopwatch.stop(); // 🚀 NEW
    _poseSmoother.reset();
    _pipeline?.reset();
    _runningCalibration.reset();
    super.dispose();
  }

  void reset() {
    if (_disposed) return;

    _sessionStopwatch.reset(); // 🚀 NEW
    _sessionStopwatch.start(); // 🚀 NEW
    _warmupStopwatch.reset();
    _warmupStopwatch.start();

    completedReps = 0;
    currentPhase = MovementPhase.idle;
    primaryMetric = null;
    lastAttemptResult = null;
    latestSmoothedLandmarks.clear();
    currentCalibrationResult = null; 
    
    _validHoldAccumulator.stop();
    _validHoldAccumulator.reset();
    _invalidDebounceTimer.stop();
    _invalidDebounceTimer.reset();
    _isCurrentlyHolding = false;
    _lastEmittedSecond = 0;
    _cadenceDetector.reset();
    currentCadenceSPM = 0;
    
    _poseSmoother.reset();
    _pipeline?.reset();
    _runningCalibration.reset(); 
    
    notifyListeners();
  }
}