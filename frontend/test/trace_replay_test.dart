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
  test('Trace Replay: Agnostic BiomechanicsPipeline Strict Assertions', () async {
    final file = File('test/traces/squat_telemetry.json'); 
    final String jsonString = await file.readAsString();
    final List<dynamic> frames = jsonDecode(jsonString);

    final pipeline = BiomechanicsPipeline(goldenSquatDefinition);

    final keyMap = {
      'right_hip': 'rightHip', 
      'right_knee': 'rightKnee', 
      'right_ankle': 'rightAnkle',
      'left_hip': 'leftHip', 
      'left_knee': 'leftKnee', 
      'left_ankle': 'leftAnkle',
    };

    print("▶️ Starting Rigorous Pipeline Replay...\n");

    double? currentAttemptMinAngle;
    final List<AttemptResult> recordedAttempts = [];

    for (var frameData in frames) {
      double timeSec = frameData['frame_ms'] / 1000.0;
      
      final Map<String, UnifiedLandmark> rawLandmarks = {};
      frameData['landmarks'].forEach((key, val) {
        if (keyMap.containsKey(key)) {
          double absoluteX = val['x'] * 1080.0;
          double absoluteY = val['y'] * 1920.0;
          rawLandmarks[keyMap[key]!] = UnifiedLandmark(x: absoluteX, y: absoluteY, z: 0, confidence: 1.0);
        }
      });
      
      final fusedFrame = LandmarkFusion.fromSmoothedPose(rawLandmarks);
      final output = pipeline.process(fusedFrame, timeSec);
      final angle = output.primaryMetric;

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
        print("  deepest knee angle: ${currentAttemptMinAngle?.toStringAsFixed(1)}°");
        print("  worst zone: $worstZone");
        print("  score: ${attemptResult.qualityScore}\n");

        currentAttemptMinAngle = null; 
      }
    }

    // ✅ Strict Architectural Assertions
    expect(recordedAttempts.length, 12, reason: "Must detect exactly 12 attempts");
    
    int goodCount = recordedAttempts.where((a) => a.outcome == AttemptOutcome.good).length;
    int imperfectCount = recordedAttempts.where((a) => a.outcome == AttemptOutcome.imperfect).length;

    expect(goodCount, 8, reason: "Must have 8 good/acceptable reps");
    expect(imperfectCount, 4, reason: "Must have 4 imperfect/poor reps");

    print("✅ Rigorous Golden Assertions Passed Successfully!");
  });
}