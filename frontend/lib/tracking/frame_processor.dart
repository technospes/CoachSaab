import 'dart:collection';
import 'package:camera/camera.dart';

/// Manages frame processing queue to prevent dropped frames and ensure consistency
class FrameProcessor {
  final Queue<_FrameTask> _frameQueue = Queue();
  bool _isProcessingQueue = false;
  
  // Callback for when a frame is processed
  final Future<void> Function(CameraImage, CameraDescription) onProcessFrame;
  
  FrameProcessor({required this.onProcessFrame});

  void enqueueFrame(CameraImage image, CameraDescription camera) {
    // Limit queue size to prevent memory issues
    if (_frameQueue.length > 5) {
      _frameQueue.removeFirst(); // Drop oldest frame if queue is too long
    }
    _frameQueue.add(_FrameTask(image, camera));
    _processNextInQueue();
  }
  
  Future<void> _processNextInQueue() async {
    if (_isProcessingQueue || _frameQueue.isEmpty) return;
    _isProcessingQueue = true;
    
    try {
      final task = _frameQueue.removeFirst();
      await onProcessFrame(task.image, task.camera);
    } catch (e) {
      // Log error but continue processing
      // Use debugPrint instead of print
      // ignore: avoid_print
      print('Frame processing error: $e');
    } finally {
      _isProcessingQueue = false;
      // Process next frame if available
      if (_frameQueue.isNotEmpty) {
        _processNextInQueue();
      }
    }
  }
  
  void clear() {
    _frameQueue.clear();
    _isProcessingQueue = false;
  }
  
  int get queueLength => _frameQueue.length;
}

class _FrameTask {
  final CameraImage image;
  final CameraDescription camera;
  
  _FrameTask(this.image, this.camera);
}