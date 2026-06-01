import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsons_tracker/bradykinesia_gait.dart';

void main() {
  late String thresholdsJson;

  setUpAll(() {
    thresholdsJson = File(
      'assets/bradykinesia_gait_thresholds.json',
    ).readAsStringSync();
  });

  test('normal-like PPMI values score low bradykinesia', () {
    final scorer = BradykinesiaGaitScorer();
    scorer.initFromJsonString(thresholdsJson);

    final result = scorer.score(
      const BradykinesiaGaitInputs(
        walkingSpeedCmS: 130,
        strideLengthM: 0.75,
        armSwingAmpDeg: 40,
        armSwingVelDegS: 42,
      ),
    );

    expect(result.sufficientData, isTrue);
    expect(result.level, lessThanOrEqualTo(1));
  });

  test('very slow walk and small arms score high bradykinesia', () {
    final scorer = BradykinesiaGaitScorer();
    scorer.initFromJsonString(thresholdsJson);

    final result = scorer.score(
      const BradykinesiaGaitInputs(
        walkingSpeedCmS: 85,
        strideLengthM: 0.45,
        armSwingAmpDeg: 12,
        armSwingVelDegS: 10,
      ),
    );

    expect(result.sufficientData, isTrue);
    expect(result.level, greaterThanOrEqualTo(3));
  });

  test('fromGaitFeatures derives stride length from SP and CAD', () {
    final inputs = BradykinesiaGaitInputs.fromGaitFeatures({
      'SP_U': 1.2,
      'CAD_U': 110.0,
      'RA_AMP_U': 30.0,
      'LA_AMP_U': 28.0,
      'StepVelocitycmsec': 120.0,
    }, armSwingVelocityRmsDegS: 25.0);

    expect(inputs.walkingSpeedCmS, 120.0);
    expect(inputs.strideLengthM, closeTo(1.2 * 60 / 110, 0.01));
    expect(inputs.armSwingAmpDeg, 29.0);
    expect(inputs.armSwingVelDegS, 25.0);
  });
}
