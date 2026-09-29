import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/domain/math_utils.dart';

void main() {
  test('MathUtils.angleToVertical computes correct deviation', () {
    // Perfectly vertical segment pointing straight down (X stays same, Y increases)
    double verticalAngle = MathUtils.angleToVertical(100.0, 100.0, 100.0, 200.0);
    expect(verticalAngle, closeTo(0.0, 0.1));

    // Segment tilted 90 degrees to the right (horizontal)
    double horizontalAngle = MathUtils.angleToVertical(100.0, 100.0, 200.0, 100.0);
    expect(horizontalAngle, closeTo(90.0, 0.1));
  });
}