import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class TtsController {
  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  
  Completer<void>? _speakCompleter;
  final ValueNotifier<bool> isSpeaking = ValueNotifier(false);
  
  TtsController() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0); // ✅ Bug 2 Fix: Sane baseline pitch
    await _tts.setVolume(1.0);
    
    await _tts.awaitSpeakCompletion(false); 
    
    _tts.setCompletionHandler(_resolveCompleter);
    _tts.setCancelHandler(_resolveCompleter);
    _tts.setErrorHandler((msg) => _resolveCompleter());
  }

  void _resolveCompleter() {
    isSpeaking.value = false;
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
  }

  bool get isEnabled => _enabled;

  // ✅ Receives dynamic voice variations
  Future<void> speak(String text, {double pitch = 1.0, double rate = 0.5}) async {
    if (!_enabled) return;
    isSpeaking.value = true;
    
    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate);
    
    _speakCompleter = Completer<void>();
    _tts.speak(text); 
    
    try {
      await _speakCompleter!.future.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      _resolveCompleter(); 
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _resolveCompleter();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) {
      await stop();
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}