import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'dart:async';

/// Wraps `HandLandmarkerPlugin` behind a start/stop lifecycle so it only
/// runs (and only pays its GPU/CPU inference cost) when the current
/// activity config actually needs hand-level tracking. Pose tracking in
/// CameraView is unaffected and keeps running at full rate regardless of
/// this controller's state.
///
/// IMPORTANT: this wraps `hand_landmarker: ^3.0.1`'s stream-based API
/// (`processFrame` fire-and-forget + `landmarkStream`). If your installed
/// version differs, the plugin's public method names may not match —
/// check `flutter pub deps` for the resolved version before wiring this in.
class HandTrackingController {
  HandLandmarkerPlugin? _plugin;
  bool _isActive = false;
  StreamSubscription? _handStreamSub;

  final ValueNotifier<List<Hand>> handsNotifier = ValueNotifier([]);

  bool get isActive => _isActive;

  /// Lazily creates the plugin the first time hand tracking is needed,
  /// then starts feeding it frames. Safe to call multiple times — a
  /// no-op if already active.
  void start({int numHands = 2, double minHandDetectionConfidence = 0.6}) {
    if (_isActive) return;

    _plugin ??= HandLandmarkerPlugin.create(
      numHands: numHands,
      minHandDetectionConfidence: minHandDetectionConfidence,
      delegate: HandLandmarkerDelegate.gpu,
    );

    _handStreamSub = _plugin!.landmarkStream.listen(
      (hands) {
        // Prevent modifying ValueNotifier after dispose
        if (_isActive) handsNotifier.value = hands;
      },
      onError: (Object e) {
        debugPrint('🚨 HAND LANDMARKER STREAM ERROR: $e');
      },
    );

    _isActive = true;
  }

  /// Stops feeding frames and clears the last result, but keeps the
  /// native plugin instance alive so re-`start()`ing later (e.g. the user
  /// switches from Squat to a hand-tracked yoga pose mid-session) doesn't
  /// pay full re-initialization cost. Call [dispose] to fully release it.
  void stop() {
    if (!_isActive) return;
    _isActive = false;
    _handStreamSub?.cancel();
    handsNotifier.value = [];
  }

  /// Feeds one camera frame to the native hand detector. No-op if not
  /// currently active — callers don't need to guard this themselves.
  void processFrame(CameraImage image, int sensorOrientation) {
    if (!_isActive || _plugin == null) return;
    try {
      _plugin!.processFrame(image, sensorOrientation);
    } catch (e) {
      debugPrint('🚨 HAND LANDMARKER processFrame ERROR: $e');
    }
  }

  void dispose() {
    _isActive = false;
    _handStreamSub?.cancel();
    _plugin?.dispose();
    _plugin = null;
    handsNotifier.dispose();
  }
}