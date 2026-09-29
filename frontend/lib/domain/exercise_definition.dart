import 'activity_rule_model.dart';

class TransitionRule {
  final String targetPhase;
  final String metric; 
  final String condition; 
  final double value;

  const TransitionRule({
    required this.targetPhase, 
    required this.metric,
    required this.condition, 
    required this.value,
  });

  factory TransitionRule.fromJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);
    return TransitionRule(
      targetPhase: safeJson['target_phase'] as String,
      metric: safeJson['metric'] as String,
      condition: safeJson['condition'] as String,
      value: (safeJson['value'] as num).toDouble(),
    );
  }
}

class MovementPhaseDefinition {
  final String id; 
  final List<TransitionRule> transitions;

  const MovementPhaseDefinition({
    required this.id, 
    required this.transitions,
  });

  factory MovementPhaseDefinition.fromJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);
    var tList = safeJson['transitions'] as List<dynamic>? ?? [];
    return MovementPhaseDefinition(
      id: (safeJson['id'] ?? safeJson['name']) as String,
      transitions: tList.map((t) => TransitionRule.fromJson(Map<String, dynamic>.from(t as Map))).toList(),
    );
  }
}

class MovementDefinition {
  final String initialState;
  final Map<String, double> parameters;
  final List<MovementPhaseDefinition> phases;

  const MovementDefinition({
    required this.initialState, 
    required this.parameters,
    required this.phases,
  });

  factory MovementDefinition.fromJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);
    final phaseList = safeJson['phases'] as List<dynamic>? ?? [];
    
    if (phaseList.isEmpty) {
      throw const FormatException('Movement definition must contain at least one phase in "phases".');
    }

    final List<MovementPhaseDefinition> parsedPhases = phaseList
        .map((p) => MovementPhaseDefinition.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();

    final phaseIds = parsedPhases.map((p) => p.id).toSet();
    final initialState = (safeJson['initial_state'] as String?) ?? '';

    if (initialState.trim().isEmpty || !phaseIds.contains(initialState)) {
      throw FormatException('Initial state "$initialState" does not match any defined phase ID.');
    }

    for (var phase in parsedPhases) {
      for (var t in phase.transitions) {
        if (!phaseIds.contains(t.targetPhase)) {
          throw FormatException('Transition target phase "${t.targetPhase}" in phase "${phase.id}" does not exist.');
        }
      }
    }

    // ✅ Robustly normalize dynamic Dart/JSON maps for parameters
    final rawParameters = safeJson['parameters'];
    final parametersMap = rawParameters is Map
        ? Map<String, dynamic>.from(rawParameters)
        : <String, dynamic>{};

    final paramsMap = parametersMap.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    return MovementDefinition(
      initialState: initialState,
      parameters: paramsMap,
      phases: parsedPhases,
    );
  }
}

class ExerciseDefinition {
  final int schemaVersion;
  final String id;
  final String name;
  final List<String> requiredLandmarks;
  final List<String> requiredMetrics;
  final String primaryMetric;
  final MovementDefinition movement;
  final List<ActivityRule> rules;
  
  //   1. Add the missing hold-state properties
  final String trackingMode;
  final Map<String, dynamic> hudConfig;

  const ExerciseDefinition({
    this.schemaVersion = 1,
    required this.id, 
    required this.name, 
    required this.requiredLandmarks, 
    required this.requiredMetrics,
    required this.primaryMetric,
    required this.movement, 
    required this.rules,
    //   2. Provide safe defaults to protect existing Squats/Curls
    this.trackingMode = 'repetition',
    this.hudConfig = const {},
  });

  factory ExerciseDefinition.fromJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);
    final int? schemaVersion = (safeJson['schema_version'] as num?)?.toInt();
    if (schemaVersion != 1) {
      throw FormatException('Unsupported or missing exercise schema version: $schemaVersion');
    }

    final id = safeJson['id'] as String?;
    if (id == null || id.trim().isEmpty) {
      throw const FormatException('Exercise definition missing mandatory non-empty "id".');
    }

    final name = safeJson['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw const FormatException('Exercise definition missing mandatory non-empty "name".');
    }

    final rawMovement = safeJson['movement'];
    if (rawMovement == null || rawMovement is! Map) {
      throw const FormatException('Exercise definition missing mandatory "movement" block.');
    }
    final movementMap = Map<String, dynamic>.from(rawMovement);

    final rulesList = safeJson['rules'] as List<dynamic>? ?? [];
    final List<ActivityRule> parsedRules = rulesList.map((r) {
      final ruleMap = Map<String, dynamic>.from(r as Map);
      final metric = ruleMap['metric'] as String?;
      if (metric == null || metric.trim().isEmpty) {
        throw const FormatException('Activity rule missing non-empty "metric".');
      }

      final weight = (ruleMap['weight'] as num?)?.toDouble() ?? 1.0;
      if (weight < 0) {
        throw FormatException('Activity rule for "$metric" has a negative weight: $weight.');
      }

      final zonesList = ruleMap['zones'] as List<dynamic>?;
      if (zonesList == null || zonesList.isEmpty) {
        throw FormatException('Activity rule for "$metric" must define at least one score zone.');
      }

      for (var z in zonesList) {
        final zoneMap = Map<String, dynamic>.from(z as Map);
        final min = (zoneMap['min'] as num?)?.toDouble() ?? 0.0;
        final max = (zoneMap['max'] as num?)?.toDouble() ?? 0.0;
        if (min >= max) {
          throw FormatException('Invalid zone range [$min, $max] for metric "$metric": min must be less than max.');
        }
      }

      return ActivityRule.fromJson(ruleMap);
    }).toList();

    final landmarksList = safeJson['required_landmarks'] as List<dynamic>? ?? [];
    final metricsList = safeJson['required_metrics'] as List<dynamic>? ?? ['knee_angle'];

    return ExerciseDefinition(
      schemaVersion: schemaVersion ?? 1,
      id: id,
      name: name,
      requiredLandmarks: landmarksList.map((l) => l.toString()).toList(),
      requiredMetrics: metricsList.map((m) => m.toString()).toList(),
      primaryMetric: safeJson['primary_metric'] ?? 'knee_angle',
      movement: MovementDefinition.fromJson(movementMap),
      rules: parsedRules,
      //   3. Parse the new properties safely
      trackingMode: safeJson['tracking_mode'] ?? 'repetition',
      hudConfig: safeJson['hud_config'] is Map 
          ? Map<String, dynamic>.from(safeJson['hud_config']) 
          : <String, dynamic>{},
    );
  }
}