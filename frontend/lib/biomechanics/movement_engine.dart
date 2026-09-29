import '../domain/exercise_definition.dart';
import 'metric_engine.dart'; 

class MovementEngine {
  final MovementDefinition definition;
  late String currentPhase;

  // ✅ Metric-specific extreme tracking (keyed by metric name)
  final Map<String, double> _metricExtremes = {};

  MovementEngine(this.definition) {
    currentPhase = definition.initialState;
  }

  String process(ExerciseMetrics metrics) {
    // Locate current phase definition from configuration
    final phaseDef = definition.phases.firstWhere(
      (p) => p.id == currentPhase,
      orElse: () => definition.phases.first,
    );

    // Evaluate configuration-driven transition rules
    for (var transition in phaseDef.transitions) {
      final metricVal = metrics.getMetric(transition.metric);
      if (metricVal == null) continue;

      if (_evaluateTransition(transition, metricVal)) {
        currentPhase = transition.targetPhase;
        _resetMemory();
        break;
      }
    }

    return currentPhase;
  }

  bool _evaluateTransition(TransitionRule transition, double currentVal) {
    final metricKey = transition.metric;

    switch (transition.condition) {
      case 'less_than':
        return currentVal < transition.value;
      
      case 'greater_than':
        return currentVal > transition.value;
      
      case 'reversal_increase':
        _metricExtremes.putIfAbsent(metricKey, () => currentVal);
        if (currentVal < _metricExtremes[metricKey]!) {
          _metricExtremes[metricKey] = currentVal;
        }
        return currentVal >= _metricExtremes[metricKey]! + transition.value;
      
      case 'reversal_decrease':
        _metricExtremes.putIfAbsent(metricKey, () => currentVal);
        if (currentVal > _metricExtremes[metricKey]!) {
          _metricExtremes[metricKey] = currentVal;
        }
        return currentVal <= _metricExtremes[metricKey]! - transition.value;
      
      default:
        return false;
    }
  }

  void _resetMemory() {
    _metricExtremes.clear();
  }

  void reset() {
    currentPhase = definition.initialState;
    _resetMemory();
  }
}