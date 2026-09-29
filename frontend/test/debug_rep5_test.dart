// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/biomechanics/metric_engine.dart';
import 'package:ai_coach_app/domain/unified_landmark.dart';
import 'package:ai_coach_app/domain/landmark_fusion.dart';

void main() {
  test('DIAGNOSTIC: Trace Elbow Geometry for Bicep Curl', () async {
    final file = File('test/traces/bicep_curl_telemetry.json');
    final String jsonString = await file.readAsString();
    final List<dynamic> frames = jsonDecode(jsonString);

    final engine = MetricEngine();
    
    final keyMap = {
      'right_shoulder': 'rightShoulder',
      'right_elbow': 'rightElbow',
      'right_wrist': 'rightWrist',
    };

    print("🔍 RUNNING GEOMETRY DIAGNOSTIC...\n");

    for (int i = 0; i < frames.length; i++) {
      var frameData = frames[i];
      double timeSec = frameData['frame_ms'] / 1000.0;
      
      final Map<String, UnifiedLandmark> rawLandmarks = {};
      
      final rawShoulder = frameData['landmarks']['right_shoulder'];
      final rawElbow = frameData['landmarks']['right_elbow'];
      final rawWrist = frameData['landmarks']['right_wrist'];

      frameData['landmarks'].forEach((key, val) {
        if (keyMap.containsKey(key)) {
          // ⚠️ Scaling step that might be distorting the geometry
          double absoluteX = val['x'] * 1080.0;
          double absoluteY = val['y'] * 1920.0;
          rawLandmarks[keyMap[key]!] = UnifiedLandmark(
              x: absoluteX, 
              y: absoluteY, 
              z: 0, 
              confidence: val['c'].toDouble()
          );
        }
      });

      final fusedFrame = LandmarkFusion.fromSmoothedPose(rawLandmarks);
      
      // ✅ Explicitly target the right elbow to match our loaded coordinates
      final metrics = engine.calculate(fusedFrame, timeSec, ['right_elbow']);
      final angle = metrics.getMetric('right_elbow');

      // Print frames where the angle drops below 60 to catch Attempt 5
      if (angle != null && angle < 60.0) {
        print("Frame $i | Time: ${timeSec.toStringAsFixed(2)}s");
        print("  Raw (Normalized): S(${rawShoulder['x'].toStringAsFixed(2)}, ${rawShoulder['y'].toStringAsFixed(2)}) | E(${rawElbow['x'].toStringAsFixed(2)}, ${rawElbow['y'].toStringAsFixed(2)}) | W(${rawWrist['x'].toStringAsFixed(2)}, ${rawWrist['y'].toStringAsFixed(2)})");
        
        final scaledS = rawLandmarks['rightShoulder']!;
        final scaledE = rawLandmarks['rightElbow']!;
        final scaledW = rawLandmarks['rightWrist']!;
        
        print("  Scaled (1080x1920): S(${scaledS.x.toStringAsFixed(1)}, ${scaledS.y.toStringAsFixed(1)}) | E(${scaledE.x.toStringAsFixed(1)}, ${scaledE.y.toStringAsFixed(1)}) | W(${scaledW.x.toStringAsFixed(1)}, ${scaledW.y.toStringAsFixed(1)})");
        print("  Calculated Angle: ${angle.toStringAsFixed(2)}°");
        print("  Confidence: S(${scaledS.confidence.toStringAsFixed(2)}) E(${scaledE.confidence.toStringAsFixed(2)}) W(${scaledW.confidence.toStringAsFixed(2)})\n");
      }
    }
  });
}