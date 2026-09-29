enum CoachingPriority { low, encouragement, correction, transition, critical }
enum RepOutcome { good, imperfect, exceptional }

class CoachingEvent {
  final String exerciseId;
  final String type;
  final CoachingPriority priority;
  final double score;
  final int repNumber;
  final String phase;
  final bool isExceptional;
  final RepOutcome? repOutcome;
  
  final int? targetReps; 
  final int? elapsedSeconds;       // 🚀 For hold/continuous
  final int? targetDurationSeconds; // 🚀 For hold/continuous

  const CoachingEvent({
    required this.exerciseId,
    required this.type,
    this.priority = CoachingPriority.low,
    this.score = 100.0,
    this.repNumber = 0,
    this.phase = 'idle',
    this.isExceptional = false,
    this.repOutcome,
    this.targetReps,
    this.elapsedSeconds,
    this.targetDurationSeconds,
  });
}