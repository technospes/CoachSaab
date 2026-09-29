// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/biomechanics/biomechanics_pipeline.dart';
import 'package:ai_coach_app/domain/unified_landmark.dart';
import 'package:ai_coach_app/domain/landmark_fusion.dart';
import 'package:ai_coach_app/domain/default_exercises.dart';
import 'package:ai_coach_app/biomechanics/models/attempt_result.dart';

void main() {
  test('Trace Replay: Agnostic Pipeline with Bicep Curl', () async {
    final file = File('test/traces/bicep_curl_telemetry.json'); 
    final String jsonString = await file.readAsString();
    final List<dynamic> frames = jsonDecode(jsonString);

    // ✅ Instantiate the EXACT same pipeline, just swapping the configuration
    final pipeline = BiomechanicsPipeline(goldenBicepCurlDefinition);

    final keyMap = {
      'right_shoulder': 'rightShoulder', 
      'right_elbow': 'rightElbow', 
      'right_wrist': 'rightWrist',
      'right_hip': 'rightHip', 
      'left_shoulder': 'leftShoulder', 
      'left_elbow': 'leftElbow', 
      'left_wrist': 'leftWrist',
      'left_hip': 'leftHip',
    };

    print("▶️ Starting Multi-Exercise Replay (Bicep Curl)...\n");

    double? currentAttemptMinAngle;
    final List<AttemptResult> recordedAttempts = [];
    
    // ✅ Track if the engine was still waiting for the rep to finish when the video ended
    bool wasActiveAtEnd = false;

    for (var frameData in frames) {
      double timeSec = frameData['frame_ms'] / 1000.0;
      
      final Map<String, UnifiedLandmark> rawLandmarks = {};
      frameData['landmarks'].forEach((key, val) {
        if (keyMap.containsKey(key)) {
          double absoluteX = val['x'] * 1080.0;
          double absoluteY = val['y'] * 1920.0;
          rawLandmarks[keyMap[key]!] = UnifiedLandmark(x: absoluteX, y: absoluteY, z: 0, confidence: val['c'].toDouble());
        }
      });
      
      final fusedFrame = LandmarkFusion.fromSmoothedPose(rawLandmarks);
      final output = pipeline.process(fusedFrame, timeSec);
      final angle = output.primaryMetric;

      // Update the final active state on every frame
      wasActiveAtEnd = output.attemptActive;

      if (output.attemptActive && angle != null) {
        if (currentAttemptMinAngle == null || angle < currentAttemptMinAngle) {
          currentAttemptMinAngle = angle;
        }
      }

      if (output.attemptFinished && output.completedAttempt != null) {
        final attemptResult = output.completedAttempt!;
        recordedAttempts.add(attemptResult);
        
        String worstZone = attemptResult.deviations.isNotEmpty 
            ? attemptResult.deviations.first.worstZone 
            : 'excellent';

        print("Attempt ${attemptResult.attemptNumber}");
        print("  tightest elbow angle: ${currentAttemptMinAngle?.toStringAsFixed(1)}°");
        print("  worst zone: $worstZone");
        print("  score: ${attemptResult.qualityScore}\n");

        currentAttemptMinAngle = null; 
      }
    }

    // ✅ Adjusted assertions for the real-world video cut-off
    expect(recordedAttempts.length, 5, reason: "Only 5 reps biomechanically completed the eccentric phase before the video ended");
    expect(wasActiveAtEnd, isTrue, reason: "The engine should still be actively tracking the 6th incomplete swing");
    
    int goodCount = recordedAttempts.where((a) => a.outcome == AttemptOutcome.good).length;
    int imperfectCount = recordedAttempts.where((a) => a.outcome == AttemptOutcome.imperfect || a.outcome == AttemptOutcome.incomplete).length;

    expect(goodCount, 3, reason: "Must have exactly 3 excellent/good reps");
    expect(imperfectCount, 2, reason: "Must have exactly 2 imperfect/poor reps completed");

    print("✅ Multi-Exercise Architecture Verified Successfully!");
  });
}