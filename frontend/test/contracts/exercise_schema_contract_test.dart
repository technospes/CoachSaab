import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/domain/exercise_definition.dart';

void main() {
  test('Schema Contract: Valid v1 schema loads successfully', () {
    final validJson = {
      "schema_version": 1,
      "id": "test_exercise",
      "name": "Test Exercise",
      "required_landmarks": ["right_hip"],
      "required_metrics": ["knee_angle"],
      "primary_metric": "knee_angle",
      "movement": {
        "initial_state": "idle",
        "parameters": {},
        "phases": [
          {
            "id": "idle",
            "transitions": [
              {"target_phase": "active", "metric": "knee_angle", "condition": "less_than", "value": 100.0}
            ]
          },
          {"id": "active", "transitions": []}
        ]
      },
      "rules": [
        {
          "joint": "knee",
          "metric": "knee_angle",
          "phase": "active",
          "aggregation": "minimum",
          "weight": 1.0,
          "deviation_type": "bad_form",
          "persistence_ms": 0,
          "zones": [
            {"min": 0.0, "max": 90.0, "label": "good", "score": 100.0}
          ]
        }
      ]
    };

    final def = ExerciseDefinition.fromJson(validJson);
    expect(def.id, 'test_exercise');
    expect(def.schemaVersion, 1);
  });

  test('Schema Contract: Unsupported or missing schema_version throws', () {
    final invalidJson = {
      "schema_version": 2,
      "id": "test",
      "name": "Test",
      "movement": {"initial_state": "idle", "phases": []},
      "rules": []
    };
    expect(() => ExerciseDefinition.fromJson(invalidJson), throwsFormatException);
  });

  test('Schema Contract: Missing ID throws', () {
    final invalidJson = {
      "schema_version": 1,
      "name": "Test",
      "movement": {
        "initial_state": "idle",
        "phases": [{"id": "idle", "transitions": []}]
      },
      "rules": []
    };
    expect(() => ExerciseDefinition.fromJson(invalidJson), throwsFormatException);
  });

  test('Schema Contract: Missing movement block throws', () {
    final invalidJson = {
      "schema_version": 1,
      "id": "test",
      "name": "Test",
      "rules": []
    };
    expect(() => ExerciseDefinition.fromJson(invalidJson), throwsFormatException);
  });

  test('Schema Contract: Empty phases list throws', () {
    final invalidJson = {
      "schema_version": 1,
      "id": "test",
      "name": "Test",
      "movement": {"initial_state": "idle", "phases": []},
      "rules": []
    };
    expect(() => ExerciseDefinition.fromJson(invalidJson), throwsFormatException);
  });

  test('Schema Contract: Invalid initial_state referencing non-existent phase throws', () {
    final invalidJson = {
      "schema_version": 1,
      "id": "test",
      "name": "Test",
      "movement": {
        "initial_state": "non_existent",
        "phases": [{"id": "idle", "transitions": []}]
      },
      "rules": []
    };
    expect(() => ExerciseDefinition.fromJson(invalidJson), throwsFormatException);
  });

  test('Schema Contract: Transition targeting non-existent phase throws', () {
    final invalidJson = {
      "schema_version": 1,
      "id": "test",
      "name": "Test",
      "movement": {
        "initial_state": "idle",
        "phases": [
          {
            "id": "idle",
            "transitions": [
              {"target_phase": "ghost_phase", "metric": "knee_angle", "condition": "less_than", "value": 100.0}
            ]
          }
        ]
      },
      "rules": []
    };
    expect(() => ExerciseDefinition.fromJson(invalidJson), throwsFormatException);
  });

  test('Schema Contract: Negative rule weight throws', () {
    final invalidJson = {
      "schema_version": 1,
      "id": "test",
      "name": "Test",
      "movement": {
        "initial_state": "idle",
        "phases": [{"id": "idle", "transitions": []}]
      },
      "rules": [
        {
          "metric": "knee_angle",
          "phase": "idle",
          "weight": -0.5,
          "zones": [{"min": 0.0, "max": 90.0, "label": "good", "score": 100.0}]
        }
      ]
    };
    expect(() => ExerciseDefinition.fromJson(invalidJson), throwsFormatException);
  });

  test('Schema Contract: Malformed zone where min >= max throws', () {
    final invalidJson = {
      "schema_version": 1,
      "id": "test",
      "name": "Test",
      "movement": {
        "initial_state": "idle",
        "phases": [{"id": "idle", "transitions": []}]
      },
      "rules": [
        {
          "metric": "knee_angle",
          "phase": "idle",
          "weight": 1.0,
          "zones": [
            {"min": 100.0, "max": 50.0, "label": "bad_range", "score": 50.0}
          ]
        }
      ]
    };
    expect(() => ExerciseDefinition.fromJson(invalidJson), throwsFormatException);
  });
}