// import 'metric_engine.dart';

// enum MovementPhase {
//   idle,
//   descending,
//   bottom,
//   ascending,
//   completed,
//   aborted,
// }

// class PhaseConfig {
//   final double standingThreshold;
//   final double initiationMargin;
//   final double bottomMargin;
//   final double ascendingMargin;
//   final String primaryJoint;

//   const PhaseConfig({
//     required this.standingThreshold,
//     required this.initiationMargin,
//     required this.bottomMargin,
//     required this.ascendingMargin,
//     required this.primaryJoint,
//   });
// }

// class PhaseDetector {
//   MovementPhase _currentPhase = MovementPhase.idle;
//   final PhaseConfig config;
  
//   double _deepestAngle = 999.0;
//   double _highestAngleSinceBottom = -999.0;

//   PhaseDetector(this.config);

//   MovementPhase get currentPhase => _currentPhase;

//   MovementPhase processMetrics(ExerciseMetrics metrics) {
//     final double? primaryAngle = metrics.getAngle(config.primaryJoint);
//     if (primaryAngle == null) return _currentPhase;

//     switch (_currentPhase) {
//       case MovementPhase.idle:
//       case MovementPhase.completed:
//       case MovementPhase.aborted:
//         if (primaryAngle < config.standingThreshold - config.initiationMargin) {
//           _currentPhase = MovementPhase.descending;
//           _deepestAngle = primaryAngle;
//         }
//         break;

//       case MovementPhase.descending:
//         if (primaryAngle < _deepestAngle) {
//           _deepestAngle = primaryAngle;
//         } else if (primaryAngle > _deepestAngle + config.bottomMargin) {
//           _currentPhase = MovementPhase.bottom;
//         }
//         break;

//       case MovementPhase.bottom:
//         if (primaryAngle < _deepestAngle) {
//           _deepestAngle = primaryAngle; // Update depth if they adjust at the bottom
//         } else if (primaryAngle > _deepestAngle + config.ascendingMargin) {
//           _currentPhase = MovementPhase.ascending;
//           _highestAngleSinceBottom = primaryAngle;
//         }
//         break;

//       case MovementPhase.ascending:
//         if (primaryAngle >= config.standingThreshold) {
//           _currentPhase = MovementPhase.completed;
//         } else if (primaryAngle > _highestAngleSinceBottom) {
//           _highestAngleSinceBottom = primaryAngle;
//         } else if (primaryAngle < _highestAngleSinceBottom - config.bottomMargin) {
//           // Reversal downwards during ascent
//           _currentPhase = MovementPhase.aborted;
//         }
//         break;
//     }

//     return _currentPhase;
//   }

//   void reset() {
//     _currentPhase = MovementPhase.idle;
//     _deepestAngle = 999.0;
//     _highestAngleSinceBottom = -999.0;
//   }
// }