import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/unified_landmark.dart';
import 'joint_mapper.dart'; // 🚀 Import your existing canonical mapper

class MediaPipePoseData {
  final UnifiedFrame frame;
  final Size imageSize;
  MediaPipePoseData(this.frame, this.imageSize);
}

class MediaPipePoseProvider {
  static const MethodChannel _methodChannel = MethodChannel('com.aicoach.mediapipe/commands');
  static const EventChannel _eventChannel = EventChannel('com.aicoach.mediapipe/stream');

  Stream<MediaPipePoseData>? _poseStream;

  Future<void> initialize(String modelAssetPath) async {
    await _methodChannel.invokeMethod('initialize', {'modelPath': modelAssetPath});
  }

  Future<int?> startNativeCamera({bool isFrontFacing = true}) async {
    final dynamic result = await _methodChannel.invokeMethod('startNativeCamera', {'isFrontFacing': isFrontFacing});
    
    if (result is int) {
      return result == -1 ? null : result;
    } else if (result is bool) {
      return null;
    }
    return null;
  }

  Future<void> stopNativeCamera() async {
    await _methodChannel.invokeMethod('stopNativeCamera');
  }

  Stream<MediaPipePoseData> get poseStream {
    _poseStream ??= _eventChannel.receiveBroadcastStream().map((dynamic event) {
      final String jsonString = event as String;
      final Map<String, dynamic> root = jsonDecode(jsonString);
      
      final double width = (root['width'] as num).toDouble();
      final double height = (root['height'] as num).toDouble();
      final List<dynamic> jsonList = root['landmarks'];
      
      final points = <String, UnifiedLandmark>{};
      
      for (int i = 0; i < jsonList.length; i++) {
        final point = jsonList[i];
        
        // 🚀 ROUTE THROUGH JOINT MAPPER: Connects MediaPipe index to canonical String keys
        final key = JointMapper.poseKey(i);
        
        points[key] = UnifiedLandmark(
          x: (point['x'] as num).toDouble(),
          y: (point['y'] as num).toDouble(),
          confidence: (point['c'] as num).toDouble(),
          worldX: point['wx'] != null ? (point['wx'] as num).toDouble() : null,
          worldY: point['wy'] != null ? (point['wy'] as num).toDouble() : null,
          worldZ: point['wz'] != null ? (point['wz'] as num).toDouble() : null,
        );
      }
      return MediaPipePoseData(UnifiedFrame(points: points), Size(width, height));
    });
    return _poseStream!;
  }
}