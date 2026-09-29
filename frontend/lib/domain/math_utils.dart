import 'dart:math';

class MathUtils {
  /// Calculates the interior angle (in degrees) between three points.
  /// [bx, by] is the middle point (the vertex/joint).
  static double calculateAngle(
    double ax, double ay,
    double bx, double by,
    double cx, double cy,
  ) {
    double radians = atan2(cy - by, cx - bx) - atan2(ay - by, ax - bx);
    double angle = (radians * 180.0 / pi).abs();
    
    // We want the interior joint angle (always <= 180 degrees)
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }

  // ✅ ADD THIS NEW 3D METHOD HERE
  /// Calculates the interior 3D angle (in degrees) between three points.
  /// [bx, by, bz] is the middle point (the vertex/joint).
  static double calculateAngle3D(
    double ax, double ay, double az,
    double bx, double by, double bz,
    double cx, double cy, double cz,
  ) {
    // Vector BA (A - B)
    double baX = ax - bx;
    double baY = ay - by;
    double baZ = az - bz;

    // Vector BC (C - B)
    double bcX = cx - bx;
    double bcY = cy - by;
    double bcZ = cz - bz;

    // Dot product
    double dotProduct = (baX * bcX) + (baY * bcY) + (baZ * bcZ);
    
    // Magnitudes
    double magBA = sqrt((baX * baX) + (baY * baY) + (baZ * baZ));
    double magBC = sqrt((bcX * bcX) + (bcY * bcY) + (bcZ * bcZ));

    // Prevent division by zero if landmarks collapse completely
    if (magBA == 0.0 || magBC == 0.0) return 0.0;

    // Clamp the cosine value to prevent NaN errors from floating point imprecision
    double cosine = (dotProduct / (magBA * magBC)).clamp(-1.0, 1.0);
    
    // Convert radians to degrees
    return acos(cosine) * (180.0 / pi);
  }

  /// Calculates the acute angle (in degrees) between a vector (formed by points a -> b) 
  /// and a true vertical plumb line pointing downwards ([0, 1, 0] in screen coordinates).
  static double angleToVertical(double x1, double y1, double x2, double y2) {
    double vx = x2 - x1;
    double vy = y2 - y1;

    double ux = 0.0;
    double uy = 1.0;

    double dotProduct = (vx * ux) + (vy * uy);
    double magV = sqrt((vx * vx) + (vy * vy));
    double magU = 1.0;

    if (magV == 0) return 0.0;

    double cosine = (dotProduct / (magV * magU)).clamp(-1.0, 1.0);
    double angleRad = acos(cosine);
    
    return angleRad * (180.0 / pi);
  }
}