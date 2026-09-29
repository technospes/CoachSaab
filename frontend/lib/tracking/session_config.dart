import '../domain/exercise_definition.dart';

class SessionConfig {
  final ExerciseDefinition exercise;
  final int? targetReps;             // For repetition mode
  final int? targetDurationSeconds;  // For hold + continuous modes
  final String? userId;
  final String? sessionId;

  SessionConfig({
    required this.exercise,
    this.targetReps,
    this.targetDurationSeconds,
    this.userId,
    this.sessionId,
  });

  bool get isRepMode => targetReps != null;
  bool get isHoldMode => targetDurationSeconds != null;
}