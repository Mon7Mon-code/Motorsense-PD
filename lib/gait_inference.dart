// lib/gait_inference.dart
//
// Dart-side gait inference pipeline:
//   1. Accepts raw 27-feature map (unscaled, NaN allowed)
//   2. Applies imputer (median fill) + StandardScaler from scaler_params.json
//   3. Sends scaled features to Kotlin via platform channel
//   4. Applies severity banding to the returned probability
//
// Usage:
//   final engine = GaitInferenceEngine();
//   await engine.init();                    // loads scaler_params.json once
//   final result = await engine.predict(rawFeatures);
//   print(result.severity);                 // 0–4

import 'dart:convert';
import 'package:flutter/services.dart';

// ── Feature order — must match train_gait.py all_feats exactly ───────────────
const List<String> kFeatureCols = [
  'CAD_U', 'STR_CV_U', 'SP_U',
  'RA_AMP_U', 'LA_AMP_U', 'SYM_U', 'ASA_U', 'has_armswing',
  'SW_VEL_OP', 'SW_PATH_OP', 'SW_FREQ_OP', 'has_sway',
  'MeanSVMDaymg', 'PercentWalking', 'ActivityLevel', 'CadencetimeDomain',
  'NumberOfBouts', 'wdV', 'stepTime', 'strideTime',
  'CVStrideTime', 'SampEntropyV', 'stepAsymV', 'StepVelocitycmsec', 'rmsV',
  'has_axivity', 'GAIT_SUBGROUP',
];

// ── Result ────────────────────────────────────────────────────────────────────
class GaitResult {
  final double probability;   // raw sigmoid output [0, 1]
  final bool isImpaired;      // probability >= 0.5
  final int severity;         // 0=normal, 1=mild, 2=moderate, 3=severe, 4=very severe
  final String severityLabel;

  GaitResult({
    required this.probability,
    required this.isImpaired,
    required this.severity,
    required this.severityLabel,
  });

  static const List<String> _labels = [
    'Normal', 'Mild', 'Moderate', 'Severe', 'Very Severe'
  ];

  @override
  String toString() =>
      'GaitResult(prob=${probability.toStringAsFixed(3)}, '
      'impaired=$isImpaired, severity=$severity/$severityLabel)';
}

// ── Engine ────────────────────────────────────────────────────────────────────
class GaitInferenceEngine {
  static const _channel = MethodChannel(
    'com.example.parkinsons_tracker/gait_inference',
  );

  // Loaded from scaler_params.json
  late List<double> _imputer;   // median per feature
  late List<double> _mean;      // scaler mean per feature
  late List<double> _std;       // scaler std per feature
  late Map<String, dynamic> _severityThresholds;

  bool _initialised = false;

  // Call once before first predict()
  Future<void> init() async {
    if (_initialised) return;

    final jsonStr = await rootBundle.loadString('assets/scaler_params.json');
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    final features = json['features'] as List<dynamic>;
    _imputer = features.map<double>((f) => (f['imputer_median'] as num).toDouble()).toList();
    _mean    = features.map<double>((f) => (f['scaler_mean']    as num).toDouble()).toList();
    _std     = features.map<double>((f) => (f['scaler_std']     as num).toDouble()).toList();
    _severityThresholds = json['severity_thresholds'] as Map<String, dynamic>;

    // Pre-load the model on the native side
    await _channel.invokeMethod('loadModel');

    _initialised = true;
  }

  // rawFeatures: map of feature name → value (double or null for missing)
  Future<GaitResult> predict(Map<String, double?> rawFeatures) async {
    assert(_initialised, 'Call init() before predict()');

    // Step 1 — assemble raw vector in canonical order, NaN for missing
    final raw = List<double>.generate(kFeatureCols.length, (i) {
      final val = rawFeatures[kFeatureCols[i]];
      return val ?? double.nan;
    });

    // Step 2 — impute: replace NaN with median
    final imputed = List<double>.generate(raw.length, (i) {
      return raw[i].isNaN ? _imputer[i] : raw[i];
    });

    // Step 3 — scale: (x - mean) / std
    final scaled = List<double>.generate(imputed.length, (i) {
      final s = _std[i];
      return s > 0 ? (imputed[i] - _mean[i]) / s : 0.0;
    });

    // Step 4 — run native inference
    final Map<Object?, Object?> nativeResult = await _channel.invokeMethod(
      'runInference',
      {'features': scaled},
    );

    final probability = (nativeResult['probability'] as num).toDouble();
    final isImpaired  = nativeResult['is_impaired'] as bool;

    // Step 5 — severity banding (uses RAW values, not scaled)
    final severity = isImpaired
        ? _bandSeverity(
            strideCV: raw[kFeatureCols.indexOf('CVStrideTime')],
            armAmp:   raw[kFeatureCols.indexOf('RA_AMP_U')],
          )
        : 0;

    return GaitResult(
      probability:   probability,
      isImpaired:    isImpaired,
      severity:      severity,
      severityLabel: GaitResult._labels[severity],
    );
  }

  int _bandSeverity({required double strideCV, required double armAmp}) {
    final cv = _severityThresholds['CVStrideTime'] as Map<String, dynamic>;
    final ra = _severityThresholds['RA_AMP_U']     as Map<String, dynamic>;

    final cvP33 = (cv['p33'] as num).toDouble();
    final cvP66 = (cv['p66'] as num).toDouble();
    final cvP90 = (cv['p90'] as num).toDouble();
    final raP10 = (ra['p10'] as num).toDouble();

    // Use imputed median for CVStrideTime if missing
    final cvVal = strideCV.isNaN
        ? _imputer[kFeatureCols.indexOf('CVStrideTime')]
        : strideCV;

    int base;
    if      (cvVal < cvP33) base = 1;
    else if (cvVal < cvP66) base = 2;
    else if (cvVal < cvP90) base = 3;
    else                    base = 4;

    // Upgrade by 1 if arm swing is markedly reduced
    if (!armAmp.isNaN && armAmp < raP10) {
      base = (base + 1).clamp(1, 4);
    }

    return base;
  }
}
