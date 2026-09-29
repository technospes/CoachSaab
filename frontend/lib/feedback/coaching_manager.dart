import 'dart:math';
import 'dart:collection';
import 'coaching_event.dart';
import 'coaching_cue.dart';
import 'tts_queue.dart';
import 'coaching_library.dart';

class CoachingManager {
  final TtsQueue _ttsQueue;
  final CoachingLibrary _library;
  final Random _random = Random();
  
  static const Duration _cooldownPeriod = Duration(seconds: 3);
  DateTime? _lastSpeechTime;
  
  final Map<String, int> _setErrorCounts = {};
  int _goodRepCount = 0;
  RepOutcome? _previousRepOutcome;
  
  // ✅ Bug 5 Fix: Context-aware memory pools
  final Map<String, Queue<String>> _recentByCategory = {};
  static const int _memorySize = 5;
  
  bool _hasSpokenHalfwayThisSet = false;
  bool _hasSpokenNearEndThisSet = false;

  CoachingManager(this._ttsQueue, this._library);

  // ✅ Bug 3 & 5 Fix: Safe peek and commit with categories
  String? _peekAndCommit(List<String> pool, {required String category, Map<String, String>? variables}) {
    if (pool.isEmpty) return null;
    
    final seen = _recentByCategory.putIfAbsent(category, () => Queue<String>());
    final fresh = pool.where((p) => !seen.contains(p)).toList();
    final source = fresh.isNotEmpty ? fresh : pool;
    
    String choice = source[_random.nextInt(source.length)];
    
    if (variables != null) {
      variables.forEach((key, value) {
        choice = choice.replaceAll('{$key}', value);
      });
    }

    seen.addLast(choice);
    if (seen.length > _memorySize) seen.removeFirst();
    return choice;
  }

  String _errorKey(CoachingEvent event) {
    return '${event.exerciseId}:${event.type}';
  }

  void processEvent(CoachingEvent event) {
    final now = DateTime.now();
    final key = _errorKey(event);

    if (event.priority == CoachingPriority.correction) {
      _setErrorCounts[key] = (_setErrorCounts[key] ?? 0) + 1;
      _goodRepCount = 0;
    } else if (event.repOutcome == RepOutcome.good || event.repOutcome == RepOutcome.exceptional) {
      _goodRepCount++;
    }

    if (_lastSpeechTime != null && event.priority != CoachingPriority.critical) {
      if (now.difference(_lastSpeechTime!) < _cooldownPeriod) {
        _updatePreviousState(event);
        return; 
      }
    }

    final phrase = _resolvePhrase(event, key);
    _updatePreviousState(event);

    if (phrase == null) return; 

    _lastSpeechTime = now;
    
    // 🚀 Dynamic Voice Delivery
    double pitch = 1.0;
    double rate = 0.5;
    
    if (event.priority == CoachingPriority.encouragement) {
      pitch = 1.0 + (_random.nextDouble() * 0.1 - 0.05);
      rate = 0.5 + (_random.nextDouble() * 0.1 - 0.05); 
    } else if (event.priority == CoachingPriority.correction) {
      pitch = 0.95; // Slightly lower, firmer tone
      rate = 0.48;  // Slightly slower, imperative
    }

    _ttsQueue.enqueue(
      CoachingCue(
        id: '${event.exerciseId}:${event.type}:${event.repNumber}',
        text: phrase,
        priority: event.priority,
        exerciseId: event.exerciseId,
        deviationType: event.priority == CoachingPriority.correction ? event.type : null,
        repNumber: event.repNumber,
        pitch: pitch,
        rate: rate,
      )
    );
  }

  void _updatePreviousState(CoachingEvent event) {
    if (event.repOutcome != null) {
      _previousRepOutcome = event.repOutcome;
    }
  }

  String? _resolvePhrase(CoachingEvent event, String key) {
    if (event.priority == CoachingPriority.correction) {
      final occurrences = _setErrorCounts[key] ?? 1;
      
      if (occurrences >= 3) {
        return _peekAndCommit(_library.getFirm(event.exerciseId, event.type), category: 'firm:${event.type}');
      } else if (occurrences == 2) {
        return _peekAndCommit(_library.getRepeated(event.exerciseId, event.type), category: 'repeated:${event.type}');
      } else {
        return _peekAndCommit(_library.getCorrection(event.exerciseId, event.type), category: 'correction:${event.type}');
      }
    } 
    else if (event.repOutcome == RepOutcome.good || event.repOutcome == RepOutcome.exceptional) {
      
      // 🚀 1. Repetition Milestones
      final target = event.targetReps;
      if (target != null && target >= 4) {
        final halfway = (target / 2).round();
        final nearEnd = target - 2;
        final collides = halfway == nearEnd;

        if (!_hasSpokenHalfwayThisSet && event.repNumber == halfway) {
          _hasSpokenHalfwayThisSet = true;
          if (collides) _hasSpokenNearEndThisSet = true; 
          return _peekAndCommit(
            _library.getMilestone('rep', collides ? 'near_end' : 'halfway'),
            category: 'milestone',
            variables: collides ? {'remaining': '${target - event.repNumber}'} : null,
          );
        }

        if (!_hasSpokenNearEndThisSet && event.repNumber == nearEnd) {
          _hasSpokenNearEndThisSet = true;
          return _peekAndCommit(
            _library.getMilestone('rep', 'near_end'),
            category: 'milestone',
            variables: {'remaining': '${target - event.repNumber}'},
          );
        }
      }

      // 🚀 2. Hold Milestones
      final holdTarget = event.targetDurationSeconds;
      final elapsed = event.elapsedSeconds;
      
      if (holdTarget != null && elapsed != null && holdTarget >= 10) {
        final halfway = holdTarget ~/ 2;
        final nearEnd = holdTarget - 5;
        
        if (!_hasSpokenHalfwayThisSet && elapsed == halfway) {
          _hasSpokenHalfwayThisSet = true;
          return _peekAndCommit(
            _library.getMilestone('hold', 'halfway'),
            category: 'milestone',
            variables: {'seconds': '$elapsed'},
          );
        }
        
        if (!_hasSpokenNearEndThisSet && elapsed == nearEnd) {
          _hasSpokenNearEndThisSet = true;
          return _peekAndCommit(
            _library.getMilestone('hold', 'near_end'),
            category: 'milestone',
            variables: {'seconds': '$elapsed'},
          );
        }
      }

      if (_previousRepOutcome == RepOutcome.imperfect) {
        return _peekAndCommit(_library.getPostCorrection(), category: 'post_correction');
      } else if (event.repOutcome == RepOutcome.exceptional) {
        return _peekAndCommit(_library.getExceptional(), category: 'exceptional');
      } else if (_goodRepCount == 1) {
        return _peekAndCommit(_library.getEncouragement(), category: 'encouragement');
      } else if (_goodRepCount >= 3) {
        if (_random.nextDouble() > 0.15) return null; 
        return _peekAndCommit(_library.getEncouragement(), category: 'encouragement');
      } else {
        if (_random.nextDouble() > 0.30) return null; 
        return _peekAndCommit(_library.getEncouragement(), category: 'encouragement');
      }
    }
    else if (event.repOutcome == RepOutcome.imperfect && event.type == 'imperfect_rep') {
      return _peekAndCommit(_library.getImperfectRep(), category: 'imperfect');
    }
    return null; 
  }

  void resetSet() {
    _setErrorCounts.clear();
    _goodRepCount = 0;
    _previousRepOutcome = null;
    _lastSpeechTime = null;
    _hasSpokenHalfwayThisSet = false;
    _hasSpokenNearEndThisSet = false;
    // LRU cache intentionally persists across sets
  }
  void resetSession() {
    resetSet();
    _recentByCategory.clear();
  }
}