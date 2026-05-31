import 'gait_inference.dart';

Future<void> testInference() async {
  final engine = GaitInferenceEngine();
  await engine.init();

  // Hardcoded test vector — median values for a moderately impaired patient
  final testFeatures = <String, double?>{
    'CAD_U':              112.5,
    'STR_CV_U':           2.7,
    'SP_U':               1.19,
    'RA_AMP_U':           19.2,
    'LA_AMP_U':           20.1,
    'SYM_U':              0.95,
    'ASA_U':              0.12,
    'has_armswing':       1.0,
    'SW_VEL_OP':          null,  // missing — will be imputed
    'SW_PATH_OP':         null,
    'SW_FREQ_OP':         null,
    'has_sway':           0.0,
    'MeanSVMDaymg':       null,  // no Axivity
    'PercentWalking':     null,
    'ActivityLevel':      null,
    'CadencetimeDomain':  null,
    'NumberOfBouts':      null,
    'wdV':                null,
    'stepTime':           null,
    'strideTime':         null,
    'CVStrideTime':       5.6,
    'SampEntropyV':       null,
    'stepAsymV':          null,
    'StepVelocitycmsec':  null,
    'rmsV':               null,
    'has_axivity':        0.0,
    'GAIT_SUBGROUP':      0.0,
  };

  final result = await engine.predict(testFeatures);
  print('=== Gait Inference Test ===');
  print(result);
}