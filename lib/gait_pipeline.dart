import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'ble_service.dart';
import 'gait_inference.dart';

/// One complete gait analysis result
class GaitAnalysisResult {
  final double probability;
  final bool isImpaired;
  final int severityLevel;       // 0=healthy,1=mild,2=moderate,3=severe,4=very severe
  final String severityLabel;
  final DateTime timestamp;
  final int samplesUsed;

  GaitAnalysisResult({
    required this.probability,
    required this.isImpaired,
    required this.severityLevel,
    required this.severityLabel,
    required this.timestamp,
    required this.samplesUsed,
  });

  @override
  String toString() =>
      'GaitAnalysisResult(prob=${probability.toStringAsFixed(3)}, '
      'severity=$severityLevel/$severityLabel, samples=$samplesUsed)';
}

/// Buffers raw IMU samples from BleService, extracts the 27-feature vector,
/// and calls GaitInferenceEngine every [analysisIntervalSec] seconds.
///
/// Feature groups (mirrors train_gait.py v7):
///   OPALS_UNIVERSAL : CAD_U, STR_CV_U, SP_U
///   OPALS_ARMSWING  : RA_AMP_U, LA_AMP_U, SYM_U, ASA_U  + has_armswing
///   OPALS_SWAY      : SW_VEL_OP, SW_PATH_OP, SW_FREQ_OP  + has_sway
///   AXIVITY         : 14 free-living features             + has_axivity
///   GAIT_SUBGROUP   : 1 subgroup flag
class GaitPipeline extends ChangeNotifier {
  // ── Configuration ─────────────────────────────────────────────────────────
  static const int    _sampleRateHz        = 50;
  static const int    _windowSec           = 20;   // analysis window length
  static const int    _analysisIntervalSec = 30;   // how often to run inference
  static const int    _minSamplesRequired  = _sampleRateHz * 10; // 10s minimum

  final BleService         _ble;
  final GaitInferenceEngine _engine;

  // ── State ─────────────────────────────────────────────────────────────────
  final List<ImuSample> _buffer = [];
  StreamSubscription<ImuSample>? _sub;
  Timer?  _analysisTimer;
  bool    _engineReady = false;
  String? _lastError;

  GaitAnalysisResult? _latestResult;
  bool   _isAnalysing = false;

  GaitAnalysisResult? get latestResult  => _latestResult;
  bool                get isAnalysing   => _isAnalysing;
  String?             get lastError     => _lastError;
  int                 get bufferSize    => _buffer.length;
  bool                get engineReady   => _engineReady;

  // ── Output stream ─────────────────────────────────────────────────────────
  final _resultController = StreamController<GaitAnalysisResult>.broadcast();
  Stream<GaitAnalysisResult> get resultStream => _resultController.stream;

  // ── Constructor ───────────────────────────────────────────────────────────
  GaitPipeline({required BleService ble, required GaitInferenceEngine engine})
      : _ble    = ble,
        _engine = engine;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      await _engine.init();
      _engineReady = true;
      debugPrint('[GaitPipeline] Engine initialised');
    } catch (e) {
      _lastError = 'Engine init failed: $e';
      debugPrint('[GaitPipeline] $_lastError');
    }
    notifyListeners();
  }

  void start() {
    if (!_engineReady) {
      _lastError = 'Engine not ready — call init() first';
      notifyListeners();
      return;
    }

    // Subscribe to BLE sample stream
    _sub = _ble.sampleStream.listen(_onSample);

    // Run analysis every N seconds
    _analysisTimer = Timer.periodic(
      Duration(seconds: _analysisIntervalSec),
      (_) => _runAnalysis(),
    );

    debugPrint('[GaitPipeline] Started');
    notifyListeners();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _buffer.clear();
    debugPrint('[GaitPipeline] Stopped');
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _resultController.close();
    super.dispose();
  }

  // ── Sample ingestion ──────────────────────────────────────────────────────

  void _onSample(ImuSample sample) {
    _buffer.add(sample);
    // Keep only the last [_windowSec] seconds worth of samples
    final maxSamples = _sampleRateHz * _windowSec;
    if (_buffer.length > maxSamples) {
      _buffer.removeRange(0, _buffer.length - maxSamples);
    }
  }

  // ── Feature extraction & inference ────────────────────────────────────────

  Future<void> _runAnalysis() async {
    if (_buffer.length < _minSamplesRequired) {
      debugPrint('[GaitPipeline] Not enough samples yet: ${_buffer.length}');
      return;
    }
    if (_isAnalysing) return;

    _isAnalysing = true;
    notifyListeners();

    try {
      final snapshot = List<ImuSample>.from(_buffer);
      final features = _extractFeatures(snapshot);
      final result   = await _engine.predict(features);

      _latestResult = result;
      _resultController.add(result);
      _lastError = null;
      debugPrint('[GaitPipeline] $result');
    } catch (e) {
      _lastError = 'Analysis failed: $e';
      debugPrint('[GaitPipeline] $_lastError');
    } finally {
      _isAnalysing = false;
      notifyListeners();
    }
  }

  /// Trigger an immediate analysis (e.g. for UI "Analyse Now" button)
  Future<void> analyseNow() => _runAnalysis();

  // ── Feature extraction ────────────────────────────────────────────────────
  //
  // From the raw IMU buffer we compute a best-effort approximation of the
  // 27 features the model was trained on.  Axivity features (free-living,
  // 24-hour wear) are always null here — the model was trained to handle this
  // via median imputation. Arm swing uses right-wrist gyroscope (gyrZ).

  Map<String, double?> _extractFeatures(List<ImuSample> samples) {
    final n = samples.length.toDouble();

    // ── Accelerometer vertical (Z) for gait timing ─────────────────────────
    final accZ = samples.map((s) => s.accZ).toList();
    final peaks = _detectPeaks(accZ, _sampleRateHz);

    // Cadence (steps/min)
    double? cad;
    double? strCv;
    double? sp;
    if (peaks.length >= 4) {
      final intervals = <double>[];
      for (int i = 1; i < peaks.length; i++) {
        intervals.add((peaks[i] - peaks[i - 1]) / _sampleRateHz);
      }
      final meanInterval = _mean(intervals);
      cad   = meanInterval > 0 ? (60.0 / meanInterval) : null;
      strCv = meanInterval > 0 ? (_std(intervals) / meanInterval * 100) : null;

      // Walking speed proxy: cadence × 0.75m (avg step length)
      sp = cad != null ? (cad * 0.75 / 60.0) : null;
    }

    // ── Arm swing from wrist gyroscope Z ───────────────────────────────────
    final gyrZ = samples.map((s) => s.gyrZ).toList();
    final gyrZPos = gyrZ.where((v) => v > 0).toList();
    final gyrZNeg = gyrZ.where((v) => v < 0).toList();

    final raAmp = gyrZPos.isNotEmpty ? _mean(gyrZPos) : null;
    final laAmp = gyrZNeg.isNotEmpty ? _mean(gyrZNeg.map((v) => v.abs()).toList()) : null;

    double? sym;
    double? asa;
    if (raAmp != null && laAmp != null && (raAmp + laAmp) > 0) {
      sym = 1.0 - ((raAmp - laAmp).abs() / (raAmp + laAmp));
      asa = (raAmp - laAmp).abs();
    }

    final hasArmswing = (raAmp != null && laAmp != null) ? 1.0 : 0.0;

    // ── Trunk sway from accelerometer X (mediolateral) ─────────────────────
    final accX = samples.map((s) => s.accX).toList();
    final swVel  = _rms(accX);                           // RMS ≈ sway velocity proxy
    final swPath = accX.map((v) => v.abs()).reduce((a, b) => a + b) / n;
    final swFreq = _dominantFreq(accX, _sampleRateHz);
    final hasSway = 1.0;

    // ── CVStrideTime (Axivity-derived, but we can estimate from wrist) ──────
    final cvStrideTime = strCv; // reuse stride CV from peaks

    return {
      // OPALS_UNIVERSAL
      'CAD_U'              : cad,
      'STR_CV_U'           : strCv,
      'SP_U'               : sp,
      // OPALS_ARMSWING
      'RA_AMP_U'           : raAmp,
      'LA_AMP_U'           : laAmp,
      'SYM_U'              : sym,
      'ASA_U'              : asa,
      'has_armswing'       : hasArmswing,
      // OPALS_SWAY
      'SW_VEL_OP'          : swVel,
      'SW_PATH_OP'         : swPath,
      'SW_FREQ_OP'         : swFreq,
      'has_sway'           : hasSway,
      // AXIVITY (not available from wrist sensor alone — imputed by model)
      'MeanSVMDaymg'       : null,
      'PercentWalking'     : null,
      'ActivityLevel'      : null,
      'CadencetimeDomain'  : null,
      'NumberOfBouts'      : null,
      'wdV'                : null,
      'stepTime'           : null,
      'strideTime'         : null,
      'CVStrideTime'       : cvStrideTime,
      'SampEntropyV'       : null,
      'stepAsymV'          : null,
      'StepVelocitycmsec'  : sp != null ? sp * 100 : null,
      'rmsV'               : _rms(samples.map((s) => s.accZ).toList()),
      'has_axivity'        : 0.0,
      // Subgroup
      'GAIT_SUBGROUP'      : 0.0,
    };
  }

  // ── DSP helpers ───────────────────────────────────────────────────────────

  /// Simple peak detection: local maxima above mean + threshold
  List<int> _detectPeaks(List<double> signal, int fs) {
    final mu  = _mean(signal);
    final sd  = _std(signal);
    final thr = mu + 0.3 * sd;
    final minDist = (fs * 0.35).round(); // min 350ms between peaks

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

  double _mean(List<double> x) {
    if (x.isEmpty) return 0;
    return x.reduce((a, b) => a + b) / x.length;
  }

  double _std(List<double> x) {
    if (x.length < 2) return 0;
    final mu  = _mean(x);
    final sq  = x.map((v) => (v - mu) * (v - mu));
    return sqrt(sq.reduce((a, b) => a + b) / (x.length - 1));
  }

  double _rms(List<double> x) {
    if (x.isEmpty) return 0;
    return sqrt(x.map((v) => v * v).reduce((a, b) => a + b) / x.length);
  }

  /// Dominant frequency via zero-crossing rate (lightweight, no FFT needed)
  double _dominantFreq(List<double> signal, int fs) {
    if (signal.length < 2) return 0;
    final mu = _mean(signal);
    int crossings = 0;
    for (int i = 1; i < signal.length; i++) {
      if ((signal[i - 1] - mu) * (signal[i] - mu) < 0) crossings++;
    }
    // Each pair of crossings = one full cycle
    return (crossings / 2.0) / (signal.length / fs);
  }
}
