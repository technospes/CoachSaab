class MetricSmoother {
  final List<double> _buffer = [];
  final int windowSize;

  MetricSmoother({this.windowSize = 5});

  double smooth(double newValue) {
    _buffer.add(newValue);

    if (_buffer.length > windowSize) {
      _buffer.removeAt(0);
    }

    final sorted = List<double>.from(_buffer)..sort();
    return sorted[sorted.length ~/ 2];
  }

  void reset() {
    _buffer.clear();
  }
}