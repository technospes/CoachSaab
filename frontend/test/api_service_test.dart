import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach_app/data/api_service.dart';
import 'package:ai_coach_app/domain/activity_config_model.dart';
import 'package:ai_coach_app/domain/activity_rule_model.dart';

void main() {
  test('Fetch Squat Config Bundle from Local FastAPI', () async {
    // final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000/api/v1');
    final apiService = ApiService(baseUrl: 'https://coachsaab-api.onrender.com/api/v1');

    debugPrint('Fetching squat config from backend...');
    final bundle = await apiService.fetchActivityConfigBundle('squat');

    final ActivityConfig config = bundle['config'];
    expect(config, isNotNull);
    expect(config.activityKey, 'squat');
    debugPrint('✅ Success: Fetched Activity -> ${config.displayName}');
    debugPrint('✅ Required Landmarks -> ${config.requiredLandmarks}');

    final List<ActivityRule> rules = bundle['rules'];
    expect(rules, isNotEmpty);
    debugPrint('✅ Success: Loaded ${rules.length} specific rules for ${config.displayName}.');
  });
}