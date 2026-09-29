import 'coaching_event.dart';

class CoachingCue {
  final String id;
  final String text;
  final CoachingPriority priority;
  final DateTime createdAt;
  
  final String exerciseId;
  final String? deviationType;
  final int? repNumber;

  // 🚀 Voice variation parameters
  final double pitch;
  final double rate;

  CoachingCue({
    required this.id,
    required this.text,
    required this.priority,
    required this.exerciseId,
    this.deviationType,
    this.repNumber,
    this.pitch = 1.0,
    this.rate = 0.5,
  }) : createdAt = DateTime.now();
}