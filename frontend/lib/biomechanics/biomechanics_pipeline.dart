import '../domain/exercise_definition.dart';
import '../domain/unified_landmark.dart';
import '../domain/pipeline_output.dart';
import '../domain/movement_phase.dart'; // Can be kept or used for compatibility if needed
import 'metric_engine.dart';
import 'movement_engine.dart';
import 'attempt_tracker.dart';
import 'deviation_tracker.dart';
import 'rep_quality_engine.dart';
import 'form_evaluator.dart';
import 'phase_metric_accumulator.dart';
import '../tracking/session_tracker.dart';
import 'models/attempt_result.dart';

class BiomechanicsPipeline {
  final ExerciseDefinition definition;

  late final MetricEngine _metricEngine;
  late final MovementEngine _movementEngine;
  late final AttemptTracker _attemptTracker;
  late final DeviationTracker _deviationTracker;
  late final RepQualityEngine _repQualityEngine;
  late final SessionTracker sessionTracker;
  late final PhaseMetricAccumulator _metricAccumulator;

  String? _lastPhase;

  BiomechanicsPipeline(this.definition) {
    _metricEngine = MetricEngine();
    _movementEngine = MovementEngine(definition.movement);
    _attemptTracker = AttemptTracker();
    _deviationTracker = DeviationTracker();
    _repQualityEngine = RepQualityEngine();
    sessionTracker = SessionTracker();
    _metricAccumulator = PhaseMetricAccumulator();
  }

  PipelineOutput process(UnifiedFrame frame, double timestampSec) {
    // 1. Calculate metrics required by the exercise definition
    final metrics = _metricEngine.calculate(frame, timestampSec, definition.requiredMetrics);

    // 2. Determine movement phase dynamically (returns String)
    final currentPhaseStr = _movementEngine.process(metrics);

    // 3. Reset phase-local aggregation window on transition
    if (_lastPhase != currentPhaseStr) {
      _metricAccumulator.reset();
      _lastPhase = currentPhaseStr;
    }

    // 4. Track attempt lifecycle using string phase mapping
    final attemptState = _attemptTracker.processPhaseString(currentPhaseStr);

    // Map string phase to MovementPhase enum for downstream engines if required
    final phaseEnum = _parseEnum(currentPhaseStr);

    // 5. Evaluate rules if active
    if (attemptState.isActive) {
      final events = FormEvaluator.evaluate(metrics, phaseEnum, definition.rules, _metricAccumulator);
      final confirmed = _deviationTracker.processEvents(events, timestampSec);
      _repQualityEngine.accumulate(phaseEnum, confirmed, timestampSec);
    }

    // 6. Finalize completed/aborted attempt
    AttemptResult? completedAttempt;
    if (attemptState.justFinished) {
      completedAttempt = _repQualityEngine.finalizeAttempt(attemptState.reachedTop, timestampSec);
      sessionTracker.addAttempt(completedAttempt);
      
      // ✅ Auto-loop the generic state machine back to start for the next repetition
      _movementEngine.reset();
      _lastPhase = _movementEngine.currentPhase;
    }

    // 7. Expose public agnostic contract
    return PipelineOutput(
      phase: phaseEnum,
      primaryMetric: metrics.getMetric(definition.primaryMetric),
      attemptActive: attemptState.isActive,
      attemptFinished: attemptState.justFinished,
      completedAttempt: completedAttempt,
      activeSignals: const [],
    );
  }

  MovementPhase _parseEnum(String phaseStr) {
    switch (phaseStr.toLowerCase()) {
      case 'descending':
      case 'flexing':
        return MovementPhase.descending;
      case 'bottom':
      case 'peak':
        return MovementPhase.bottom;
      case 'ascending':
      case 'extending':
        return MovementPhase.ascending;
      case 'completed':
        return MovementPhase.completed;
      case 'aborted':
        return MovementPhase.aborted;
      default:
        return MovementPhase.idle;
    }
  }

  void reset() {
    _metricEngine.reset();
    _movementEngine.reset();
    _attemptTracker.reset();
    _deviationTracker.reset();
    sessionTracker.reset();
    _metricAccumulator.reset();
    _lastPhase = null;
  }
}