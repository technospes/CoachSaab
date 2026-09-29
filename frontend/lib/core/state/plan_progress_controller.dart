import 'package:flutter/foundation.dart';
import '../../data/api_client.dart';
import '../../data/repositories/plan_repository.dart';

class PlanProgress {
  final String planId;
  final int totalTrainingDays;
  final Set<String> completedKeys;

  const PlanProgress({
    this.planId = '',
    this.totalTrainingDays = 0,
    this.completedKeys = const {},
  });

  int get completedDays => completedKeys.length;
  double get fraction => totalTrainingDays > 0 ? (completedDays / totalTrainingDays).clamp(0.0, 1.0) : 0.0;
  int get percentage => (fraction * 100).round();
}

class PlanProgressController extends ValueNotifier<PlanProgress> {
  final PlanRepository repository;

  PlanProgressController(this.repository) : super(const PlanProgress());

  Future<void> load(String planId, Map<String, dynamic> planJson) async {
    final int totalDays = repository.calculateTotalTrainingDays(planJson);

    // 1. Instant load from local cache
    final localCompletions = await repository.getCompletedDaysLocal(planId);
    value = PlanProgress(planId: planId, totalTrainingDays: totalDays, completedKeys: localCompletions);

    // 2. Background server sync
    try {
      final serverCompletions = await repository.fetchCompletedDaysFromServer(planId);
      await repository.saveCompletedDaysLocal(planId, serverCompletions);
      value = PlanProgress(planId: planId, totalTrainingDays: totalDays, completedKeys: serverCompletions);
    } catch (_) {}
  }

  Future<void> toggleDay(String planId, int week, int day) async {
    final String dayKey = 'w${week}_d$day';
    final Set<String> currentCompletions = Set.from(value.completedKeys);
    final bool isCurrentlyCompleted = currentCompletions.contains(dayKey);
    final bool targetState = !isCurrentlyCompleted;

    // Optimistic UI update
    targetState ? currentCompletions.add(dayKey) : currentCompletions.remove(dayKey);
    await repository.saveCompletedDaysLocal(planId, currentCompletions);
    value = PlanProgress(planId: planId, totalTrainingDays: value.totalTrainingDays, completedKeys: currentCompletions);

    // Network Sync
    try {
      await repository.toggleDayCompletionOnServer(planId, week, day, targetState);
    } catch (e) {
      // Rollback strictly handled here on failure
      targetState ? currentCompletions.remove(dayKey) : currentCompletions.add(dayKey);
      await repository.saveCompletedDaysLocal(planId, currentCompletions);
      value = PlanProgress(planId: planId, totalTrainingDays: value.totalTrainingDays, completedKeys: currentCompletions);
      throw Exception("Sync failed");
    }
  }
}

// Global instance 
final planProgressController = PlanProgressController(PlanRepository(ApiClient()));