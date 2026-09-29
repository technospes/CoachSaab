import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/activity_config_model.dart';
import '../domain/activity_rule_model.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<Map<String, dynamic>> fetchActivityConfigBundle(String activityKey) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/activity-configs/$activityKey'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Parse into strictly typed models
        final config = ActivityConfig.fromJson(data['config']);
        
        final rawRules = data['rules'] as List<dynamic>;
        final rules = rawRules.map((r) => ActivityRule.fromJson(r as Map<String, dynamic>)).toList();
        
        return {
          'config': config,
          'rules': rules,
          'feedback_map': data['feedback_map'] as List<dynamic>,
        };
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }
}