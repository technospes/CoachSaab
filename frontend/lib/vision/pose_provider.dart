import '../domain/unified_landmark.dart';

abstract class PoseProvider {
  Future<void> initialize(String modelPath);
  Future<UnifiedFrame?> processImage(dynamic inputImage, int timestampUs);
  void dispose();
}