import '../domain/activity_rule_model.dart';
import '../domain/movement_phase.dart';
import 'metric_engine.dart';
import 'phase_metric_accumulator.dart';

class DeviationEvent {
  final String type;
  final String zoneLabel;
  final double observedValue;
  final double score;
  final double weight;
  final String phase;
  final int persistenceMs;
  final String aggregation;

  DeviationEvent({
    required this.type, required this.zoneLabel, required this.observedValue, 
    required this.score, required this.weight, required this.phase, required this.persistenceMs,required this.aggregation,
  });
}

class FormEvaluator {
  static List<DeviationEvent> evaluate(
    ExerciseMetrics metrics, 
    MovementPhase currentPhase, 
    List<ActivityRule> rules, [
    PhaseMetricAccumulator? accumulator,
  ]) {
    List<DeviationEvent> events = [];
    String phaseName = currentPhase.name.toLowerCase();

    // 🚀 OPTIMIZATION: Record metrics exactly ONCE per frame, before evaluating rules
    if (accumulator != null) {
      metrics.jointAngles.forEach((key, val) {
        accumulator.record(key, val);
        accumulator.record('${key}_angle', val);
      });
      metrics.customMetrics.forEach((key, val) {
        accumulator.record(key, val);
      });
    }

    // Now evaluate the rules
    for (var rule in rules) {
      if (rule.phase != phaseName) continue;

      double? observed;
      if (accumulator != null) {
        observed = accumulator.getAggregatedValue(rule.metric, rule.aggregation);
      }
      
      observed ??= metrics.getMetric(rule.metric);
      if (observed == null) continue;

      MetricZone? activeZone;
      for (var zone in rule.zones) {
        if (observed >= zone.min && observed < zone.max) {
          activeZone = zone;
          break;
        }
      }

      activeZone ??= rule.zones.last;

      events.add(DeviationEvent(
        type: rule.deviationType,
        zoneLabel: activeZone.label,
        observedValue: observed,
        score: activeZone.score,
        weight: rule.weight,
        phase: phaseName,
        persistenceMs: rule.persistenceMs,
        aggregation: rule.aggregation,
      ));
    }

    return events;
  }
}