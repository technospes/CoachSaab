import 'dart:convert';
import 'package:flutter/services.dart';

class CoachingLibrary {
  Map<String, dynamic> _phrases = {};
  bool _isLoaded = false;
  String userName = "Athlete"; // Can be set on login/init

  Future<void> loadLibrary() async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/coaching/coaching_phrases.json');
      _phrases = jsonDecode(jsonString);
      _isLoaded = true;
    } catch (e) {
      _phrases = {};
    }
  }

  List<String> _process(List<String> rawPhrases) {
    return rawPhrases.map((p) => p.replaceAll('{name}', userName)).toList();
  }

  List<String> getCorrection(String exerciseId, String type) {
    final exerciseMap = _phrases[exerciseId];
    if (exerciseMap != null && exerciseMap[type] != null) {
      return _process(List<String>.from(exerciseMap[type]['correction'] ?? []));
    }
    return [];
  }

  List<String> getRepeated(String exerciseId, String type) {
    final exerciseMap = _phrases[exerciseId];
    if (exerciseMap != null && exerciseMap[type] != null) {
      return _process(List<String>.from(exerciseMap[type]['repeated'] ?? []));
    }
    return [];
  }

  List<String> getFirm(String exerciseId, String type) {
    final exerciseMap = _phrases[exerciseId];
    if (exerciseMap != null && exerciseMap[type] != null) {
      return _process(List<String>.from(exerciseMap[type]['firm'] ?? []));
    }
    return [];
  }

  List<String> getEncouragement() {
    final global = _phrases['global'];
    if (global != null && global['good_rep'] != null) {
      return _process(List<String>.from(global['good_rep']['encouragement'] ?? []));
    }
    return [];
  }

  List<String> getExceptional() {
    final global = _phrases['global'];
    if (global != null && global['good_rep'] != null) {
      return _process(List<String>.from(global['good_rep']['exceptional'] ?? []));
    }
    return [];
  }

  // 🚀 EXPOSING THE NEW RICH CONTENT
  List<String> getPostCorrection() {
    final global = _phrases['global'];
    return _process(List<String>.from(global?['post_correction'] ?? []));
  }

  List<String> getImperfectRep() {
    final global = _phrases['global'];
    return _process(List<String>.from(global?['imperfect_rep'] ?? []));
  }

  bool _lateNightAnnounced = false;

  List<String> getTransition(String type) {
    final hour = DateTime.now().hour;
    final isLate = hour >= 22 || hour < 4;
    
    if (type == 'set_start' && isLate && !_lateNightAnnounced) {
      _lateNightAnnounced = true;
      final latePhrases = _phrases['global']?['transitions']?['set_start_late'];
      if (latePhrases != null) {
         return _process(List<String>.from(latePhrases));
      }
    }
    
    final transitions = _phrases['global']?['transitions'];
    return _process(List<String>.from(transitions?[type] ?? []));
  }

  List<String> getSessionFeedback(String type) {
    final feedback = _phrases['global']?['session_feedback'];
    return _process(List<String>.from(feedback?[type] ?? []));
  }

  List<String> getMilestone(String mode, String key) {
    final global = _phrases['global'];
    return _process(List<String>.from(global?['milestones']?[mode]?[key] ?? []));
  }
}