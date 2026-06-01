import 'dart:convert';
import 'package:flutter/services.dart';

/// Raw movement values used for bradykinesia–gait scoring.
class BradykinesiaGaitInputs {
  final double? walkingSpeedCmS;
  final double? strideLengthM;
  final double? armSwingAmpDeg;
  final double? armSwingVelDegS;

  const BradykinesiaGaitInputs({
    this.walkingSpeedCmS,
    this.strideLengthM,
    this.armSwingAmpDeg,
    this.armSwingVelDegS,
  });

  /// Build from the 27-feature gait map + optional live arm velocity RMS.
  factory BradykinesiaGaitInputs.fromGaitFeatures(
    Map<String, double?> features, {
    double? armSwingVelocityRmsDegS,
  }) {
    final sp = features['SP_U'];
    final cad = features['CAD_U'];
    final stepVel = features['StepVelocitycmsec'];
    final ra = features['RA_AMP_U'];
    final la = features['LA_AMP_U'];

    double? speed = stepVel;
    if (speed == null && sp != null) speed = sp * 100;

    double? stride;
    if (sp != null && cad != null && cad > 0) {
      stride = sp * 60 / cad;
    }

    double? amp;
    if (ra != null && la != null) {
      amp = (ra + la) / 2;
    } else {
      amp = ra ?? la;
    }

    return BradykinesiaGaitInputs(
      walkingSpeedCmS: speed,
      strideLengthM: stride,
      armSwingAmpDeg: amp,
      armSwingVelDegS: armSwingVelocityRmsDegS,
    );
  }

  int get availableCount => [
        walkingSpeedCmS,
        strideLengthM,
        armSwingAmpDeg,
        armSwingVelDegS,
      ].where((v) => v != null).length;
}

/// Per-metric band 0 (best) … 4 (worst bradykinesia).
class BradykinesiaMetricScore {
  final String name;
  final double? value;
  final int band;
  final bool imputed;

  const BradykinesiaMetricScore({
    required this.name,
    required this.value,
    required this.band,
    this.imputed = false,
  });
}

/// Composite bradykinesia severity inferred from gait (0–4).
class BradykinesiaGaitResult {
  final int level;
  final String label;
  final List<BradykinesiaMetricScore> metrics;
  final bool sufficientData;

  const BradykinesiaGaitResult({
    required this.level,
    required this.label,
    required this.metrics,
    required this.sufficientData,
  });

  static const List<String> _labels = [
    'Normal',
    'Mild',
    'Moderate',
    'Severe',
    'Very Severe',
  ];

  factory BradykinesiaGaitResult.insufficient() => const BradykinesiaGaitResult(
        level: 0,
        label: 'Insufficient data',
        metrics: [],
        sufficientData: false,
      );

  @override
  String toString() =>
      'BradykinesiaGaitResult(level=$level/$label, metrics=${metrics.length})';
}

/// Scores bradykinesia indirectly via gait (Hausdorff-style hypokinesia).
///
/// Thresholds calibrated on PPMI normal gait rows; see
/// [assets/bradykinesia_gait_thresholds.json].
class BradykinesiaGaitScorer {
  static const _assetPath = 'assets/bradykinesia_gait_thresholds.json';

  /// Weights reflect NP3BRADY correlation on PPMI (arm > speed/stride).
  static const Map<String, double> _weights = {
    'walking_speed_cm_s': 0.20,
    'stride_length_m': 0.20,
    'arm_swing_amp_deg': 0.35,
    'arm_swing_vel_deg_s': 0.25,
  };

  Map<String, _MetricThresholds>? _thresholds;
  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(_assetPath);
    _loadFromJson(raw);
  }

  /// Test helper — load thresholds without [rootBundle].
  void initFromJsonString(String jsonStr) => _loadFromJson(jsonStr);

  void _loadFromJson(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final t = json['thresholds'] as Map<String, dynamic>;
    _thresholds = t.map(
      (name, spec) => MapEntry(
        name,
        _MetricThresholds.fromJson(spec as Map<String, dynamic>),
      ),
    );
    _loaded = true;
  }

  BradykinesiaGaitResult score(BradykinesiaGaitInputs inputs) {
    assert(_loaded, 'Call init() before score()');
    final th = _thresholds!;

    final metricValues = <String, double?>{
      'walking_speed_cm_s': inputs.walkingSpeedCmS,
      'stride_length_m': inputs.strideLengthM,
      'arm_swing_amp_deg': inputs.armSwingAmpDeg,
      'arm_swing_vel_deg_s': inputs.armSwingVelDegS,
    };

    final scores = <BradykinesiaMetricScore>[];
    var weightedSum = 0.0;
    var weightTotal = 0.0;

    for (final entry in metricValues.entries) {
      final spec = th[entry.key];
      if (spec == null) continue;
      final value = entry.value;
      if (value == null || value.isNaN) continue;

      final band = spec.bandFor(value);
      scores.add(
        BradykinesiaMetricScore(name: entry.key, value: value, band: band),
      );
      final w = _weights[entry.key] ?? 0.25;
      weightedSum += band * w;
      weightTotal += w;
    }

    if (weightTotal < 0.35) {
      return BradykinesiaGaitResult.insufficient();
    }

    final level = (weightedSum / weightTotal).round().clamp(0, 4);
    return BradykinesiaGaitResult(
      level: level,
      label: BradykinesiaGaitResult._labels[level],
      metrics: scores,
      sufficientData: true,
    );
  }
}

class _MetricThresholds {
  final double p20;
  final double p40;
  final double p60;
  final double p80;
  final bool higherIsBetter;

  _MetricThresholds({
    required this.p20,
    required this.p40,
    required this.p60,
    required this.p80,
    required this.higherIsBetter,
  });

  factory _MetricThresholds.fromJson(Map<String, dynamic> j) {
    return _MetricThresholds(
      p20: (j['p20'] as num).toDouble(),
      p40: (j['p40'] as num).toDouble(),
      p60: (j['p60'] as num).toDouble(),
      p80: (j['p80'] as num).toDouble(),
      higherIsBetter: j['higher_is_better'] as bool? ?? true,
    );
  }

  /// 0 = best (near normal PPMI), 4 = worst bradykinesia.
  int bandFor(double value) {
    if (higherIsBetter) {
      if (value >= p80) return 0;
      if (value >= p60) return 1;
      if (value >= p40) return 2;
      if (value >= p20) return 3;
      return 4;
    }
    // lower-is-better metrics (not used in current calibration)
    if (value <= p20) return 0;
    if (value <= p40) return 1;
    if (value <= p60) return 2;
    if (value <= p80) return 3;
    return 4;
  }
}
