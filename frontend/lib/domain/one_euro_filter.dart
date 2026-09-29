import 'dart:math';

/// A single-value low-pass filter used internally by OneEuroFilter.
/// Not used directly — see OneEuroFilter below.
class _LowPassFilter {
  double? _lastRawValue;
  double? _lastFilteredValue;

  double filter(double value, double alpha) {
    double result;
    if (_lastFilteredValue == null) {
      result = value;
    } else {
      result = alpha * value + (1 - alpha) * _lastFilteredValue!;
    }
    _lastRawValue = value;
    _lastFilteredValue = result;
    return result;
  }

  double? get lastRawValue => _lastRawValue;

  bool get hasLastRawValue => _lastRawValue != null;
}

/// The One Euro Filter (Casiez, Roussel, Vogel — CHI 2012).
/// https://gery.casiez.net/1euro/
///
/// Designed exactly for this problem: noisy, jittery signals from human
/// motion tracking (originally built for mouse/touch input, widely used
/// since for pose/hand landmark smoothing). It adapts its own cutoff
/// frequency to the signal's velocity:
///   - When the tracked point is nearly still, cutoff is low -> heavy
///     smoothing -> kills jitter at rest (e.g. holding a plank, or the
///     top/bottom pause of a squat).
///   - When the tracked point is moving fast, cutoff rises -> filter
///     opens up -> tracks fast motion with minimal added lag (e.g. the
///     fast descent of a quick rep).
///
/// This is a single-value filter — one instance per scalar signal (one
/// per landmark's x, one per its y, or one per a computed joint angle).
/// It is NOT frame-rate-dependent by assumption — it takes an explicit
/// timestamp each call, so irregular camera frame timing (which is
/// normal on Android image streams) doesn't destabilize it.
class OneEuroFilter {
  OneEuroFilter({
    this.minCutoff = 1.0,
    this.beta = 0.0,
    this.dCutoff = 1.0,
  });

  /// Minimum cutoff frequency (Hz). Lower = more smoothing at low speed,
  /// but more lag. This is the main "how smooth at rest" knob.
  final double minCutoff;

  /// Speed coefficient. Higher = cutoff rises faster as speed increases,
  /// meaning the filter opens up (tracks closely, less smoothing) sooner
  /// during fast motion. This is the main "how responsive during fast
  /// movement" knob. beta = 0 disables adaptivity entirely (becomes a
  /// plain fixed low-pass filter).
  final double beta;

  /// Cutoff frequency for the derivative (velocity estimate) itself.
  /// Rarely needs tuning — 1.0 is the value used in the original paper
  /// and most reference implementations.
  final double dCutoff;

  final _LowPassFilter _xFilter = _LowPassFilter();
  final _LowPassFilter _dxFilter = _LowPassFilter();
  double? _lastTimestampSeconds;

  static double _alpha(double cutoff, double dtSeconds) {
    final double tau = 1.0 / (2 * pi * cutoff);
    return 1.0 / (1.0 + tau / dtSeconds);
  }

  /// Filters one new sample. [timestampSeconds] should be a monotonically
  /// increasing clock (e.g. `DateTime.now().microsecondsSinceEpoch / 1e6`
  /// or a frame counter divided by expected fps) — NOT wall-clock date,
  /// just something that increases each call by roughly the real elapsed
  /// time. First call always returns the raw value unchanged (filter has
  /// no history yet to smooth against).
  double filter(double value, double timestampSeconds) {
    if (_lastTimestampSeconds == null) {
      _lastTimestampSeconds = timestampSeconds;
      return _xFilter.filter(value, 1.0);
    }

    double dt = timestampSeconds - _lastTimestampSeconds!;
    _lastTimestampSeconds = timestampSeconds;

    // Guard against a zero or negative dt (duplicate/out-of-order
    // timestamps, which can happen with async camera frame delivery) —
    // treat it as "no time passed" rather than dividing by zero.
    if (dt <= 0) dt = 1.0 / 30.0;

    // Estimate velocity as the change in the raw (unfiltered) signal
    // over dt, then smooth that estimate too — this is what makes the
    // filter adaptive rather than a fixed-cutoff low-pass.
    final double previousRaw = _xFilter.lastRawValue ?? value;
    final double dValue = (value - previousRaw) / dt;
    final double edValue = _dxFilter.filter(dValue, _alpha(dCutoff, dt));

    final double cutoff = minCutoff + beta * edValue.abs();
    return _xFilter.filter(value, _alpha(cutoff, dt));
  }

  bool get hasHistory => _xFilter.hasLastRawValue;
}
