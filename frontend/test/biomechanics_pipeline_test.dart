import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/biomechanics/biomechanics_pipeline.dart';
import 'package:ai_coach_app/domain/default_exercises.dart';
import 'package:ai_coach_app/domain/unified_landmark.dart';
import 'package:ai_coach_app/domain/movement_phase.dart';

void main() {
  test('Biomechanics Pipeline Pipeline Initialization Test', () {
    final pipeline = BiomechanicsPipeline(goldenSquatDefinition);
    
    // Test a dummy frame evaluation
    final frame = UnifiedFrame(points: {});
    final output = pipeline.process(frame, 0.0);

    expect(output.phase, MovementPhase.idle);
  });
}