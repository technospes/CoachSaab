// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/biomechanics/biomechanics_pipeline.dart';
import 'package:ai_coach_app/domain/unified_landmark.dart';
import 'package:ai_coach_app/domain/landmark_fusion.dart';
import 'package:ai_coach_app/domain/default_exercises.dart';
import 'package:ai_coach_app/domain/exercise_repository.dart';
import 'package:ai_coach_app/domain/exercise_definition.dart'; // ✅ Explicitly import exercise definition
import 'package:ai_coach_app/biomechanics/models/attempt_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, String> getLandmarkKeyMap(String exerciseId) {
    if (exerciseId == 'bicep_curl') {
      return {
        'right_shoulder': 'rightShoulder', 
        'right_elbow': 'rightElbow', 
        'right_wrist': 'rightWrist',
        'right_hip': 'rightHip', 
        'left_shoulder': 'leftShoulder', 
        'left_elbow': 'leftElbow', 
        'left_wrist': 'leftWrist',
        'left_hip': 'leftHip',
      };
    } else {
      return {
        'right_hip': 'rightHip',
        'right_knee': 'rightKnee',
        'right_ankle': 'rightAnkle',
        'left_hip': 'leftHip',
        'left_knee': 'leftKnee',
        'left_ankle': 'leftAnkle',
      };
    }
  }

  Future<List<AttemptResult>> runPipelineWithDefinition({
    required ExerciseDefinition definition,
    required String tracePath,
    required String exerciseId,
  }) async {
    final file = File(tracePath);
    expect(
      await file.exists(),
      isTrue,
      reason: 'Trace file mandatory for equivalence testing not found: $tracePath',
    );
    
    final String jsonString = await file.readAsString();
    final List<dynamic> frames = jsonDecode(jsonString);
    final keyMap = getLandmarkKeyMap(exerciseId);

    final pipeline = BiomechanicsPipeline(definition);
    final List<AttemptResult> attempts = [];

    for (var frameData in frames) {
      double timeSec = frameData['frame_ms'] / 1000.0;
      final Map<String, UnifiedLandmark> rawLandmarks = {};
      
      frameData['landmarks'].forEach((key, val) {
        if (keyMap.containsKey(key)) {
          rawLandmarks[keyMap[key]!] = UnifiedLandmark(
            x: val['x'].toDouble(), 
            y: val['y'].toDouble(), 
            z: (val['z'] ?? 0.0).toDouble(), 
            confidence: val['c'].toDouble()
          );
        }
      });

      final output = pipeline.process(LandmarkFusion.fromSmoothedPose(rawLandmarks), timeSec);
      if (output.attemptFinished && output.completedAttempt != null) {
        attempts.add(output.completedAttempt!);
      }
    }
    return attempts;
  }

  test('Full Behavioral Equivalence: Bicep Curl (Dart vs JSON)', () async {
    final repository = ExerciseRepository();
    final jsonDefinition = await repository.loadExercise('bicep_curl');

    final dartAttempts = await runPipelineWithDefinition(
      definition: goldenBicepCurlDefinition,
      tracePath: 'test/traces/bicep_curl_telemetry.json',
      exerciseId: 'bicep_curl',
    );

    final jsonAttempts = await runPipelineWithDefinition(
      definition: jsonDefinition,
      tracePath: 'test/traces/bicep_curl_telemetry.json',
      exerciseId: 'bicep_curl',
    );

    expect(jsonAttempts.length, dartAttempts.length);

    for (int i = 0; i < dartAttempts.length; i++) {
      final dartAttempt = dartAttempts[i];
      final jsonAttempt = jsonAttempts[i];

      expect(jsonAttempt.qualityScore, dartAttempt.qualityScore, 
          reason: "Score mismatch at attempt $i");
      expect(jsonAttempt.outcome, dartAttempt.outcome, 
          reason: "AttemptOutcome mismatch at attempt $i");
      expect(jsonAttempt.attemptNumber, dartAttempt.attemptNumber, 
          reason: "Attempt number mismatch at attempt $i");
      expect(jsonAttempt.deviations.length, dartAttempt.deviations.length, 
          reason: "Deviation count mismatch at attempt $i");

      // ✅ Safe deep comparison based on standard deviation properties (type & score)
      for (int j = 0; j < dartAttempt.deviations.length; j++) {
        final dartDev = dartAttempt.deviations[j];
        final jsonDev = jsonAttempt.deviations[j];

        expect(jsonDev.type, dartDev.type, reason: "Deviation type mismatch at attempt $i, dev $j");
        expect(jsonDev.lowestScore, dartDev.lowestScore, reason: "Deviation lowestScore mismatch at attempt $i, dev $j");
        expect(jsonDev.worstObservedValue, dartDev.worstObservedValue, reason: "Deviation worstObservedValue mismatch at attempt $i, dev $j");
      }
    }

    print("✅ Bicep Curl Full Behavioral & Deviation Equivalence Verified across ${dartAttempts.length} attempts!");
  });

  test('Full Behavioral Equivalence: Squat (Dart vs JSON)', () async {
    final repository = ExerciseRepository();
    final jsonDefinition = await repository.loadExercise('squat');

    final dartAttempts = await runPipelineWithDefinition(
      definition: goldenSquatDefinition,
      tracePath: 'test/traces/squat_telemetry.json',
      exerciseId: 'squat',
    );

    final jsonAttempts = await runPipelineWithDefinition(
      definition: jsonDefinition,
      tracePath: 'test/traces/squat_telemetry.json',
      exerciseId: 'squat',
    );

    expect(jsonAttempts.length, dartAttempts.length);

    for (int i = 0; i < dartAttempts.length; i++) {
      final dartAttempt = dartAttempts[i];
      final jsonAttempt = jsonAttempts[i];

      expect(jsonAttempt.qualityScore, dartAttempt.qualityScore, 
          reason: "Squat score mismatch at attempt $i");
      expect(jsonAttempt.outcome, dartAttempt.outcome, 
          reason: "Squat outcome mismatch at attempt $i");
      expect(jsonAttempt.attemptNumber, dartAttempt.attemptNumber, 
          reason: "Squat attempt number mismatch at attempt $i");
      expect(jsonAttempt.deviations.length, dartAttempt.deviations.length, 
          reason: "Squat deviation count mismatch at attempt $i");

      for (int j = 0; j < dartAttempt.deviations.length; j++) {
        final dartDev = dartAttempt.deviations[j];
        final jsonDev = jsonAttempt.deviations[j];

        expect(jsonDev.type, dartDev.type);
        expect(jsonDev.lowestScore, dartDev.lowestScore);
        expect(jsonDev.worstObservedValue, dartDev.worstObservedValue);
      }
    }

    print("✅ Squat Full Behavioral & Deviation Equivalence Verified across ${dartAttempts.length} attempts!");
  });
}