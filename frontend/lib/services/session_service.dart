import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../tracking/session_config.dart';
import '../domain/exercise_repository.dart';
import 'package:flutter/foundation.dart';

class SessionService {
  final String baseUrl = 'https://coachsaab-api.onrender.com/api/v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ExerciseRepository _repository = ExerciseRepository();

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token') 
        ?? await _storage.read(key: 'jwt') 
        ?? await _storage.read(key: 'token');
  }

  /// POST /sessions/start (Offline-first bypass)
  Future<SessionConfig> startSession(
    String activityKey, {
    int? overrideReps,
    int? overrideDuration,
  }) async {
    try {
      final definition = await _repository.loadExercise(activityKey);
      final mockSessionId = 'local_${DateTime.now().millisecondsSinceEpoch}';

      final mode = definition.trackingMode; 
      final hudConfig = definition.hudConfig; 

      int? reps;
      int? duration;

      if (mode == 'repetition') {
        // 🚀 Apply override if it exists, otherwise fallback to JSON default, otherwise 10
        reps = overrideReps ?? (hudConfig['target_reps'] as num?)?.toInt() ?? 10;
      } else if (mode == 'hold') {
        duration = overrideDuration ?? (hudConfig['target_duration_seconds'] as num?)?.toInt() ?? 30;
      }

      debugPrint('[SESSION] key=$activityKey mode=$mode reps=$reps duration=$duration');

      return SessionConfig(
        sessionId: mockSessionId,
        exercise: definition, 
        targetReps: reps,
        targetDurationSeconds: duration,
      );
    } catch (e) {
      throw Exception("Failed to initialize offline session: $e");
    }
  }
}