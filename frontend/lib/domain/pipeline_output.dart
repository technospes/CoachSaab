import 'movement_phase.dart';
import '../biomechanics/models/attempt_result.dart';

class PipelineOutput {
  final MovementPhase phase;
  final double? primaryMetric;
  final bool attemptActive;
  final bool attemptFinished;
  final AttemptResult? completedAttempt;
  final List<String> activeSignals;

  const PipelineOutput({
    required this.phase,
    required this.primaryMetric,
    required this.attemptActive,
    required this.attemptFinished,
    required this.completedAttempt,
    required this.activeSignals,
  });
}