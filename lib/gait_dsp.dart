import 'dart:math';

/// Shared DSP helpers for wrist and phone gait feature extraction.
class GaitDsp {
  GaitDsp._();

  static double mean(List<double> x) {
    if (x.isEmpty) return 0;
    return x.reduce((a, b) => a + b) / x.length;
  }

  static double std(List<double> x) {
    if (x.length < 2) return 0;
    final mu = mean(x);
    final sq = x.map((v) => (v - mu) * (v - mu));
    return sqrt(sq.reduce((a, b) => a + b) / (x.length - 1));
  }

  static double rms(List<double> x) {
    if (x.isEmpty) return 0;
    return sqrt(x.map((v) => v * v).reduce((a, b) => a + b) / x.length);
  }

  /// Local maxima above mean + 0.3·σ with minimum peak separation.
  static List<int> detectPeaks(List<double> signal, double fs) {
    final mu = mean(signal);
    final sd = std(signal);
    final thr = mu + 0.3 * sd;
    final minDist = (fs * 0.35).round();

    final peaks = <int>[];
    for (int i = 1; i < signal.length - 1; i++) {
      if (signal[i] > thr &&
          signal[i] > signal[i - 1] &&
          signal[i] > signal[i + 1]) {
        if (peaks.isEmpty || (i - peaks.last) >= minDist) {
          peaks.add(i);
        }
      }
    }
    return peaks;
  }

  static double dominantFreq(List<double> signal, double fs) {
    if (signal.length < 2) return 0;
    final mu = mean(signal);
    int crossings = 0;
    for (int i = 1; i < signal.length; i++) {
      if ((signal[i - 1] - mu) * (signal[i] - mu) < 0) crossings++;
    }
    return (crossings / 2.0) / (signal.length / fs);
  }

  /// Step intervals (seconds) from peak indices and sample rate.
  static List<double> peakIntervalsSec(List<int> peaks, double fs) {
    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add((peaks[i] - peaks[i - 1]) / fs);
    }
    return intervals;
  }

  /// Step-time asymmetry: |odd-mean − even-mean| / overall-mean (Axivity-style).
  static double? stepAsymmetry(List<double> stepIntervals) {
    if (stepIntervals.length < 4) return null;
    final odd = <double>[];
    final even = <double>[];
    for (int i = 0; i < stepIntervals.length; i++) {
      if (i.isOdd) {
        odd.add(stepIntervals[i]);
      } else {
        even.add(stepIntervals[i]);
      }
    }
    if (odd.isEmpty || even.isEmpty) return null;
    final overall = mean(stepIntervals);
    if (overall <= 0) return null;
    return (mean(odd) - mean(even)).abs() / overall;
  }

  /// Lightweight sample entropy proxy on stride intervals (0–1 scale).
  static double? sampleEntropy(List<double> intervals, {int m = 2}) {
    if (intervals.length < m + 3) return null;
    double countMatches(List<double> template, List<List<double>> windows) {
      var c = 0;
      for (final w in windows) {
        if (w.length != template.length) continue;
        var ok = true;
        for (int i = 0; i < template.length; i++) {
          if ((w[i] - template[i]).abs() > 0.05 * mean(intervals)) {
            ok = false;
            break;
          }
        }
        if (ok) c++;
      }
      return c.toDouble();
    }

    final windows = <List<double>>[];
    for (int i = 0; i <= intervals.length - m; i++) {
      windows.add(intervals.sublist(i, i + m));
    }
    if (windows.length < 2) return null;

    var phiM = 0.0;
    var phiM1 = 0.0;
    for (final w in windows) {
      phiM += log(countMatches(w, windows) / windows.length);
    }
    phiM /= windows.length;

    final windowsM1 = <List<double>>[];
    for (int i = 0; i <= intervals.length - (m + 1); i++) {
      windowsM1.add(intervals.sublist(i, i + m + 1));
    }
    for (final w in windowsM1) {
      phiM1 += log(countMatches(w, windowsM1) / windowsM1.length);
    }
    phiM1 /= windowsM1.length;

    return (phiM - phiM1).clamp(0.0, 2.0);
  }
}
