import 'package:shared_preferences/shared_preferences.dart';
import '../../data/api_client.dart';

class PlanRepository {
  final ApiClient apiClient;

  PlanRepository(this.apiClient);

  Future<Set<String>> getCompletedDaysLocal(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('completions_$planId') ?? []).toSet();
  }

  Future<void> saveCompletedDaysLocal(String planId, Set<String> completions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('completions_$planId', completions.toList());
  }

  Future<Set<String>> fetchCompletedDaysFromServer(String planId) async {
    final List<dynamic> comps = await apiClient.get('/plans/$planId/completions');
    return comps.cast<String>().toSet();
  }

  Future<void> toggleDayCompletionOnServer(String planId, int week, int day, bool isCompleted) async {
    // Note: No user_id. The backend FastAPI depends on the JWT token.
    await apiClient.post('/plans/$planId/completions/toggle', body: {
      'week_number': week,
      'day_number': day,
      'is_completed': isCompleted,
    });
  }

  int calculateTotalTrainingDays(Map<String, dynamic> planJson) {
    final schedule = (planJson['schedule'] as List?) ?? [];
    int trainingDaysPerWeek = 7;
    
    if (schedule.isNotEmpty) {
      trainingDaysPerWeek = schedule.where((day) => day['is_rest'] != true).length;
    }
    
    final durationWeeks = (planJson['duration_weeks'] as num?)?.toInt() ?? 0;
    return durationWeeks * trainingDaysPerWeek;
  }
}