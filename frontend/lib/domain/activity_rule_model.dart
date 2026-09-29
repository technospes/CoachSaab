class MetricZone {
  final double min;
  final double max;
  final String label; 
  final double score;

  const MetricZone({
    required this.min, required this.max, required this.label, required this.score,
  });

  factory MetricZone.fromJson(Map<String, dynamic> json) {
    return MetricZone(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      label: json['label'] as String,
      score: (json['score'] ?? 100.0).toDouble(), 
    );
  }
}

class ActivityRule {
  final String joint;
  final String metric;
  final String phase;
  final String aggregation; 
  final List<MetricZone> zones;
  final double weight;
  final String deviationType;
  final int persistenceMs;

  const ActivityRule({
    required this.joint, 
    required this.metric, 
    required this.phase, 
    required this.aggregation,
    required this.zones, 
    required this.weight, 
    required this.deviationType, 
    required this.persistenceMs,
  });

  factory ActivityRule.fromJson(Map<String, dynamic> json) {
    final zonesList = json['zones'] as List<dynamic>? ?? [];
    final parsedZones = zonesList.map((z) => MetricZone.fromJson(z as Map<String, dynamic>)).toList();

    return ActivityRule(
      joint: json['joint'] ?? json['metric']?.replaceAll('_angle', '') ?? 'knee',
      metric: json['metric'] ?? 'angle',
      phase: json['phase'] ?? 'bottom',
      aggregation: json['aggregation'] ?? 'minimum',
      zones: parsedZones,
      weight: (json['weight'] as num? ?? 1.0).toDouble(),
      deviationType: json['deviation_type'] ?? 'form_deviation',
      // ✅ Safely parse int whether JSON provides an int or a double (e.g. 0.0)
      persistenceMs: (json['persistence_ms'] as num?)?.toInt() ?? 0, 
    );
  }
}