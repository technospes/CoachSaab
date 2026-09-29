/// Frame rate controller - PROCESS EVERY FRAME for zero lag
class FrameRateController {
  // ⚡ Process every single frame - zero lag
  bool shouldProcessFrame() {
    return true;
  }
  
  void reset() {
    // Nothing to reset
  }
}