class ActivityConfig {
  final String category;
  final String activityKey;
  final String displayName;
  final List<String> requiredLandmarks;
  final String trackingMode;
  final List<String> phases;
  final Map<String, dynamic> hudConfig;
  final bool requiresHandTracking;

  ActivityConfig({
    required this.category,
    required this.activityKey,
    required this.displayName,
    required this.requiredLandmarks,
    required this.trackingMode,
    required this.phases,
    required this.hudConfig,
    this.requiresHandTracking = false,
  });

  factory ActivityConfig.fromJson(Map<String, dynamic> json) {
    return ActivityConfig(
      category: json['category'] ?? '',
      activityKey: json['activity_key'] ?? '',
      displayName: json['display_name'] ?? '',
      requiredLandmarks: List<String>.from(json['required_landmarks'] ?? []),
      trackingMode: json['tracking_mode'] ?? 'repetition',
      phases: List<String>.from(json['phases'] ?? []),
      hudConfig: json['hud_config'] ?? {},
      requiresHandTracking: json['requires_hand_tracking'] ?? false,
    );
  }
}

class ActivityFeedback {
  final String deviationType;
  final String locale;
  final String displayText;
  final String ttsText;

  ActivityFeedback({
    required this.deviationType,
    required this.locale,
    required this.displayText,
    required this.ttsText,
  });

  factory ActivityFeedback.fromJson(Map<String, dynamic> json) {
    return ActivityFeedback(
      deviationType: json['deviation_type'] ?? '',
      locale: json['locale'] ?? 'en',
      displayText: json['display_text'] ?? '',
      ttsText: json['tts_text'] ?? '',
    );
  }
}