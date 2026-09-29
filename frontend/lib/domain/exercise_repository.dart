import 'dart:convert';
import 'package:flutter/services.dart';
import 'exercise_definition.dart';

class ExerciseRepository {
  /// Loads an exercise definition asynchronously from local JSON assets with strict versioning.
  Future<ExerciseDefinition> loadExercise(String exerciseId) async {
    try {
      // ✅ Explicitly reference the asset path (Flutter bundles assets in tests via package context if needed, 
      // but standard rootBundle expects the exact path declared in pubspec.yaml)
      final String jsonString = await rootBundle.loadString('assets/exercises/$exerciseId.json');
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return ExerciseDefinition.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Failed to load exercise definition for "$exerciseId": $e');
    }
  }
}