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

/// Tremor + dyskinesia pipeline — two separate input paths, one output.
///
/// Tremor    → firmware classifies and sends a CSV row → call [ingestReading].
/// Dyskinesia → app computes from raw IMU via Goertzel (1–3 Hz) every 2 s.
///
/// Both paths write to the same [TremorResult] output stream so callers and
/// UI are unaware of which path produced each field.
class TremorPipeline extends ChangeNotifier {
  // ── Configuration ──────────────────────────────────────────────────────────
  static const int    _sampleRateHz        = 50;
  static const int    _windowSamples       = 200;  // 4 s @ 50 Hz
  static const int    _analysisIntervalSec = 2;    // dyskinesia analysis cadence
  static const int    _minSamples          = 100;  // 2 s minimum before first analysis
  static const int    _episodeCooldownSec  = 30;   // min gap between logged episodes

  // Dyskinesia band only — tremor band is handled by firmware.
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

  // Last tremor values received from firmware CSV.
  // Carried forward into every dyskinesia timer result so the UI
  // always shows the most recent tremor classification alongside
  // the freshly computed dyskinesia value.
  int    _csvTremorSeverity = 0;
  String _csvTremorLabel    = 'Normal';
  double _csvTremorHz       = 0.0;
  double _csvTremorAmp      = 0.0;

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

    // Save so _analyse() carries these forward into every dyskinesia tick.
    _csvTremorSeverity = tremorSev;
    _csvTremorLabel    = _kSeverityLabels[tremorSev];
    _csvTremorHz       = reading.domFreq.toDouble();
    _csvTremorAmp      = reading.axRms;

    // Dyskinesia: use latest value from the IMU timer path.
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

  // ── Analysis (dyskinesia only) ──────────────────────────────────────────────
  // Tremor is NOT computed here — it comes from the firmware CSV via
  // ingestReading(). This method only updates dyskinesia from raw IMU and
  // carries forward the last known CSV tremor values.

  void _analyse() {
    if (_buffer.length < _minSamples) return;

    final snapshot = List<ImuSample>.from(_buffer);

    final gyroMag = snapshot.map((s) =>
        sqrt(s.gyrX * s.gyrX + s.gyrY * s.gyrY + s.gyrZ * s.gyrZ)).toList();
    final accMag = snapshot.map((s) =>
        sqrt(s.accX * s.accX + s.accY * s.accY + s.accZ * s.accZ)).toList();
    final fused = List<double>.generate(
      snapshot.length,
      (i) => 0.7 * gyroMag[i] + 0.3 * accMag[i],
    );

    final total = totalPower(fused, _sampleRateHz);
    if (total < 1e-6) return;

    final dyskinSev = _toSeverity(
      bandPower(fused, _sampleRateHz, _dyskinLowHz, _dyskinHighHz) / total,
    );

    final now = DateTime.now();
    final result = TremorResult(
      // Tremor: carry forward last CSV values (firmware owns this).
      tremorSeverity:     _csvTremorSeverity,
      tremorLabel:        _csvTremorLabel,
      tremorFrequencyHz:  _csvTremorHz,
      tremorAmplitude:    _csvTremorAmp,
      // Dyskinesia: freshly computed from raw IMU.
      dyskinesiaSeverity: dyskinSev,
      dyskinesiaLabel:    _kSeverityLabels[dyskinSev],
      timestamp:          now,
    );

    _latest = result;
    _resultController.add(result);
    _lastError = null;

    _tremorTrend.add((now, _csvTremorSeverity));
    final cutoff = now.subtract(const Duration(days: 7));
    _tremorTrend.removeWhere((e) => e.$1.isBefore(cutoff));

    _maybeLogEpisode(result, now);
    debugPrint('[TremorPipeline] (dyskinesia tick) $result');
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
