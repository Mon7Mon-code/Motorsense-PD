import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'ble_service.dart';
import 'signal_utils.dart';

const List<String> _kSeverityLabels = [
  'Normal', 'Mild', 'Moderate', 'Severe', 'Very Severe'
];

/// Result of one tremor + dyskinesia analysis window.
class TremorResult {
  final int tremorSeverity;        // 0–4
  final String tremorLabel;
  final double tremorFrequencyHz;  // dominant frequency within 3.5–7.5 Hz
  final double tremorAmplitude;    // RMS gyro magnitude weighted by band ratio (°/s)
  final int dyskinesiaSeverity;    // 0–4
  final String dyskinesiaLabel;
  final DateTime timestamp;

  TremorResult({
    required this.tremorSeverity,
    required this.tremorLabel,
    required this.tremorFrequencyHz,
    required this.tremorAmplitude,
    required this.dyskinesiaSeverity,
    required this.dyskinesiaLabel,
    required this.timestamp,
  });

  @override
  String toString() =>
      'TremorResult(tremor=$tremorSeverity/$tremorLabel '
      '@${tremorFrequencyHz.toStringAsFixed(1)}Hz, '
      'dyskinesia=$dyskinesiaSeverity/$dyskinesiaLabel)';
}

/// Processed tremor feature row — matches the upstream CSV/BLE output format.
///
/// Fields mirror the columns produced by the hardware-side tremor processor
/// or a companion Python script:
///   ax_rms    – overall motion strength in m/s²
///   log_power – log₁₀ of power in the 4–6 Hz tremor band
///   dom_freq  – dominant frequency in Hz (integer, clamped 1–10)
///   p_tremor  – model confidence [0, 1]
///   severity  – 'NONE' | 'MILD' | 'MODERATE' | 'SEVERE'
class TremorReading {
  final double axRms;
  final double logPower;
  final int    domFreq;   // Hz, integer 1–10
  final double pTremor;   // model confidence [0, 1]
  final String severity;  // 'NONE' | 'MILD' | 'MODERATE' | 'SEVERE'

  const TremorReading({
    required this.axRms,
    required this.logPower,
    required this.domFreq,
    required this.pTremor,
    required this.severity,
  });

  /// Parse from a CSV line: "ax_rms,log_power,dom_freq,p_tremor,severity"
  factory TremorReading.fromCsvRow(String line) {
    final parts = line.trim().split(',');
    if (parts.length < 5) {
      throw FormatException('Expected 5 CSV columns, got ${parts.length}: $line');
    }
    return TremorReading(
      axRms:    double.parse(parts[0]),
      logPower: double.parse(parts[1]),
      domFreq:  double.parse(parts[2]).round().clamp(1, 10),
      pTremor:  double.parse(parts[3]).clamp(0.0, 1.0),
      severity: parts[4].trim().toUpperCase(),
    );
  }

  /// Parse from a map (e.g. decoded JSON or BLE structured payload).
  factory TremorReading.fromMap(Map<String, dynamic> m) {
    return TremorReading(
      axRms:    (m['ax_rms']    as num).toDouble(),
      logPower: (m['log_power'] as num).toDouble(),
      domFreq:  (m['dom_freq']  as num).round().clamp(1, 10),
      pTremor:  (m['p_tremor']  as num).toDouble().clamp(0.0, 1.0),
      severity: (m['severity']  as String).trim().toUpperCase(),
    );
  }

  @override
  String toString() =>
      'TremorReading(axRms=${axRms.toStringAsFixed(3)}, '
      'logPower=${logPower.toStringAsFixed(3)}, '
      'domFreq=$domFreq Hz, pTremor=${pTremor.toStringAsFixed(3)}, '
      'severity=$severity)';
}

/// A symptom episode detected automatically (used by SymptomsScreen).
class DetectedEpisode {
  final String symptomType;    // 'Tremor' or 'Dyskinesia'
  final int severityLevel;
  final String severityLabel;
  final DateTime detectedAt;

  DetectedEpisode({
    required this.symptomType,
    required this.severityLevel,
    required this.severityLabel,
    required this.detectedAt,
  });
}

/// Tremor + dyskinesia detector using Goertzel band-power analysis.
///
/// Pipeline (runs every [_analysisIntervalSec] seconds on a rolling window):
///   1. Compute fused gyro magnitude (primary) + accel magnitude (secondary).
///   2. Apply Goertzel band-power at:
///        Tremor band    : 3.5 – 7.5 Hz  (rest/action tremor)
///        Dyskinesia band: 1.0 – 3.0 Hz  (involuntary low-freq movement)
///   3. Map band-power ratio to severity 0–4.
///   4. Debounce-log episodes for the Symptoms screen.
class TremorPipeline extends ChangeNotifier {
  // ── Configuration ──────────────────────────────────────────────────────────
  static const int    _sampleRateHz       = 50;
  static const int    _windowSamples      = 200;  // 4 s @ 50 Hz
  static const int    _analysisIntervalSec = 2;   // 50% overlap with window
  static const int    _minSamples         = 100;  // 2 s minimum before first analysis
  static const int    _episodeCooldownSec = 30;   // min gap between logged episodes

  static const double _tremorLowHz  = 3.5;
  static const double _tremorHighHz = 7.5;
  static const double _dyskinLowHz  = 1.0;
  static const double _dyskinHighHz = 3.0;

  // Band-power ratio thresholds for severity 1–4.
  // Empirical starting points — tune with real patient data.
  static const List<double> _thresholds = [0.05, 0.15, 0.30, 0.50];

  // ── Dependencies ───────────────────────────────────────────────────────────
  final BleService _ble;

  // ── Internal state ─────────────────────────────────────────────────────────
  final List<ImuSample> _buffer = [];
  StreamSubscription<ImuSample>? _sub;
  Timer? _timer;

  TremorResult? _latest;
  String?       _lastError;
  DateTime?     _lastTremorEpisodeAt;
  DateTime?     _lastDyskinEpisodeAt;

  // Auto-detected episodes (newest first) — read by SymptomsScreen.
  final List<DetectedEpisode> _episodes = [];

  // 7-day rolling trend: list of (timestamp, tremorSeverity) pairs.
  final List<(DateTime, int)> _tremorTrend = [];

  // ── Public getters ─────────────────────────────────────────────────────────
  TremorResult?          get latestResult => _latest;
  String?                get lastError    => _lastError;
  List<DetectedEpisode>  get episodes     => List.unmodifiable(_episodes);
  List<(DateTime, int)>  get tremorTrend  => List.unmodifiable(_tremorTrend);

  // ── Output stream ──────────────────────────────────────────────────────────
  final _resultController = StreamController<TremorResult>.broadcast();
  Stream<TremorResult> get resultStream => _resultController.stream;

  // ── Constructor ────────────────────────────────────────────────────────────
  TremorPipeline({required BleService ble}) : _ble = ble;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void start() {
    _sub  = _ble.sampleStream.listen(_onSample);
    _timer = Timer.periodic(
      Duration(seconds: _analysisIntervalSec),
      (_) => _analyse(),
    );
    debugPrint('[TremorPipeline] Started');
    notifyListeners();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    _buffer.clear();
    debugPrint('[TremorPipeline] Stopped');
    notifyListeners();
  }

  // ── Processed-feature input path ───────────────────────────────────────────
  //
  // Call this when upstream (firmware or Python companion) has already computed
  // tremor features, instead of letting the Goertzel timer do it from raw IMU.
  // Both paths produce identical TremorResult output — callers and UI are
  // unaware of which path was used.

  /// Ingest a pre-processed [TremorReading] and emit it as a [TremorResult].
  ///
  /// Dyskinesia severity is preserved from the previous result when not
  /// supplied by the upstream processor (the tremor CSV has no dyskinesia
  /// column), so the UI never regresses to zero unexpectedly.
  void ingestReading(TremorReading reading) {
    final tremorSev = _severityFromString(reading.severity);
    // Preserve last known dyskinesia severity — CSV format doesn't include it.
    final dyskinSev = _latest?.dyskinesiaSeverity ?? 0;

    final now = DateTime.now();
    final result = TremorResult(
      tremorSeverity:     tremorSev,
      tremorLabel:        _kSeverityLabels[tremorSev],
      tremorFrequencyHz:  reading.domFreq.toDouble(),
      tremorAmplitude:    reading.axRms,
      dyskinesiaSeverity: dyskinSev,
      dyskinesiaLabel:    _kSeverityLabels[dyskinSev],
      timestamp:          now,
    );

    _latest = result;
    _resultController.add(result);
    _lastError = null;

    _tremorTrend.add((now, tremorSev));
    final cutoff = now.subtract(const Duration(days: 7));
    _tremorTrend.removeWhere((e) => e.$1.isBefore(cutoff));

    _maybeLogEpisode(result, now);

    debugPrint('[TremorPipeline] ingested $reading → $result');
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _resultController.close();
    super.dispose();
  }

  // ── Sample ingestion ────────────────────────────────────────────────────────

  void _onSample(ImuSample s) {
    _buffer.add(s);
    if (_buffer.length > _windowSamples) {
      _buffer.removeRange(0, _buffer.length - _windowSamples);
    }
  }

  // ── Analysis ────────────────────────────────────────────────────────────────

  void _analyse() {
    if (_buffer.length < _minSamples) return;

    final snapshot = List<ImuSample>.from(_buffer);

    // Fused gyro magnitude — rotation is the primary tremor carrier at the wrist.
    final gyroMag = snapshot.map((s) {
      return sqrt(s.gyrX * s.gyrX + s.gyrY * s.gyrY + s.gyrZ * s.gyrZ);
    }).toList();

    // Fused accel magnitude — adds linear displacement component.
    final accMag = snapshot.map((s) {
      return sqrt(s.accX * s.accX + s.accY * s.accY + s.accZ * s.accZ);
    }).toList();

    // Weighted fused signal (gyro dominant, accel supplementary).
    final fused = List<double>.generate(
      snapshot.length,
      (i) => 0.7 * gyroMag[i] + 0.3 * accMag[i],
    );

    final total = totalPower(fused, _sampleRateHz);
    if (total < 1e-6) return; // silent signal — no meaningful analysis

    final tremorPow  = bandPower(fused, _sampleRateHz, _tremorLowHz, _tremorHighHz);
    final dyskinPow  = bandPower(fused, _sampleRateHz, _dyskinLowHz, _dyskinHighHz);

    final tremorRatio = tremorPow  / total;
    final dyskinRatio = dyskinPow  / total;

    final tremorSev = _toSeverity(tremorRatio);
    final dyskinSev = _toSeverity(dyskinRatio);

    final tremorHz  = dominantFreqInBand(
      fused, _sampleRateHz, _tremorLowHz, _tremorHighHz,
    );
    // Amplitude: RMS gyro magnitude weighted by tremor band contribution.
    final tremorAmp = signalRms(gyroMag) * tremorRatio;

    final now = DateTime.now();
    final result = TremorResult(
      tremorSeverity:     tremorSev,
      tremorLabel:        _kSeverityLabels[tremorSev],
      tremorFrequencyHz:  tremorHz,
      tremorAmplitude:    tremorAmp,
      dyskinesiaSeverity: dyskinSev,
      dyskinesiaLabel:    _kSeverityLabels[dyskinSev],
      timestamp:          now,
    );

    _latest = result;
    _resultController.add(result);
    _lastError = null;

    // 7-day rolling trend (keep only last 7 days).
    _tremorTrend.add((now, tremorSev));
    final cutoff = now.subtract(const Duration(days: 7));
    _tremorTrend.removeWhere((e) => e.$1.isBefore(cutoff));

    _maybeLogEpisode(result, now);

    debugPrint('[TremorPipeline] $result');
    notifyListeners();
  }

  // ── Episode logging (debounced) ─────────────────────────────────────────────

  void _maybeLogEpisode(TremorResult result, DateTime now) {
    final cooldown = Duration(seconds: _episodeCooldownSec);

    if (result.tremorSeverity >= 1) {
      if (_lastTremorEpisodeAt == null ||
          now.difference(_lastTremorEpisodeAt!) > cooldown) {
        _lastTremorEpisodeAt = now;
        _episodes.insert(0, DetectedEpisode(
          symptomType:   'Tremor',
          severityLevel: result.tremorSeverity,
          severityLabel: result.tremorLabel,
          detectedAt:    now,
        ));
      }
    }

    if (result.dyskinesiaSeverity >= 1) {
      if (_lastDyskinEpisodeAt == null ||
          now.difference(_lastDyskinEpisodeAt!) > cooldown) {
        _lastDyskinEpisodeAt = now;
        _episodes.insert(0, DetectedEpisode(
          symptomType:   'Dyskinesia',
          severityLevel: result.dyskinesiaSeverity,
          severityLabel: result.dyskinesiaLabel,
          detectedAt:    now,
        ));
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  int _toSeverity(double ratio) {
    for (int i = _thresholds.length - 1; i >= 0; i--) {
      if (ratio >= _thresholds[i]) return i + 1;
    }
    return 0;
  }

  /// Adapter: maps upstream severity string to the 0–4 int scale used
  /// throughout the app. 'SEVERE' maps to 3; 'VERY SEVERE' (not in the CSV
  /// format) remains reserved for the Goertzel path.
  static int _severityFromString(String s) {
    switch (s.toUpperCase()) {
      case 'MILD':     return 1;
      case 'MODERATE': return 2;
      case 'SEVERE':   return 3;
      case 'NONE':
      default:         return 0;
    }
  }
}
