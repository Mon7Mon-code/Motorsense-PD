/// Auxiliary gait metrics (not all are model inputs) and pre-inference checks.
class GaitValidationMetrics {
  final int stepCount;
  final double? stepSymmetry;
  final double? armSwingVelocityRmsDegS;
  final double? armSwingRegularity;
  final double wristSampleRateHz;
  final double phoneSampleRateHz;
  final bool phoneUsedForCadence;
  final List<String> warnings;

  const GaitValidationMetrics({
    required this.stepCount,
    this.stepSymmetry,
    this.armSwingVelocityRmsDegS,
    this.armSwingRegularity,
    required this.wristSampleRateHz,
    required this.phoneSampleRateHz,
    required this.phoneUsedForCadence,
    this.warnings = const [],
  });
}

/// Sanity-checks raw features before they are scaled and sent to the .ptl model.
class GaitModelValidator {
  static const _cadRange = (40.0, 180.0);
  static const _spRange = (0.3, 2.5);
  static const _armAmpRange = (0.0, 90.0);

  static List<String> validate(Map<String, double?> features) {
    final w = <String>[];

    final cad = features['CAD_U'];
    if (cad != null && (cad < _cadRange.$1 || cad > _cadRange.$2)) {
      w.add('CAD_U=$cad outside plausible steps/min range');
    }

    final sp = features['SP_U'];
    if (sp != null && (sp < _spRange.$1 || sp > _spRange.$2)) {
      w.add('SP_U=$sp outside plausible m/s range');
    }

    final ra = features['RA_AMP_U'];
    if (ra != null && (ra < _armAmpRange.$1 || ra > _armAmpRange.$2)) {
      w.add('RA_AMP_U=$ra outside plausible degrees range');
    }

    final hasAx = features['has_axivity'] == 1.0;
    final hasPhoneCad = features['CadencetimeDomain'] != null;
    if (hasAx && !hasPhoneCad) {
      w.add('has_axivity=1 but phone cadence features missing');
    }

    if (features['has_axivity'] == 0.0 &&
        features['CAD_U'] == null &&
        features['STR_CV_U'] == null) {
      w.add('No cadence features — model will rely on imputation');
    }

    return w;
  }
}
