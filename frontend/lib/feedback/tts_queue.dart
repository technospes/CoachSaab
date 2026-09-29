import 'dart:async';
import 'coaching_cue.dart';
import 'coaching_event.dart';
import 'tts_controller.dart';

class TtsQueue {
  final TtsController _tts;
  final List<CoachingCue> _pending = [];
  
  CoachingCue? _currentCue;
  bool _processing = false;
  int _generation = 0;
  bool get isSpeaking => _processing;

  static const Duration _maxQueueAge = Duration(seconds: 3);
  static const Duration _speechGap = Duration(milliseconds: 350);

  TtsQueue(this._tts);

  Future<void> enqueue(CoachingCue cue) async {
    if (!_tts.isEnabled) return;
    if (_isStale(cue)) return;

    // 🚨 Critical: immediately owns the audio channel.
    if (cue.priority == CoachingPriority.critical) {
      await _interruptAndReplace(cue);
      return;
    }

    // ⚠️ Correction: supersedes lower-priority pending cues.
    if (cue.priority == CoachingPriority.correction) {
      _pending.removeWhere((existing) => existing.priority.index < cue.priority.index);

      if (_currentCue != null && _currentCue!.priority.index < cue.priority.index) {
        await _interruptCurrent();
      }
    }

    // Prevent duplicate pending/current cues.
    if (_isDuplicate(cue)) return;

    _pending.add(cue);
    _sortQueue();
    _startWorker();
  }

  bool _isDuplicate(CoachingCue cue) {
    if (_currentCue?.id == cue.id) return true;
    return _pending.any((existing) => existing.id == cue.id);
  }

  bool _isStale(CoachingCue cue) {
    return DateTime.now().difference(cue.createdAt) > _maxQueueAge;
  }

  void _sortQueue() {
    _pending.sort((a, b) => b.priority.index.compareTo(a.priority.index));
  }

  void _startWorker() {
    if (_processing) return;
    _processing = true;
    unawaited(_worker());
  }

  Future<void> _worker() async {
    final workerGeneration = _generation;

    try {
      while (workerGeneration == _generation && _pending.isNotEmpty) {
        _removeStaleCues();
        if (_pending.isEmpty) break;

        final cue = _pending.removeAt(0);
        if (_isStale(cue)) continue;

        _currentCue = cue;

        try {
          await _tts.speak(cue.text, pitch: cue.pitch, rate: cue.rate);
        } finally {
          if (identical(_currentCue, cue)) {
            _currentCue = null;
          }
        }

        if (workerGeneration != _generation) break;

        await Future.delayed(_speechGap);
      }
    } finally {
      if (workerGeneration == _generation) {
        _processing = false;
      }
    }
  }

  void _removeStaleCues() {
    _pending.removeWhere(_isStale);
  }

  Future<void> _interruptCurrent() async {
    _generation++;
    await _tts.stop();
    _currentCue = null;
    _processing = false;
    _startWorker();
  }

  Future<void> _interruptAndReplace(CoachingCue cue) async {
    _generation++;
    _pending.clear();
    await _tts.stop();
    _currentCue = null;
    _pending.add(cue);
    _processing = false;
    _startWorker();
  }

  Future<void> reset() async {
    _generation++;
    _pending.clear();
    await _tts.stop();
    _currentCue = null;
    _processing = false;
  }

  Future<void> dispose() async {
    await reset();
  }
}