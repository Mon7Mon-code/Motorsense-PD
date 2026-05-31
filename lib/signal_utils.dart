import 'dart:math';

double signalMean(List<double> x) {
  if (x.isEmpty) return 0;
  return x.reduce((a, b) => a + b) / x.length;
}

double signalStd(List<double> x) {
  if (x.length < 2) return 0;
  final mu = signalMean(x);
  return sqrt(x.map((v) => (v - mu) * (v - mu)).reduce((a, b) => a + b) / (x.length - 1));
}

double signalRms(List<double> x) {
  if (x.isEmpty) return 0;
  return sqrt(x.map((v) => v * v).reduce((a, b) => a + b) / x.length);
}

/// Goertzel algorithm — DFT power at a specific frequency.
/// More efficient than FFT when only a small number of bins are needed.
double goertzelPower(List<double> signal, int fs, double freqHz) {
  final N = signal.length;
  if (N == 0) return 0;
  final k = N * freqHz / fs;
  final coeff = 2 * cos(2 * pi * k / N);
  double s1 = 0, s2 = 0;
  for (final x in signal) {
    final s0 = x + coeff * s1 - s2;
    s2 = s1;
    s1 = s0;
  }
  return s1 * s1 + s2 * s2 - coeff * s1 * s2;
}

/// Sum of Goertzel powers for all DFT bins in [lowHz, highHz].
double bandPower(List<double> signal, int fs, double lowHz, double highHz) {
  final N = signal.length;
  if (N == 0) return 0;
  final resolution = fs / N;
  final lowBin  = (lowHz  / resolution).round().clamp(0, N ~/ 2);
  final highBin = (highHz / resolution).round().clamp(0, N ~/ 2);
  double power = 0;
  for (int bin = lowBin; bin <= highBin; bin++) {
    power += goertzelPower(signal, fs, bin * resolution);
  }
  return power;
}

/// Total power from DC to Nyquist.
double totalPower(List<double> signal, int fs) =>
    bandPower(signal, fs, 0, fs / 2);

/// Returns the frequency in [lowHz, highHz] with peak Goertzel power.
double dominantFreqInBand(List<double> signal, int fs, double lowHz, double highHz) {
  final N = signal.length;
  if (N == 0) return lowHz;
  final resolution = fs / N;
  final lowBin  = (lowHz  / resolution).round().clamp(0, N ~/ 2);
  final highBin = (highHz / resolution).round().clamp(0, N ~/ 2);
  double maxPow = -1;
  double maxFreq = lowHz;
  for (int bin = lowBin; bin <= highBin; bin++) {
    final f = bin * resolution;
    final p = goertzelPower(signal, fs, f);
    if (p > maxPow) { maxPow = p; maxFreq = f; }
  }
  return maxFreq;
}

/// Local-maxima peak detector — returns indices of peaks above mean + 0.3*std
/// with a minimum inter-peak distance of [minSpacingSec] seconds.
List<int> detectPeaks(List<double> signal, int fs, {double minSpacingSec = 0.35}) {
  final mu  = signalMean(signal);
  final sd  = signalStd(signal);
  final thr = mu + 0.3 * sd;
  final minDist = (fs * minSpacingSec).round();

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

/// Zero-crossing rate estimate of dominant frequency (lightweight approximation).
double zeroCrossFreq(List<double> signal, int fs) {
  if (signal.length < 2) return 0;
  final mu = signalMean(signal);
  int crossings = 0;
  for (int i = 1; i < signal.length; i++) {
    if ((signal[i - 1] - mu) * (signal[i] - mu) < 0) crossings++;
  }
  return (crossings / 2.0) / (signal.length / fs);
}
