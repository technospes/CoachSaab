import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/domain/exercise_repository.dart'; // ✅ Corrected package path
import 'package:ai_coach_app/biomechanics/biomechanics_pipeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ExerciseRepository loads and validates bicep_curl contract strictly', () async {
    final repository = ExerciseRepository();

    final definition = await repository.loadExercise('bicep_curl');

    expect(definition.id, 'bicep_curl');
    expect(definition.name, 'Standard Bicep Curl');
    expect(definition.primaryMetric, 'elbow_angle');
    expect(
      definition.requiredMetrics,
      contains('upper_arm_vertical_deviation'),
    );
    expect(definition.movement.phases, isNotEmpty);
    expect(definition.rules, isNotEmpty);

    final pipeline = BiomechanicsPipeline(definition);
    expect(pipeline, isNotNull);
  });
}