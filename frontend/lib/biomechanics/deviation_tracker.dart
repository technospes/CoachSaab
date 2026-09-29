import 'form_evaluator.dart';
import 'package:flutter/foundation.dart';

class ConfirmedDeviation {
  final String type;
  final String worstZoneLabel;
  final double lowestScore;
  final double worstObservedValue;
  final double weight;
  final String phase;
  final double durationMs;
  final String aggregation;

  ConfirmedDeviation({
    required this.type, required this.worstZoneLabel, required this.lowestScore,
    required this.worstObservedValue, required this.weight, required this.phase, required this.durationMs,required this.aggregation,
  });
}

class _DeviationState {
  final String type;
  final double firstDetectedAtSec;
  double lastDetectedAtSec;
  String worstZoneLabel;
  double lowestScore;
  double worstObservedValue;
  double weight;
  String phase;
  final int persistenceMs; 
  bool isConfirmed = false;
  final String aggregation;

  _DeviationState({
    required this.type, required this.firstDetectedAtSec, required this.lastDetectedAtSec,
    required this.worstZoneLabel, required this.lowestScore, required this.worstObservedValue,
    required this.weight, required this.phase, required this.persistenceMs,required this.aggregation,
  });
}

class DeviationTracker {
  final double resolutionThresholdSec = 0.150; 
  final Map<String, _DeviationState> _activeStates = {};

  List<ConfirmedDeviation> processEvents(List<DeviationEvent> frameEvents, double currentTimestampSec) {
    Set<String> currentEventTypes = {};
    
    for (var event in frameEvents) {
      currentEventTypes.add(event.type);
      
      if (_activeStates.containsKey(event.type)) {
        final state = _activeStates[event.type]!;
        state.lastDetectedAtSec = currentTimestampSec;
        state.phase = event.phase;
        
        // 🚀 FIX: Track the extreme value per aggregation strategy
        // NOTE: For 'maximum'/'minimum' aggregations, `lowestScore` reflects the
        // score at the extreme value frame, not the minimum score across the phase.
        // This is intentional: extension rules want the score at peak extension.
        bool shouldUpdate = false;
        
        switch (state.aggregation) {
          case 'maximum':
            shouldUpdate = event.observedValue > state.worstObservedValue;
            break;
          case 'minimum':
            shouldUpdate = event.observedValue < state.worstObservedValue;
            break;
          default: // 'average' or 'latest' -> track the worst-scoring frame
            shouldUpdate = event.score < state.lowestScore;
        }

        if (shouldUpdate) {
          debugPrint('[DEV] type=${state.type} agg=${state.aggregation} value=${event.observedValue.toStringAsFixed(1)} score=${event.score}');
          state.lowestScore = event.score;
          state.worstZoneLabel = event.zoneLabel;
          state.worstObservedValue = event.observedValue;
        }
      } else {
        _activeStates[event.type] = _DeviationState(
          type: event.type, 
          firstDetectedAtSec: currentTimestampSec, 
          lastDetectedAtSec: currentTimestampSec,
          worstZoneLabel: event.zoneLabel, 
          lowestScore: event.score, 
          worstObservedValue: event.observedValue,
          weight: event.weight, 
          phase: event.phase, 
          persistenceMs: event.persistenceMs,
          aggregation: event.aggregation,
        );
      }
    }

    List<String> keysToRemove = [];
    List<ConfirmedDeviation> confirmedList = [];

    _activeStates.forEach((type, state) {
      bool missingFromCurrentFrame = !currentEventTypes.contains(type);
      double durationMs = (currentTimestampSec - state.firstDetectedAtSec) * 1000;

      if (missingFromCurrentFrame && (currentTimestampSec - state.lastDetectedAtSec) > resolutionThresholdSec) {
        keysToRemove.add(type);
      } else {
        if (!state.isConfirmed && durationMs >= state.persistenceMs) {
          state.isConfirmed = true;
        }
        
        if (state.isConfirmed) {
          confirmedList.add(ConfirmedDeviation(
            type: state.type, worstZoneLabel: state.worstZoneLabel, lowestScore: state.lowestScore,
            worstObservedValue: state.worstObservedValue, weight: state.weight, phase: state.phase, durationMs: durationMs,aggregation: state.aggregation,
          ));
        }
      }
    });

    for (var key in keysToRemove) {
      _activeStates.remove(key);
    }
    return confirmedList;
  }
  
  void reset() {
    _activeStates.clear();
  }
}