import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; 
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'; // Kept ONLY for InputImageRotation enum
import 'package:hand_landmarker/hand_landmarker.dart';

import '../domain/movement_phase.dart';
import '../tracking/session_config.dart';
import '../tracking/live_biomechanics_controller.dart';
import '../screens/session_summary_screen.dart';
import '../feedback/tts_controller.dart';
import 'hand_tracking_controller.dart';
import '../feedback/tts_queue.dart';
import '../feedback/coaching_library.dart';
import '../feedback/coaching_manager.dart';
import '../feedback/coaching_event.dart';
import '../feedback/coaching_cue.dart';
import '../domain/pose_smoother.dart';
import '../domain/unified_landmark.dart';
import 'smoothed_pose_painter.dart';
import '../biomechanics/running_calibration.dart';
import '../vision/mediapipe_pose_provider.dart';

class CameraView extends StatefulWidget {
  final String activityName;
  final SessionConfig sessionConfig;

  const CameraView({
    super.key,
    required this.activityName,
    required this.sessionConfig,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  static const Color _accentColor = Color(0xFF2DD4CF);
  int? _nativeTextureId;
  final MediaPipePoseProvider _mpProvider = MediaPipePoseProvider();
  
  final HandTrackingController _handController = HandTrackingController();
  final LiveBiomechanicsController _biomechanicsController = LiveBiomechanicsController();

  bool _hasAnnouncedWarmup = false;
  
  bool _isDisposing = false;
  bool _isSwitchingCamera = false;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.back; 

  String _currentFeedback = "Warming up native engine...";
  Color _feedbackColor = Colors.orange;

  Size _imageSize = const Size(1080, 1440);
  final InputImageRotation _imageRotation = InputImageRotation.rotation0deg;
  
  final PoseSmoother _visualSmoother = PoseSmoother.visual();
  
  // 🚀 DECOUPLED: ValueNotifier now uses canonical String keys
  final ValueNotifier<Map<String, UnifiedLandmark>> _visualLandmarksNotifier = ValueNotifier({});

  final Stopwatch _sessionClock = Stopwatch();
  final TtsController _ttsController = TtsController();
  
  late final TtsQueue _ttsQueue;
  late final CoachingLibrary _coachingLibrary;
  late final CoachingManager _coachingManager;
  
  bool _hasGreetedUser = false;
  bool _isPoseLost = false;
  MovementPhase _lastSpokenPhase = MovementPhase.idle;

  @override
  void initState() {
    super.initState();
    
    _ttsQueue = TtsQueue(_ttsController);
    _coachingLibrary = CoachingLibrary();
    _coachingManager = CoachingManager(_ttsQueue, _coachingLibrary);
    
    _coachingLibrary.loadLibrary().then((_) {
      _biomechanicsController.coachingManager = _coachingManager;
    });

    _biomechanicsController.addListener(_onControllerUpdated);
    _initPipelineAndCamera();
  }
  
  Future<void> _initPipelineAndCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    _biomechanicsController.initialize(widget.sessionConfig);
    _sessionClock.start();
    
    await _mpProvider.initialize('assets/models/pose_landmarker_full.task');
    
    final textureId = await _mpProvider.startNativeCamera(
      isFrontFacing: _cameraLensDirection == CameraLensDirection.front
    );

    if (mounted) {
      setState(() {
        _nativeTextureId = textureId;
      });
    }

    _mpProvider.poseStream.listen((data) {
      if (!mounted || _isDisposing) return;
      _imageSize = data.imageSize; 
      _handleUnifiedFrame(data.frame);
    });
  }

  void _handleUnifiedFrame(UnifiedFrame frame) {
    if (frame.isEmpty) {
      if (mounted && !_isDisposing) {
        if (!_isPoseLost) {
          _isPoseLost = true;
          _ttsQueue.enqueue(CoachingCue(id: 'pose_lost', text: "Please step back into frame.", priority: CoachingPriority.critical, exerciseId: widget.sessionConfig.exercise.id));
        }
        setState(() {
          _updateFeedbackUI("Step into frame", Colors.orange);
        });
      }
      return;
    }

    _isPoseLost = false;

    // // 🚀 DIAGNOSTIC BOUNDARY CHECKS
    // debugPrint(
    //   'CANONICAL ELBOWS: '
    //   'L=${JointMapper.poseKey(13)} '
    //   'R=${JointMapper.poseKey(14)}'
    // );
    // debugPrint(
    //   'FRAME LOOKUP: '
    //   'L=${frame.points[JointMapper.poseKey(13)]?.confidence} '
    //   'R=${frame.points[JointMapper.poseKey(14)]?.confidence}'
    // );

    if (!_hasGreetedUser) {
      _hasGreetedUser = true;
      _ttsQueue.enqueue(CoachingCue(id: 'greeting', text: "I can see you. Let's begin.", priority: CoachingPriority.transition, exerciseId: widget.sessionConfig.exercise.id));
      
      if (mounted) {
        setState(() {
           _updateFeedbackUI("Tracking Active", Colors.green);
        });
      }
    }

    final int frameTimestampUs = _sessionClock.elapsedMicroseconds;
    final double timestampSec = frameTimestampUs / 1000000.0;
        
    final visualLandmarks = _visualSmoother.smooth(frame, timestampSec);
    _visualLandmarksNotifier.value = visualLandmarks;
        
    final List<Hand> hands = []; 
        
    // 🚀 Feed the fully decoupled String-based map into the engine
    _biomechanicsController.processSmoothedFrame(
        _biomechanicsController.smoothPose(frame, timestampSec), 
        timestampSec, 
        frameTimestampUs, 
        _imageSize, 
        hands
    );

    if (mounted) {
       setState(() {}); 
    }
  }

  void _onControllerUpdated() {
    if (!mounted || _isDisposing) return;

    // 🚀 Warm-up: announce "go" once
    if (!_hasAnnouncedWarmup && _biomechanicsController.isWarmedUp) {
      _hasAnnouncedWarmup = true;
      _ttsQueue.enqueue(CoachingCue(
        id: 'warmup_complete',
        text: "Alright, let's go.",
        priority: CoachingPriority.transition,
        exerciseId: widget.sessionConfig.exercise.id,
      ));
    }

    // 🚀 Warm-up: show "Calibrating..." and skip the rest of the UI updates
    if (!_biomechanicsController.isWarmedUp) {
      _updateFeedbackUI("Calibrating…", Colors.blue);
      setState(() {});
      return;
    }
    
    final config = widget.sessionConfig.exercise;

    if (config.trackingMode == 'continuous') {
      final calResult = _biomechanicsController.currentCalibrationResult;
      if (calResult != null && calResult.reason != null) {
        final color = calResult.status == CalibrationStatus.ready ? Colors.green : Colors.blue;
        _updateFeedbackUI(calResult.reason!, color);
      }
    } else if (config.trackingMode == 'hold') {
      if (_biomechanicsController.currentHoldSeconds >= _biomechanicsController.targetHoldSeconds) {
         _ttsQueue.enqueue(CoachingCue(id: 'done', text: "Target reached! Great job.", priority: CoachingPriority.critical, exerciseId: widget.sessionConfig.exercise.id));
         _safeExit();
         return;
      }
    } else {
      final currentPhase = _biomechanicsController.currentPhase;
      if (currentPhase != _lastSpokenPhase) {
        _lastSpokenPhase = currentPhase;
        if (currentPhase == MovementPhase.bottom) {
          _updateFeedbackUI("Hold...", Colors.blue);
        } else if (currentPhase == MovementPhase.ascending || currentPhase == MovementPhase.descending) {
          _updateFeedbackUI("Looking Good", Colors.green);
        }
      }
    }
    setState(() {});
  }

  void _updateFeedbackUI(String newFeedback, Color newColor) {
    if (_currentFeedback != newFeedback) {
      _currentFeedback = newFeedback;
      _feedbackColor = newColor;
    }
  }

  Future<void> _toggleSound() async {
    final newState = !_ttsController.isEnabled;
    await _ttsController.setEnabled(newState);
    setState(() {});
  }

  Future<void> _toggleCamera() async {
    if (_isSwitchingCamera) return;
    _isSwitchingCamera = true;

    await _mpProvider.stopNativeCamera();

    setState(() {
      _cameraLensDirection = _cameraLensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });

    _hasAnnouncedWarmup = false;
    _coachingManager.resetSession(); // 🚀 explicitly wipes LRU + error counts
    _biomechanicsController.reset(); // 🚀 keeps sessionConfig intact

    await _mpProvider.startNativeCamera(
      isFrontFacing: _cameraLensDirection == CameraLensDirection.front
    );
    
    _isSwitchingCamera = false;
  }

  Future<void> _safeExit() async {
    if (_isDisposing) return;
    _isDisposing = true;

    await _mpProvider.stopNativeCamera();

    // This now safely retrieves the Mock Tracker for running!
    final tracker = _biomechanicsController.sessionTracker;
    tracker?.endSession();

    if (!mounted) return;

    if (tracker != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SessionSummaryScreen(
            tracker: tracker,
            activityName: widget.activityName,
          ),
        ),
      );
    } else {
      Navigator.pop(context); // Fallback failsafe
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    _biomechanicsController.removeListener(_onControllerUpdated);
    _mpProvider.stopNativeCamera(); 

    _biomechanicsController.dispose();
    _handController.dispose();
    _ttsController.dispose();
    _sessionClock.stop();
    _visualLandmarksNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposing || !_biomechanicsController.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black, 
        body: Center(
          child: CircularProgressIndicator(color: _accentColor)
        )
      );
    }
    
    final int displayReps = _biomechanicsController.completedReps;
    final String displayPhase = _biomechanicsController.currentPhase.name.toUpperCase();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _safeExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _imageSize.width / _imageSize.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_nativeTextureId != null)
                      Texture(textureId: _nativeTextureId!),

                    ValueListenableBuilder<Map<String, UnifiedLandmark>>(
                      valueListenable: _visualLandmarksNotifier,
                      builder: (context, visualLandmarks, child) {
                        if (visualLandmarks.isEmpty) return const SizedBox.shrink();
                        
                        return CustomPaint(
                          painter: SmoothedPosePainter(
                            landmarks: visualLandmarks,
                            absoluteImageSize: _imageSize, 
                            rotation: _imageRotation,
                            cameraLensDirection: _cameraLensDirection,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            Positioned(
              top: 56, left: 16,
              child: GestureDetector(
                onTap: _safeExit,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
                ),
              ),
            ),

            Positioned(
              top: 56, left: 72, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    final mode = widget.sessionConfig.exercise.trackingMode;
                    String leftLabel = "REPS";
                    String leftValue = "$displayReps";
                    String rightLabel = "STAGE";
                    Widget rightValue = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(displayPhase == 'BOTTOM' ? 'Up' : 'Down', style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                        Icon(displayPhase == 'BOTTOM' ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.black87, size: 22),
                      ],
                    );

                    if (mode == 'hold') {
                      leftLabel = "HOLD TIME";
                      leftValue = "${_biomechanicsController.currentHoldSeconds.toStringAsFixed(1)}s";
                      rightLabel = "TARGET";
                      rightValue = Text("${_biomechanicsController.targetHoldSeconds.toStringAsFixed(0)}s", style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold));
                    } else if (mode == 'continuous') {
                      leftLabel = "ACTIVITY";
                      leftValue = "RUN";
                      rightLabel = "STATUS";
                      final isReady = _biomechanicsController.currentCalibrationResult?.status == CalibrationStatus.ready;
                      rightValue = Text(isReady ? "LOCKED" : "CALIBRATING", style: TextStyle(color: isReady ? Colors.green : Colors.orange, fontSize: 16, fontWeight: FontWeight.bold));
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(leftLabel, style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            Text(leftValue, style: const TextStyle(color: Colors.black87, fontSize: 32, fontWeight: FontWeight.w900, height: 1.1)),
                          ],
                        ),
                        Container(width: 1, height: 36, color: Colors.black12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(rightLabel, style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                            rightValue,
                          ],
                        ),
                      ],
                    );
                  }
                ),
              ),
            ),

            Positioned(
              bottom: 108, left: 16, right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 5, color: _feedbackColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipOval(
                                  child: Image.network(
                                    'https://api.dicebear.com/9.x/initials/png?seed=CS&backgroundColor=121212&textColor=2DD4CF',
                                    width: 42, height: 42, fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                                      radius: 21, backgroundColor: _accentColor,
                                      child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _currentFeedback,
                                    style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
                                  ),
                                ),
                                if (_ttsQueue.isSpeaking)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8, top: 4),
                                    child: Icon(Icons.graphic_eq_rounded, color: _accentColor, size: 20),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 28, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildGlassButton(
                    icon: _ttsController.isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    label: _ttsController.isEnabled ? 'Sound On' : 'Sound Off',
                    size: 52,
                    onTap: _toggleSound,
                  ),
                  const SizedBox(width: 22),
                  _buildGlassButton(
                    icon: Icons.center_focus_strong_rounded,
                    label: '',
                    size: 68,
                    filled: true,
                    onTap: () {},
                  ),
                  const SizedBox(width: 22),
                  _buildGlassButton(
                    icon: Icons.flip_camera_ios_rounded, 
                    label: 'Switch',
                    size: 52,
                    onTap: _toggleCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double size = 52,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? _accentColor : Colors.white.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Icon(icon, color: Colors.white, size: filled ? size * 0.44 : size * 0.42),
              ),
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
            ),
          ],
        ],
      ),
    );
  }
}