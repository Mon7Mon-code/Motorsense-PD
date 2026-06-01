import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'ble_service.dart';
import 'gait_dsp.dart';
import 'gait_inference.dart';
import 'signal_utils.dart';
import 'bradykinesia_gait.dart';
import 'gait_validation.dart';
import 'phone_sensor_service.dart';
import 'sensor_config.dart';

/// One complete gait analysis result
class GaitAnalysisResult {
  final double probability;
  final bool isImpaired;
  final int severityLevel;        // 0=healthy,1=mild,2=moderate,3=severe,4=very severe
  final String severityLabel;
  final DateTime timestamp;
  final int samplesUsed;
  final GaitValidationMetrics validation;
  final Map<String, double?> features;
  final BradykinesiaGaitResult bradykinesia;

  // Raw feature values exposed for downstream use (bradykinesia, UI display).
  final double? cadenceStepsPerMin;
  final double? armSwingAmplitudeDeg; // RA_AMP_U (right arm, degrees)
  final double? strideTimeCV;         // coefficient of variation (%)
  final double? walkingSpeedMs;       // estimated walking speed (m/s)

  GaitAnalysisResult({
    required this.probability,
    required this.isImpaired,
    required this.severityLevel,
    required this.severityLabel,
    required this.timestamp,
    required this.samplesUsed,
    required this.validation,
    required this.features,
    required this.bradykinesia,
    this.cadenceStepsPerMin,
    this.armSwingAmplitudeDeg,
    this.strideTimeCV,
    this.walkingSpeedMs,
  });

  /// Bradykinesia severity inferred from cadence and arm swing amplitude.
  /// Thresholds are based on published Parkinson's gait norms.
  int get bradykinesiaSeverity {
    final cad = cadenceStepsPerMin;
    final arm = armSwingAmplitudeDeg;
    if (cad == null && arm == null) return 0;
    if ((cad != null && cad < 50)  || (arm != null && arm < 2))  return 4;
    if ((cad != null && cad < 70)  || (arm != null && arm < 5))  return 3;
    if ((cad != null && cad < 85)  || (arm != null && arm < 10)) return 2;
    if ((cad != null && cad < 100) || (arm != null && arm < 15)) return 1;
    return 0;
  }

  String get bradykinesiaLabel =>
      const ['Normal', 'Mild', 'Moderate', 'Severe', 'Very Severe'][bradykinesiaSeverity];

  @override
  String toString() =>
      'GaitAnalysisResult(prob=${probability.toStringAsFixed(3)}, '
      'severity=$severityLevel/$severityLabel, '
      'bradykinesia=${bradykinesia.level}/${bradykinesia.label}, '
      'samples=$samplesUsed, steps=${validation.stepCount})';
}

/// Dual-sensor gait pipeline: wrist BLE (XIAO) + phone accelerometer.
///
/// Cadence, stride variability, walking speed, and Axivity-style step metrics
/// are derived from the phone. Arm swing, symmetry, and sway use the wrist IMU.
class GaitPipeline extends ChangeNotifier {
  static const int _windowSec = SensorConfig.gaitWindowSec;
  static const int _analysisIntervalSec = SensorConfig.gaitWindowSec;
  static const int _minSamplesRequired =
      SensorConfig.xiaoLsm6ds3OdrHz * SensorConfig.gaitMinBufferSec;

  static const double _minArmSwingDeg = 5.0;
  static const double _avgStepLengthM = 0.75;

  final BleService _ble;
  final PhoneSensorService _phone;
  final GaitInferenceEngine _engine;
  final BradykinesiaGaitScorer _bradykinesiaScorer;

  final List<ImuSample> _wristBuffer = [];
  final List<PhoneAccelSample> _phoneBuffer = [];
  StreamSubscription<ImuSample>? _wristSub;
  StreamSubscription<PhoneAccelSample>? _phoneSub;
  Timer? _analysisTimer;
  bool _engineReady = false;
  String? _lastError;

  GaitAnalysisResult? _latestResult;
  bool _isAnalysing = false;

  // 7-day rolling trend: (timestamp, bradykinesiaSeverity) pairs.
  final List<(DateTime, int)> _bradykinesiaTrend = [];

  GaitAnalysisResult?    get latestResult      => _latestResult;
  bool                   get isAnalysing       => _isAnalysing;
  String?                get lastError         => _lastError;
  int                    get wristBufferSize   => _wristBuffer.length;
  int                    get phoneBufferSize   => _phoneBuffer.length;
  bool                   get engineReady       => _engineReady;
  List<(DateTime, int)>  get bradykinesiaTrend =>
      List.unmodifiable(_bradykinesiaTrend);

  final _resultController = StreamController<GaitAnalysisResult>.broadcast();
  Stream<GaitAnalysisResult> get resultStream => _resultController.stream;

  GaitPipeline({
    required BleService ble,
    required PhoneSensorService phone,
    required GaitInferenceEngine engine,
    BradykinesiaGaitScorer? bradykinesiaScorer,
  })  : _ble = ble,
        _phone = phone,
        _engine = engine,
        _bradykinesiaScorer = bradykinesiaScorer ?? BradykinesiaGaitScorer();

  Future<void> init() async {
    try {
      await Future.wait([
        _engine.init(),
        _bradykinesiaScorer.init(),
      ]);
      _engineReady = true;
      debugPrint('[GaitPipeline] Engine initialised');
    } catch (e) {
      _lastError = 'Engine init failed: $e';
      debugPrint('[GaitPipeline] $_lastError');
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (!_engineReady) {
      _lastError = 'Engine not ready — call init() first';
      notifyListeners();
      return;
    }

    await _phone.start();
    await _ble.start();

    _wristSub = _ble.sampleStream.listen(_onWristSample);
    _phoneSub = _phone.sampleStream.listen(_onPhoneSample);

    _analysisTimer = Timer.periodic(
      const Duration(seconds: _analysisIntervalSec),
      (_) => _runAnalysis(),
    );

    debugPrint('[GaitPipeline] Started (dual-sensor)');
    notifyListeners();
  }

  void stop() {
    _wristSub?.cancel();
    _wristSub = null;
    _phoneSub?.cancel();
    _phoneSub = null;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _ble.stop();
    _phone.stop();
    _wristBuffer.clear();
    _phoneBuffer.clear();
    debugPrint('[GaitPipeline] Stopped');
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _resultController.close();
    super.dispose();
  }

  void _onWristSample(ImuSample sample) {
    _wristBuffer.add(sample);
    _trimBuffer(
      _wristBuffer,
      maxSamples: _maxWristSamples(),
      timestamp: (s) => (s as ImuSample).timestamp,
    );
  }

  void _onPhoneSample(PhoneAccelSample sample) {
    _phoneBuffer.add(sample);
    _trimBuffer(
      _phoneBuffer,
      maxSamples: _maxPhoneSamples(),
      timestamp: (s) => (s as PhoneAccelSample).timestamp,
    );
  }

  int _maxWristSamples() =>
      (SensorConfig.xiaoLsm6ds3OdrHz * _windowSec * 1.2).round();

  int _maxPhoneSamples() => _maxWristSamples();

  void _trimBuffer(
    List<dynamic> buffer, {
    required int maxSamples,
    required DateTime Function(dynamic) timestamp,
  }) {
    if (buffer.length <= maxSamples) return;
    final cutoff = timestamp(buffer.last).subtract(
      Duration(seconds: _windowSec),
    );
    while (buffer.isNotEmpty && timestamp(buffer.first).isBefore(cutoff)) {
      buffer.removeAt(0);
    }
    if (buffer.length > maxSamples) {
      buffer.removeRange(0, buffer.length - maxSamples);
    }
  }

  Future<void> _runAnalysis() async {
    if (_wristBuffer.length < _minSamplesRequired) {
      debugPrint(
        '[GaitPipeline] Not enough wrist samples: ${_wristBuffer.length}',
      );
      return;
    }
    if (_isAnalysing) return;

    _isAnalysing = true;
    notifyListeners();

    try {
      final wrist = List<ImuSample>.from(_wristBuffer);
      final phone = List<PhoneAccelSample>.from(_phoneBuffer);
      final extracted = _extractFeatures(wrist: wrist, phone: phone);
      final features = extracted.features;
      final validation = extracted.validation;

      final validatorWarnings = GaitModelValidator.validate(features);
      if (validatorWarnings.isNotEmpty) {
        debugPrint('[GaitPipeline] Validation: $validatorWarnings');
      }

      final gaitResult = await _engine.predict(features);

      final bradyInputs = BradykinesiaGaitInputs.fromGaitFeatures(
        features,
        armSwingVelocityRmsDegS: validation.armSwingVelocityRmsDegS,
      );
      final bradykinesia = _bradykinesiaScorer.score(bradyInputs);

      final now = DateTime.now();
      final result = GaitAnalysisResult(
        probability:          gaitResult.probability,
        isImpaired:           gaitResult.isImpaired,
        severityLevel:        gaitResult.severity,
        severityLabel:        gaitResult.severityLabel,
        timestamp:            now,
        samplesUsed:          wrist.length,
        bradykinesia:         bradykinesia,
        validation: GaitValidationMetrics(
          stepCount:               validation.stepCount,
          stepSymmetry:            validation.stepSymmetry,
          armSwingVelocityRmsDegS: validation.armSwingVelocityRmsDegS,
          armSwingRegularity:      validation.armSwingRegularity,
          wristSampleRateHz:       validation.wristSampleRateHz,
          phoneSampleRateHz:       validation.phoneSampleRateHz,
          phoneUsedForCadence:     validation.phoneUsedForCadence,
          warnings: [...validation.warnings, ...validatorWarnings],
        ),
        features:             features,
        cadenceStepsPerMin:   features['CAD_U'],
        armSwingAmplitudeDeg: features['RA_AMP_U'],
        strideTimeCV:         features['STR_CV_U'],
        walkingSpeedMs:       features['SP_U'],
      );

      _latestResult = result;
      _resultController.add(result);
      _lastError = null;

      // Update 7-day trend.
      _bradykinesiaTrend.add((now, result.bradykinesiaSeverity));
      final cutoff = now.subtract(const Duration(days: 7));
      _bradykinesiaTrend.removeWhere((e) => e.$1.isBefore(cutoff));

      debugPrint('[GaitPipeline] $result');
    } catch (e) {
      _lastError = 'Analysis failed: $e';
      debugPrint('[GaitPipeline] $_lastError');
    } finally {
      _isAnalysing = false;
      notifyListeners();
    }
  }

  Future<void> analyseNow() => _runAnalysis();

  /// Runs feature extraction on provided buffers (for unit tests).
  ({Map<String, double?> features, GaitValidationMetrics validation})
      extractForTest({
    required List<ImuSample> wrist,
    required List<PhoneAccelSample> phone,
  }) {
    return _extractFeatures(wrist: wrist, phone: phone);
  }

  ({Map<String, double?> features, GaitValidationMetrics validation})
      _extractFeatures({
    required List<ImuSample> wrist,
    required List<PhoneAccelSample> phone,
  }) {
    final wristFs = SensorConfig.estimateSampleRateHz(
      wrist.map((s) => s.timestamp).toList(),
    );
    final phoneFs = phone.length >= 4
        ? SensorConfig.estimateSampleRateHz(
            phone.map((s) => s.timestamp).toList(),
          )
        : wristFs;

    final phoneUsed = phone.length >= _minSamplesRequired ~/ 4;
    final phoneGait = phoneUsed
        ? _phoneGaitMetrics(phone, phoneFs)
        : _PhoneGaitMetrics.empty();

    final arm = _armSwingMetrics(wrist, wristFs);

    final warnings = <String>[];
    if (!phoneUsed) {
      warnings.add(
        'Insufficient phone accelerometer data — cadence imputed by model',
      );
    }

    final hasAxivity = phoneGait.hasValidSteps ? 1.0 : 0.0;

    final features = <String, double?>{
      'CAD_U': phoneGait.cadence,
      'STR_CV_U': phoneGait.strideCvPercent,
      'SP_U': phoneGait.speedMs,
      'RA_AMP_U': arm.raAmp,
      'LA_AMP_U': arm.laAmp,
      'SYM_U': arm.sym,
      'ASA_U': arm.asa,
      'has_armswing': arm.hasArmswing,
      'SW_VEL_OP': arm.swVel,
      'SW_PATH_OP': arm.swPath,
      'SW_FREQ_OP': arm.swFreq,
      'has_sway': arm.hasSway,
      'MeanSVMDaymg': null,
      'PercentWalking': phoneGait.percentWalking,
      'ActivityLevel': phoneGait.activityLevel,
      'CadencetimeDomain': phoneGait.cadence,
      'NumberOfBouts': phoneGait.boutCount.toDouble(),
      'wdV': phoneGait.walkingDurationFraction,
      'stepTime': phoneGait.stepTime,
      'strideTime': phoneGait.strideTime,
      'CVStrideTime': phoneGait.cvStrideTime,
      'SampEntropyV': phoneGait.sampleEntropy,
      'stepAsymV': phoneGait.stepAsym,
      'StepVelocitycmsec':
          phoneGait.speedMs != null ? phoneGait.speedMs! * 100 : null,
      'rmsV': phoneGait.rmsAccel,
      'has_axivity': hasAxivity,
      'GAIT_SUBGROUP': 0.0,
    };

    final validation = GaitValidationMetrics(
      stepCount:               phoneGait.stepCount,
      stepSymmetry:            phoneGait.stepSymmetry,
      armSwingVelocityRmsDegS: arm.velocityRmsDegS,
      armSwingRegularity:      arm.regularity,
      wristSampleRateHz:       wristFs,
      phoneSampleRateHz:       phoneFs,
      phoneUsedForCadence:     phoneUsed && phoneGait.hasValidSteps,
      warnings:                warnings,
    );

    return (features: features, validation: validation);
  }

  _PhoneGaitMetrics _phoneGaitMetrics(List<PhoneAccelSample> phone, double fs) {
    final mag = phone.map((s) => s.magnitude).toList();
    final peaks = GaitDsp.detectPeaks(mag, fs);
    final intervals = GaitDsp.peakIntervalsSec(peaks, fs);

    if (intervals.length < 3) {
      return _PhoneGaitMetrics.empty();
    }

    final meanStep = GaitDsp.mean(intervals);
    final cad = meanStep > 0 ? 60.0 / meanStep : null;
    final strideCv = meanStep > 0 ? GaitDsp.std(intervals) / meanStep * 100 : null;
    final speed = cad != null ? cad * _avgStepLengthM / 60.0 : null;
    final stepAsym = GaitDsp.stepAsymmetry(intervals);
    final stepSymmetry =
        stepAsym != null ? (1.0 - stepAsym).clamp(0.0, 1.0) : null;

    final walkingThreshold = GaitDsp.mean(mag) * 0.6;
    final walkingSamples = mag.where((v) => v > walkingThreshold).length;
    final percentWalking = phone.isNotEmpty
        ? 100.0 * walkingSamples / phone.length
        : null;

    return _PhoneGaitMetrics(
      hasValidSteps:           true,
      stepCount:               peaks.length,
      cadence:                 cad,
      strideCvPercent:         strideCv,
      speedMs:                 speed,
      stepTime:                meanStep,
      strideTime:              meanStep * 2,
      cvStrideTime:            strideCv,
      stepAsym:                stepAsym,
      stepSymmetry:            stepSymmetry,
      sampleEntropy:           GaitDsp.sampleEntropy(intervals),
      rmsAccel:                GaitDsp.rms(mag),
      percentWalking:          percentWalking,
      activityLevel:           percentWalking != null ? percentWalking / 100 : null,
      boutCount:               _countWalkingBouts(mag, walkingThreshold, fs),
      walkingDurationFraction: phone.isNotEmpty
          ? walkingSamples / phone.length
          : null,
    );
  }

  int _countWalkingBouts(List<double> mag, double threshold, double fs) {
    var inBout = false;
    var bouts = 0;
    var boutLen = 0;
    const minBoutSamples = 20;

    for (final v in mag) {
      if (v > threshold) {
        if (!inBout) {
          inBout = true;
          boutLen = 1;
        } else {
          boutLen++;
        }
      } else if (inBout) {
        if (boutLen >= minBoutSamples) bouts++;
        inBout = false;
        boutLen = 0;
      }
    }
    if (inBout && boutLen >= minBoutSamples) bouts++;
    return bouts;
  }

  _ArmSwingMetrics _armSwingMetrics(List<ImuSample> samples, double fs) {
    final dt = 1.0 / fs;
    final gyrZ = samples.map((s) => s.gyrZ).toList();
    final accX = samples.map((s) => s.accX).toList();
    final accY = samples.map((s) => s.accY).toList();

    final zeroCrossings = <int>[];
    for (int i = 1; i < gyrZ.length; i++) {
      if (gyrZ[i - 1] * gyrZ[i] < 0) zeroCrossings.add(i);
    }

    final rightCycleAmps = <double>[];
    final leftCycleAmps  = <double>[];

    for (int i = 0; i < zeroCrossings.length - 1; i++) {
      final start = zeroCrossings[i];
      final end   = zeroCrossings[i + 1];
      final segGyr = gyrZ.sublist(start, end + 1);
      final n = segGyr.length;

      final segAngle = List<double>.filled(n, 0.0);
      for (int j = 1; j < n; j++) {
        segAngle[j] = segAngle[j - 1] + (segGyr[j - 1] + segGyr[j]) * 0.5 * dt;
      }

      final slope = (segAngle[n - 1] - segAngle[0]) / (n - 1);
      final detrended = List<double>.generate(
        n,
        (j) => segAngle[j] - (segAngle[0] + slope * j),
      );

      final ampRange = detrended.reduce(max) - detrended.reduce(min);
      if (gyrZ[(start + end) ~/ 2] > 0) {
        rightCycleAmps.add(ampRange);
      } else {
        leftCycleAmps.add(ampRange);
      }
    }

    final raAmp = rightCycleAmps.isNotEmpty ? GaitDsp.mean(rightCycleAmps) : null;
    final laAmp = leftCycleAmps.isNotEmpty  ? GaitDsp.mean(leftCycleAmps)  : null;

    final hasArmswing =
        (raAmp != null &&
            raAmp >= _minArmSwingDeg &&
            laAmp != null &&
            laAmp >= _minArmSwingDeg)
        ? 1.0
        : 0.0;

    final raAmpFinal = (raAmp != null && raAmp >= _minArmSwingDeg) ? raAmp : null;
    final laAmpFinal = (laAmp != null && laAmp >= _minArmSwingDeg) ? laAmp : null;

    double? sym;
    if (raAmpFinal != null && laAmpFinal != null && laAmpFinal > 0) {
      sym = 1.0 - (raAmpFinal / laAmpFinal);
    }

    double? asa;
    if (raAmpFinal != null &&
        laAmpFinal != null &&
        raAmpFinal > 0 &&
        laAmpFinal > 0) {
      final greater = raAmpFinal >= laAmpFinal ? raAmpFinal : laAmpFinal;
      final smaller = raAmpFinal <  laAmpFinal ? raAmpFinal : laAmpFinal;
      asa = (45.0 - (atan(greater / smaller) * 180.0 / pi)) * 100.0 / 90.0;
    }

    final allAmps = [...rightCycleAmps, ...leftCycleAmps];
    double? regularity;
    if (allAmps.length >= 3) {
      final mu = GaitDsp.mean(allAmps);
      regularity = mu > 0 ? GaitDsp.std(allAmps) / mu : null;
    }

    final activeGyr  = gyrZ.where((g) => g.abs() > 5).toList();
    final velocityRms = activeGyr.isNotEmpty ? GaitDsp.rms(activeGyr) : null;

    final swVel  = GaitDsp.rms([...accX, ...accY]);
    var   swPath = 0.0;
    for (int i = 1; i < samples.length; i++) {
      final dAP = (accY[i] - accY[i - 1]).abs();
      final dML = (accX[i] - accX[i - 1]).abs();
      swPath += sqrt(dAP * dAP + dML * dML) * dt;
    }
    final swFreq = GaitDsp.dominantFreq(accY, fs);

    return _ArmSwingMetrics(
      raAmp:          raAmpFinal,
      laAmp:          laAmpFinal,
      sym:            sym,
      asa:            asa,
      hasArmswing:    hasArmswing,
      swVel:          swVel,
      swPath:         swPath,
      swFreq:         swFreq,
      hasSway:        1.0,
      velocityRmsDegS: velocityRms,
      regularity:     regularity,
    );
  }
}

class _PhoneGaitMetrics {
  final bool hasValidSteps;
  final int stepCount;
  final double? cadence;
  final double? strideCvPercent;
  final double? speedMs;
  final double? stepTime;
  final double? strideTime;
  final double? cvStrideTime;
  final double? stepAsym;
  final double? stepSymmetry;
  final double? sampleEntropy;
  final double? rmsAccel;
  final double? percentWalking;
  final double? activityLevel;
  final int boutCount;
  final double? walkingDurationFraction;

  const _PhoneGaitMetrics({
    required this.hasValidSteps,
    required this.stepCount,
    this.cadence,
    this.strideCvPercent,
    this.speedMs,
    this.stepTime,
    this.strideTime,
    this.cvStrideTime,
    this.stepAsym,
    this.stepSymmetry,
    this.sampleEntropy,
    this.rmsAccel,
    this.percentWalking,
    this.activityLevel,
    required this.boutCount,
    this.walkingDurationFraction,
  });

  factory _PhoneGaitMetrics.empty() => const _PhoneGaitMetrics(
        hasValidSteps: false,
        stepCount: 0,
        boutCount: 0,
      );
}

class _ArmSwingMetrics {
  final double? raAmp;
  final double? laAmp;
  final double? sym;
  final double? asa;
  final double hasArmswing;
  final double swVel;
  final double swPath;
  final double swFreq;
  final double hasSway;
  final double? velocityRmsDegS;
  final double? regularity;

  const _ArmSwingMetrics({
    this.raAmp,
    this.laAmp,
    this.sym,
    this.asa,
    required this.hasArmswing,
    required this.swVel,
    required this.swPath,
    required this.swFreq,
    required this.hasSway,
    this.velocityRmsDegS,
    this.regularity,
  });
}
