import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsons_tracker/ble_service.dart';
import 'package:parkinsons_tracker/gait_inference.dart';
import 'package:parkinsons_tracker/gait_pipeline.dart';
import 'package:parkinsons_tracker/phone_sensor_service.dart';
import 'package:parkinsons_tracker/sensor_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GaitPipeline dual-sensor extraction', () {
    late GaitPipeline pipeline;

    setUp(() {
      pipeline = GaitPipeline(
        ble: BleService(),
        phone: PhoneSensorService(),
        engine: GaitInferenceEngine(),
      );
    });

    test('cadence and speed come from phone, not wrist accZ', () {
      final wrist = _syntheticWrist(seconds: 12, rateHz: 104);
      final phone = _syntheticPhone(seconds: 12, rateHz: 104, strideHz: 0.5);

      final out = pipeline.extractForTest(wrist: wrist, phone: phone);
      final f = out.features;

      expect(f['CAD_U'], isNotNull);
      expect(f['CAD_U']!, closeTo(60.0, 8.0));
      expect(f['SP_U'], isNotNull);
      expect(f['has_axivity'], 1.0);
      expect(out.validation.phoneUsedForCadence, isTrue);
      expect(out.validation.stepCount, greaterThan(4));
      expect(out.validation.armSwingVelocityRmsDegS, isNotNull);
      expect(out.validation.armSwingRegularity, isNotNull);
      expect(out.validation.stepSymmetry, isNotNull);
    });

    test('wrist-only cadence is not used when phone data present', () {
      final wrist = _syntheticWrist(seconds: 12, rateHz: 104, flatAccZ: true);
      final phone = _syntheticPhone(seconds: 12, rateHz: 104, strideHz: 0.5);

      final out = pipeline.extractForTest(wrist: wrist, phone: phone);
      expect(out.features['CAD_U'], isNotNull);
      expect(out.validation.phoneUsedForCadence, isTrue);
    });

    test('sample rate estimation near XIAO 104 Hz default', () {
      final wrist = _syntheticWrist(seconds: 5, rateHz: 104);
      final rate = SensorConfig.estimateSampleRateHz(
        wrist.map((s) => s.timestamp).toList(),
      );
      expect(rate, closeTo(104, 15));
    });
  });
}

List<ImuSample> _syntheticWrist({
  required int seconds,
  required int rateHz,
  bool flatAccZ = false,
}) {
  final samples = <ImuSample>[];
  final t0 = DateTime.now();
  final n = seconds * rateHz;
  for (int i = 0; i < n; i++) {
    final t = i / rateHz;
    final phase = 2 * pi * 0.9 * t;
    samples.add(
      ImuSample(
        accX: 0.05 * sin(phase),
        accY: 0.1 * cos(phase),
        accZ: flatAccZ ? 9.8 : 9.8 + 0.02 * sin(phase),
        gyrX: 5 * cos(phase * 0.5),
        gyrY: 2 * sin(phase),
        gyrZ: 20 * sin(phase),
        timestamp: t0.add(Duration(microseconds: (t * 1e6).round())),
      ),
    );
  }
  return samples;
}

List<PhoneAccelSample> _syntheticPhone({
  required int seconds,
  required int rateHz,
  required double strideHz,
}) {
  final samples = <PhoneAccelSample>[];
  final t0 = DateTime.now();
  final n = seconds * rateHz;
  for (int i = 0; i < n; i++) {
    final t = i / rateHz;
    final phase = 2 * pi * strideHz * t;
    samples.add(
      PhoneAccelSample(
        x: 0.1 * sin(phase * 0.5),
        y: 0.6 * sin(phase),
        z: 0.3 * cos(phase),
        timestamp: t0.add(Duration(microseconds: (t * 1e6).round())),
      ),
    );
  }
  return samples;
}
