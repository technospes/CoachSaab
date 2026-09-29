/// A single tracked point, regardless of which detector produced it
/// (ML Kit Pose or MediaPipe HandLandmarker). Normalized 0.0-1.0 x/y,
/// matching both detectors' native coordinate convention.
class UnifiedLandmark {
  final double x;
  final double y;
  final double? z; // Retain existing pseudo-Z if previously used
  final double confidence;

  // NEW: MediaPipe Metric 3D World Coordinates (in meters)
  final double? worldX;
  final double? worldY;
  final double? worldZ;

  const UnifiedLandmark({
    required this.x,
    required this.y,
    this.z,
    required this.confidence,
    this.worldX,
    this.worldY,
    this.worldZ,
  });
}

/// One frame's worth of tracked points, fused from however many detectors
/// ran this tick. Keyed by a stable string joint name (see JointMapper) —
/// NOT by enum type, since pose and hand landmarks use different enums
/// (PoseLandmarkType vs HandLandmarkType) that can't share a map key type.
class UnifiedFrame {
  const UnifiedFrame({required this.points, this.timestampUs}); // 🚀 ADDED timestampUs

  final Map<String, UnifiedLandmark> points;
  final int? timestampUs; // 🚀 ADDED property

  static const UnifiedFrame empty = UnifiedFrame(points: {});

  UnifiedLandmark? operator [](String jointKey) => points[jointKey];

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  UnifiedFrame merge(UnifiedFrame other) {
    return UnifiedFrame(
      points: {...points, ...other.points},
      timestampUs: timestampUs ?? other.timestampUs, // Keep timestamp
    );
  }
}