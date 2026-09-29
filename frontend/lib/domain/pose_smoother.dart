import '../domain/unified_landmark.dart';
import 'one_euro_filter.dart';

/// REAL-TIME POSE SMOOTHER - Used ONLY for biomechanics calculations
class PoseSmoother {
  final Map<String, OneEuroFilter> _filtersX = {};
  final Map<String, OneEuroFilter> _filtersY = {};
  final Map<String, OneEuroFilter> _filtersZ = {};
  
  final double minCutoff;
  final double beta;
  final double dCutoff;

  PoseSmoother({
    this.minCutoff = 0.005,
    this.beta = 0.20,
    this.dCutoff = 1.0,
  });

  factory PoseSmoother.biomechanics() => PoseSmoother(minCutoff: 0.005, beta: 0.20);
  factory PoseSmoother.visual() => PoseSmoother(minCutoff: 0.5, beta: 5.0);

  // 🚀 CHANGED: Now accepts UnifiedFrame and returns a Map keyed by String
  Map<String, UnifiedLandmark> smooth(UnifiedFrame rawFrame, double timestamp) {
    final smoothedPoints = <String, UnifiedLandmark>{};

    for (final entry in rawFrame.points.entries) {
      final key = entry.key;
      final landmark = entry.value;

      _filtersX.putIfAbsent(key, () => OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff));
      _filtersY.putIfAbsent(key, () => OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff));
      _filtersZ.putIfAbsent(key, () => OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff));

      final smoothedX = _filtersX[key]!.filter(landmark.x, timestamp);
      final smoothedY = _filtersY[key]!.filter(landmark.y, timestamp);
      final smoothedZ = landmark.z != null ? _filtersZ[key]!.filter(landmark.z!, timestamp) : null;

      smoothedPoints[key] = UnifiedLandmark(
        x: smoothedX,
        y: smoothedY,
        z: smoothedZ,
        confidence: landmark.confidence,
        worldX: landmark.worldX, // Pass through the new 3D coordinates untouched for now
        worldY: landmark.worldY,
        worldZ: landmark.worldZ,
      );
    }

    return smoothedPoints;
  }

  void reset() {
    _filtersX.clear();
    _filtersY.clear();
    _filtersZ.clear();
  }
}