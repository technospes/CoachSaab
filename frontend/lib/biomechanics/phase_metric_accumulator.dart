class PhaseMetricAccumulator {
  final Map<String, List<double>> _phaseValues = {};

  void record(String metricId, double value) {
    _phaseValues.putIfAbsent(metricId, () => []).add(value);
  }

  void reset() {
    _phaseValues.clear();
  }

  int getFrameCount(String metricId) => _phaseValues[metricId]?.length ?? 0;

  double? minimum(String metricId) {
    final values = _phaseValues[metricId];
    if (values == null || values.isEmpty) return null;
    return values.reduce((a, b) => a < b ? a : b);
  }

  double? maximum(String metricId) {
    final values = _phaseValues[metricId];
    if (values == null || values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  double? average(String metricId) {
    final values = _phaseValues[metricId];
    if (values == null || values.isEmpty) return null;
    double sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  double? latest(String metricId) {
    final values = _phaseValues[metricId];
    if (values == null || values.isEmpty) return null;
    return values.last;
  }

  double? getAggregatedValue(String metricId, String aggregationType) {
    switch (aggregationType.toLowerCase()) {
      case 'minimum':
        return minimum(metricId);
      case 'maximum':
        return maximum(metricId);
      case 'average':
        return average(metricId);
      case 'latest':
      default:
        return latest(metricId);
    }
  }
}