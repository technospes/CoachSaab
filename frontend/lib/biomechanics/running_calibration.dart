import 'dart:math';
import 'package:flutter/material.dart'; // Needed for Size
import '../domain/unified_landmark.dart';

enum CalibrationStatus { checkingView, collectingBaseline, ready, invalid }
enum RunningDirection { left, right }

class RunningCalibrationResult {
  final CalibrationStatus status;
  final RunningDirection? direction;
  final double? torsoLength;
  final double bodyHeightRatio;
  final double landmarkConfidence;
  final String? reason;

  const RunningCalibrationResult({
    required this.status,
    this.direction,
    this.torsoLength,
    required this.bodyHeightRatio,
    required this.landmarkConfidence,
    this.reason,
  });
}

class _MotionSample {
  final int timestampUs;
  final double pelvisX;
  final double confidence;

  const _MotionSample({
    required this.timestampUs,
    required this.pelvisX,
    required this.confidence,
  });
}

class RunningCalibration {
  final double minConfidence = 0.45;
  final double minBodyHeightRatio = 0.15;
  final int calibrationDurationUs = 1500000;
  final int minimumCalibrationSamples = 5;
  final double minDirectionDisplacementBodyScales = 0.4;

  bool _isFrozen = false;
  int? _calibrationStartTimeUs;
  
  final List<double> _torsoSamples = [];
  final List<_MotionSample> _pelvisSamples = [];

  double? _frozenTorsoLength;
  RunningDirection? _frozenDirection;

  RunningCalibrationResult processFrame({
    required Map<String, UnifiedLandmark> landmarks,
    required Size imageSize,
    required int timestampUs,
  }) {
    if (_isFrozen) return _buildReadyResult(1.0, 1.0);

    if (!_isViewValid(landmarks)) {
      return _buildResult(CalibrationStatus.checkingView, 0.0, 0.0, reason: "Step into frame. Ensure full body is visible.");
    }

    final double bodyRatio = _calculateBodyHeightRatio(landmarks, imageSize.height);
    if (bodyRatio < minBodyHeightRatio) {
      return _buildResult(CalibrationStatus.invalid, bodyRatio, 1.0, reason: "Subject is too far away. Step closer.");
    }

    _calibrationStartTimeUs ??= timestampUs;
    _accumulateData(landmarks, timestampUs);

    final int elapsedUs = timestampUs - _calibrationStartTimeUs!;
    if (elapsedUs >= calibrationDurationUs) {
      return _evaluateAndFreeze(bodyRatio);
    }

    return _buildResult(CalibrationStatus.collectingBaseline, bodyRatio, 1.0, reason: "Start running naturally...");
  }

  bool _isViewValid(Map<String, UnifiedLandmark> landmarks) {
    bool isReliable(UnifiedLandmark? l) => l != null && l.confidence >= minConfidence;
    return isReliable(landmarks['nose']) &&
           isReliable(landmarks['leftShoulder']) &&
           isReliable(landmarks['rightShoulder']) &&
           isReliable(landmarks['leftHip']) &&
           isReliable(landmarks['rightHip']) &&
           isReliable(landmarks['leftKnee']) &&
           isReliable(landmarks['rightKnee']) &&
           isReliable(landmarks['leftAnkle']) &&
           isReliable(landmarks['rightAnkle']);
  }

  double _calculateBodyHeightRatio(Map<String, UnifiedLandmark> landmarks, double imageHeight) {
    final points = [
      landmarks['nose'], landmarks['leftShoulder'], landmarks['rightShoulder'],
      landmarks['leftHip'], landmarks['rightHip'], landmarks['leftKnee'],
      landmarks['rightKnee'], landmarks['leftAnkle'], landmarks['rightAnkle'],
    ].whereType<UnifiedLandmark>().where((l) => l.confidence >= minConfidence).toList();

    if (points.length < 7) return 0.0;
    final double minY = points.map((p) => p.y).reduce(min);
    final double maxY = points.map((p) => p.y).reduce(max);
    return ((maxY - minY).abs() / imageHeight).clamp(0.0, 1.0);
  }

  void _accumulateData(Map<String, UnifiedLandmark> landmarks, int timestampUs) {
    final leftShoulder = landmarks['leftShoulder']!;
    final rightShoulder = landmarks['rightShoulder']!;
    final leftHip = landmarks['leftHip']!;
    final rightHip = landmarks['rightHip']!;

    final double midShoulderX = (leftShoulder.x + rightShoulder.x) / 2;
    final double midShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final double midHipX = (leftHip.x + rightHip.x) / 2;
    final double midHipY = (leftHip.y + rightHip.y) / 2;

    final double torsoLength = sqrt(pow(midShoulderX - midHipX, 2) + pow(midShoulderY - midHipY, 2));
    final double avgConfidence = (leftHip.confidence + rightHip.confidence) / 2;
    
    _torsoSamples.add(torsoLength);
    _pelvisSamples.add(_MotionSample(timestampUs: timestampUs, pelvisX: midHipX, confidence: avgConfidence));
  }

  RunningCalibrationResult _evaluateAndFreeze(double currentRatio) {
    if (_torsoSamples.length < minimumCalibrationSamples) {
      _resetClock(); 
      return _buildResult(CalibrationStatus.checkingView, currentRatio, 0.0, reason: "Too many dropped frames. Ensure good lighting.");
    }
    _torsoSamples.sort();
    _frozenTorsoLength = _torsoSamples[_torsoSamples.length ~/ 2];

    final double displacement = _calculateRobustDisplacement();
    final double normalizedDisplacement = displacement.abs() / _frozenTorsoLength!;

    if (normalizedDisplacement < minDirectionDisplacementBodyScales) {
      _resetClock(); 
      return _buildResult(CalibrationStatus.collectingBaseline, currentRatio, 1.0, reason: "Start running to calibrate direction.");
    }

    _frozenDirection = (displacement < 0) ? RunningDirection.left : RunningDirection.right;
    _isFrozen = true;
    return _buildReadyResult(currentRatio, 1.0);
  }

  double _calculateRobustDisplacement() {
    if (_pelvisSamples.isEmpty) return 0.0;
    double sumT = 0, sumX = 0, sumTX = 0, sumT2 = 0;
    final int n = _pelvisSamples.length;
    for (final sample in _pelvisSamples) {
      final double t = (sample.timestampUs - _calibrationStartTimeUs!) / 1000000.0; 
      final double x = sample.pelvisX;
      sumT += t; sumX += x; sumTX += (t * x); sumT2 += (t * t);
    }
    final double meanT = sumT / n;
    final double meanX = sumX / n;
    final double denominator = sumT2 - (n * meanT * meanT);
    if (denominator == 0) return 0.0; 

    final double slope = (sumTX - (n * meanT * meanX)) / denominator;
    final double totalTimeSeconds = (_pelvisSamples.last.timestampUs - _calibrationStartTimeUs!) / 1000000.0;
    return slope * totalTimeSeconds; 
  }

  void _resetClock() {
    _calibrationStartTimeUs = null; _torsoSamples.clear(); _pelvisSamples.clear();
  }

  RunningCalibrationResult _buildResult(CalibrationStatus status, double ratio, double conf, {String? reason}) {
    return RunningCalibrationResult(status: status, bodyHeightRatio: ratio, landmarkConfidence: conf, reason: reason);
  }

  RunningCalibrationResult _buildReadyResult(double ratio, double conf) {
    return RunningCalibrationResult(status: CalibrationStatus.ready, direction: _frozenDirection, torsoLength: _frozenTorsoLength, bodyHeightRatio: ratio, landmarkConfidence: conf, reason: "Ready.");
  }

  void reset() {
    _isFrozen = false; _resetClock(); _frozenTorsoLength = null; _frozenDirection = null;
  }
}