import 'package:flutter/material.dart';
import '../domain/activity_config_model.dart';
import '../domain/movement_phase.dart';

class CoachingState {
  final String displayText;
  final Color color;

  CoachingState({
    required this.displayText,
    required this.color,
  });
}

class FeedbackEngine {
  static CoachingState getCoachingState({
    required List<String> deviations,
    required List<ActivityFeedback> feedbackMap,
    required MovementPhase currentPhase,
  }) {
    // 1. Critical Visibility
    if (deviations.any((d) => d.startsWith('obscured_'))) {
      return CoachingState(
        displayText: "Step back! Body obscured.",
        color: Colors.orange,
      );
    }

    // 2. Active Form Deviations (Resolved to UI text)
    for (var deviation in deviations) {
      final match = feedbackMap.where((f) => f.deviationType == deviation).firstOrNull;
      if (match != null && match.displayText.isNotEmpty) {
        return CoachingState(
          displayText: match.displayText,
          color: Colors.redAccent,
        );
      }
    }

    // 3. Clean Phase States (No chattiness, no hardcoded exercises)
    if (currentPhase == MovementPhase.bottom) {
      return CoachingState(
        displayText: "Hold",
        color: Colors.blue,
      );
    }

    return CoachingState(
      displayText: "Tracking Active",
      color: Colors.green,
    );
  }
}