import 'exercise_definition.dart';
import 'activity_rule_model.dart';

// ==========================================
// 1. SQUAT DEFINITION
// ==========================================
@Deprecated(
  'Legacy migration oracle. Use ExerciseRepository.loadExercise() instead.',
)
final goldenSquatDefinition = ExerciseDefinition(
  id: 'squat',
  name: 'Standard Squat',
  requiredLandmarks: ['right_hip', 'right_knee', 'right_ankle', 'left_hip', 'left_knee', 'left_ankle'],
  requiredMetrics: ['knee', 'right_knee', 'left_knee', 'knee_angle'],
  primaryMetric: 'knee_angle',
  movement: const MovementDefinition(
    initialState: 'idle',
    parameters: {
      'standing_threshold': 155.0,
      'initiation_margin': 5.0,
      'bottom_margin': 3.0,
      'ascending_margin': 10.0,
    },
    phases: [
      MovementPhaseDefinition(
        id: 'idle',
        transitions: [
          TransitionRule(targetPhase: 'descending', metric: 'knee_angle', condition: 'less_than', value: 150.0)
        ]
      ),
      MovementPhaseDefinition(
        id: 'descending',
        transitions: [
          TransitionRule(targetPhase: 'bottom', metric: 'knee_angle', condition: 'reversal_increase', value: 3.0),
          TransitionRule(targetPhase: 'aborted', metric: 'knee_angle', condition: 'greater_than', value: 155.0)
        ]
      ),
      MovementPhaseDefinition(
        id: 'bottom',
        transitions: [
          TransitionRule(targetPhase: 'ascending', metric: 'knee_angle', condition: 'reversal_increase', value: 10.0)
        ]
      ),
      MovementPhaseDefinition(
        id: 'ascending',
        transitions: [
          TransitionRule(targetPhase: 'completed', metric: 'knee_angle', condition: 'greater_than', value: 155.0),
          TransitionRule(targetPhase: 'aborted', metric: 'knee_angle', condition: 'reversal_decrease', value: 5.0)
        ]
      ),
      MovementPhaseDefinition(id: 'completed', transitions: []),
      MovementPhaseDefinition(id: 'aborted', transitions: []),
    ]
  ),
  rules: [
    const ActivityRule(
      joint: 'knee', 
      metric: 'knee_angle', 
      phase: 'bottom', 
      aggregation: 'minimum', 
      weight: 1.0, 
      deviationType: 'insufficient_depth',
      persistenceMs: 0, 
      zones: [
        MetricZone(min: 0.0, max: 100.0, label: 'excellent', score: 100.0),
        MetricZone(min: 100.0, max: 115.0, label: 'acceptable', score: 85.0),
        MetricZone(min: 115.0, max: 130.0, label: 'imperfect', score: 60.0),
        MetricZone(min: 130.0, max: 180.0, label: 'poor', score: 20.0),
      ]
    )
  ]
);

// ==========================================
// 2. BICEP CURL DEFINITION
// ==========================================
@Deprecated(
  'Legacy migration oracle. Use ExerciseRepository.loadExercise() instead.',
)
final goldenBicepCurlDefinition = ExerciseDefinition(
  id: 'bicep_curl',
  name: 'Standard Bicep Curl',
  requiredLandmarks: ['right_shoulder', 'right_elbow', 'right_wrist', 'right_hip', 'left_shoulder', 'left_elbow', 'left_wrist', 'left_hip'],
  // ✅ Added segment metric to required metrics list
  requiredMetrics: ['elbow', 'right_elbow', 'left_elbow', 'elbow_angle', 'upper_arm_vertical_deviation'], 
  primaryMetric: 'elbow_angle',
  movement: const MovementDefinition(
    initialState: 'idle',
    parameters: {}, 
    phases: [
      MovementPhaseDefinition(
        id: 'idle',
        transitions: [
          TransitionRule(targetPhase: 'flexing', metric: 'elbow_angle', condition: 'less_than', value: 140.0)
        ]
      ),
      MovementPhaseDefinition(
        id: 'flexing',
        transitions: [
          TransitionRule(targetPhase: 'peak', metric: 'elbow_angle', condition: 'reversal_increase', value: 5.0),
          TransitionRule(targetPhase: 'aborted', metric: 'elbow_angle', condition: 'greater_than', value: 160.0)
        ]
      ),
      MovementPhaseDefinition(
        id: 'peak',
        transitions: [
          TransitionRule(targetPhase: 'extending', metric: 'elbow_angle', condition: 'reversal_increase', value: 15.0)
        ]
      ),
      MovementPhaseDefinition(
        id: 'extending',
        transitions: [
          TransitionRule(targetPhase: 'completed', metric: 'elbow_angle', condition: 'greater_than', value: 130.0),
          TransitionRule(targetPhase: 'aborted', metric: 'elbow_angle', condition: 'reversal_decrease', value: 10.0)
        ]
      ),
      MovementPhaseDefinition(id: 'completed', transitions: []),
      MovementPhaseDefinition(id: 'aborted', transitions: []),
    ]
  ),
  rules: [
    const ActivityRule(
      joint: 'elbow', 
      metric: 'elbow_angle', 
      phase: 'bottom', 
      aggregation: 'minimum', 
      weight: 1.0, 
      deviationType: 'insufficient_curl',
      persistenceMs: 0, 
      zones: [
        MetricZone(min: 0.0, max: 35.0, label: 'excellent', score: 100.0), 
        MetricZone(min: 35.0, max: 40.0, label: 'acceptable', score: 85.0),
        MetricZone(min: 40.0, max: 90.0, label: 'imperfect', score: 60.0), 
        MetricZone(min: 90.0, max: 180.0, label: 'poor', score: 20.0), 
      ]
    ),
    // ✅ Added multi-metric stability rule for upper arm movement
    const ActivityRule(
      joint: 'shoulder', 
      metric: 'upper_arm_vertical_deviation', 
      phase: 'bottom', 
      aggregation: 'maximum', 
      weight: 0.8, 
      deviationType: 'excessive_elbow_swing',
      persistenceMs: 0, 
      zones: [
        MetricZone(min: 0.0, max: 15.0, label: 'excellent', score: 100.0),
        MetricZone(min: 15.0, max: 25.0, label: 'acceptable', score: 85.0),
        MetricZone(min: 25.0, max: 40.0, label: 'imperfect', score: 60.0),
        MetricZone(min: 40.0, max: 180.0, label: 'poor', score: 20.0),
      ]
    )
  ]
);