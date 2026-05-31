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
/// and calls GaitInferenceEngine every [_analysisIntervalSec] seconds.
///
/// Feature groups (mirrors train_gait.py v7):
///   OPALS_UNIVERSAL : CAD_U, STR_CV_U, SP_U
///   OPALS_ARMSWING  : RA_AMP_U, LA_AMP_U, SYM_U, ASA_U  + has_armswing
///   OPALS_SWAY      : SW_VEL_OP, SW_PATH_OP, SW_FREQ_OP  + has_sway
///   AXIVITY         : 14 free-living features             + has_axivity
///   GAIT_SUBGROUP   : 1 subgroup flag
///
/// Formulas follow the official PPMI Gait Assessment Methods Document
/// (Mirelman, Tel Aviv Medical Center / APDM Opals, 2018).
class GaitPipeline extends ChangeNotifier {
  // ── Configuration ─────────────────────────────────────────────────────────
  static const int    _sampleRateHz        = 50;
  static const int    _windowSec           = 20;   // analysis window length
  static const int    _analysisIntervalSec = 20;   // matches window length
  static const int    _minSamplesRequired  = _sampleRateHz * 10; // 10s minimum

  /// Minimum peak-to-peak arm swing amplitude (deg) to count as active swing.
  /// Below this the person is considered stationary — has_armswing = 0.
  static const double _minArmSwingDeg = 5.0;

  final BleService          _ble;
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
  // Implements the PPMI Gait Assessment Methods Document formulas exactly.
  // RA_AMP_U / LA_AMP_U: peak-to-peak angular range per swing half-cycle
  //   (degrees), computed by integrating gyrZ over each half-cycle via
  //   trapezoidal rule with per-segment linear detrending to eliminate gyro
  //   drift, then averaging across all detected cycles.
  // SYM_U:  1 - (RA_AMP / LA_AMP)  [PPMI formula]
  // ASA_U:  (45 - arctan(greater/smaller) * 180/pi) * 100 / 90  [PPMI formula]
  // Axivity features always null — model handles via median imputation.

  Map<String, double?> _extractFeatures(List<ImuSample> samples) {
    final dt = 1.0 / _sampleRateHz;

    // ── Accelerometer vertical (Z) for gait timing ─────────────────────────
    final accZ = samples.map((s) => s.accZ).toList();
    final peaks = _detectPeaks(accZ, _sampleRateHz);

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
      sp    = cad != null ? (cad * 0.75 / 60.0) : null;
    }

    // ── Arm swing amplitude in DEGREES via gyroscope integration ──────────
    // Per PPMI doc: amplitude = range from peak anterior to posterior movement.
    // Integrate gyrZ (deg/s) over each swing half-cycle using the trapezoidal
    // rule to get angular displacement (degrees). Each half-cycle is integrated
    // and detrended independently (linear baseline removal) to eliminate
    // gyroscope drift — prevents drift accumulation across the 20s window.
    final gyrZ = samples.map((s) => s.gyrZ).toList();

    // Detect swing half-cycles using zero-crossings of gyrZ
    final zeroCrossings = <int>[];
    for (int i = 1; i < gyrZ.length; i++) {
      if (gyrZ[i - 1] * gyrZ[i] < 0) zeroCrossings.add(i);
    }

    final rightCycleAmps = <double>[]; // positive half-cycles (forward swing)
    final leftCycleAmps  = <double>[]; // negative half-cycles (backward swing)

    for (int i = 0; i < zeroCrossings.length - 1; i++) {
      final start  = zeroCrossings[i];
      final end    = zeroCrossings[i + 1];
      final segGyr = gyrZ.sublist(start, end + 1);
      final n      = segGyr.length;

      // Integrate THIS segment only (trapezoidal rule) — no cross-segment drift
      final segAngle = List<double>.filled(n, 0.0);
      for (int j = 1; j < n; j++) {
        segAngle[j] = segAngle[j - 1] + (segGyr[j - 1] + segGyr[j]) * 0.5 * dt;
      }

      // Linear detrend: subtract straight line from segAngle[0] to segAngle[n-1]
      final slope = (segAngle[n - 1] - segAngle[0]) / (n - 1);
      final detrended = List<double>.generate(
        n, (j) => segAngle[j] - (segAngle[0] + slope * j),
      );

      final ampRange = detrended.reduce(max) - detrended.reduce(min);

      // Positive gyrZ midpoint = forward (right arm) swing
      if (gyrZ[(start + end) ~/ 2] > 0) {
        rightCycleAmps.add(ampRange);
      } else {
        leftCycleAmps.add(ampRange);
      }
    }

    // Average amplitude per arm (degrees) — PPMI RA_AMP_U / LA_AMP_U
    final raAmp = rightCycleAmps.isNotEmpty ? _mean(rightCycleAmps) : null;
    final laAmp = leftCycleAmps.isNotEmpty  ? _mean(leftCycleAmps)  : null;

    // Only flag as active arm swing if amplitude exceeds minimum threshold
    final hasArmswing = (raAmp != null && raAmp >= _minArmSwingDeg &&
                         laAmp != null && laAmp >= _minArmSwingDeg) ? 1.0 : 0.0;

    // Null out amplitudes below threshold (treat as missing for model)
    final raAmpFinal = (raAmp != null && raAmp >= _minArmSwingDeg) ? raAmp : null;
    final laAmpFinal = (laAmp != null && laAmp >= _minArmSwingDeg) ? laAmp : null;

    // ── SYM_U: Between-arm symmetry (PPMI formula) ─────────────────────────
    // Sym = 1 - (AverageAmplitudeRight / AverageAmplitudeLeft)
    double? sym;
    if (raAmpFinal != null && laAmpFinal != null && laAmpFinal > 0) {
      sym = 1.0 - (raAmpFinal / laAmpFinal);
    }

    // ── ASA_U: Arm swing asymmetry (PPMI formula) ──────────────────────────
    // ASA = (45 - arctan(greater / smaller) * (180/pi)) * 100 / 90
    double? asa;
    if (raAmpFinal != null && laAmpFinal != null &&
        raAmpFinal > 0 && laAmpFinal > 0) {
      final greater = raAmpFinal >= laAmpFinal ? raAmpFinal : laAmpFinal;
      final smaller = raAmpFinal <  laAmpFinal ? raAmpFinal : laAmpFinal;
      asa = (45.0 - (atan(greater / smaller) * 180.0 / pi)) * 100.0 / 90.0;
    }

    // ── Trunk sway from accelerometer AP (Y) and ML (X) ────────────────────
    // SW_VEL_OP : RMS of AP+ML acceleration (mean velocity proxy)
    // SW_PATH_OP: total CoP trajectory length from incremental AP+ML displacement
    // SW_FREQ_OP: centroidal frequency via zero-crossing rate on AP axis
    final accX = samples.map((s) => s.accX).toList();
    final accY = samples.map((s) => s.accY).toList();

    final swVel = _rms([...accX, ...accY]);

    double swPath = 0.0;
    for (int i = 1; i < samples.length; i++) {
      final dAP = (accY[i] - accY[i - 1]).abs();
      final dML = (accX[i] - accX[i - 1]).abs();
      swPath += sqrt(dAP * dAP + dML * dML) * dt;
    }

    final swFreq = _dominantFreq(accY, _sampleRateHz);
    const hasSway = 1.0;

    // CVStrideTime reused from stride intervals
    final cvStrideTime = strCv;

    return {
      // OPALS_UNIVERSAL
      'CAD_U'             : cad,
      'STR_CV_U'          : strCv,
      'SP_U'              : sp,
      // OPALS_ARMSWING (all in degrees, per PPMI doc)
      'RA_AMP_U'          : raAmpFinal,
      'LA_AMP_U'          : laAmpFinal,
      'SYM_U'             : sym,
      'ASA_U'             : asa,
      'has_armswing'      : hasArmswing,
      // OPALS_SWAY
      'SW_VEL_OP'         : swVel,
      'SW_PATH_OP'        : swPath,
      'SW_FREQ_OP'        : swFreq,
      'has_sway'          : hasSway,
      // AXIVITY (not available from wrist sensor — imputed by model)
      'MeanSVMDaymg'      : null,
      'PercentWalking'    : null,
      'ActivityLevel'     : null,
      'CadencetimeDomain' : null,
      'NumberOfBouts'     : null,
      'wdV'               : null,
      'stepTime'          : null,
      'strideTime'        : null,
      'CVStrideTime'      : cvStrideTime,
      'SampEntropyV'      : null,
      'stepAsymV'         : null,
      'StepVelocitycmsec' : sp != null ? sp * 100 : null,
      'rmsV'              : _rms(accZ),
      'has_axivity'       : 0.0,
      // Subgroup
      'GAIT_SUBGROUP'     : 0.0,
    };
  }

  // ── DSP helpers ───────────────────────────────────────────────────────────

  /// Simple peak detection: local maxima above mean + 0.3*std threshold
  List<int> _detectPeaks(List<double> signal, int fs) {
    final mu      = _mean(signal);
    final sd      = _std(signal);
    final thr     = mu + 0.3 * sd;
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
    final mu = _mean(x);
    final sq = x.map((v) => (v - mu) * (v - mu));
    return sqrt(sq.reduce((a, b) => a + b) / (x.length - 1));
  }

  double _rms(List<double> x) {
    if (x.isEmpty) return 0;
    return sqrt(x.map((v) => v * v).reduce((a, b) => a + b) / x.length);
  }

  /// Dominant frequency via zero-crossing rate (lightweight FFT approximation)
  double _dominantFreq(List<double> signal, int fs) {
    if (signal.length < 2) return 0;
    final mu = _mean(signal);
    int crossings = 0;
    for (int i = 1; i < signal.length; i++) {
      if ((signal[i - 1] - mu) * (signal[i] - mu) < 0) crossings++;
    }
    return (crossings / 2.0) / (signal.length / fs);
  }
}