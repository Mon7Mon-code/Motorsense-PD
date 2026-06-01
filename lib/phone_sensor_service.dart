import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'sensor_config.dart';

/// Linear acceleration sample from the smartphone (pocket / lower-body proxy).
class PhoneAccelSample {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const PhoneAccelSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  double get magnitude => sqrt(x * x + y * y + z * z);
}

enum PhoneSensorStatus { stopped, active, simulating, unavailable }

/// Streams user accelerometer data from the phone for step / cadence features.
///
/// Falls back to a gait-like simulator when no hardware sensor is available
/// (desktop tests, emulators without motion).
class PhoneSensorService extends ChangeNotifier {
  static const double _simStrideHz = 0.9;
  static const double _simNoise = 0.06;

  PhoneSensorStatus _status = PhoneSensorStatus.stopped;
  String? _lastError;

  PhoneSensorStatus get status => _status;
  String? get lastError => _lastError;
  bool get isActive =>
      _status == PhoneSensorStatus.active ||
      _status == PhoneSensorStatus.simulating;

  final _sampleController = StreamController<PhoneAccelSample>.broadcast();
  Stream<PhoneAccelSample> get sampleStream => _sampleController.stream;

  StreamSubscription<UserAccelerometerEvent>? _sensorSub;
  Timer? _simTimer;
  double _simT = 0;
  final _rng = Random();

  /// Inject samples directly (unit tests).
  void addTestSample(PhoneAccelSample sample) {
    _sampleController.add(sample);
  }

  Future<void> start() async {
    if (isActive) return;

    try {
      _sensorSub = userAccelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (event) {
          _setStatus(PhoneSensorStatus.active);
          _sampleController.add(
            PhoneAccelSample(
              x: event.x,
              y: event.y,
              z: event.z,
              timestamp: DateTime.now(),
            ),
          );
        },
        onError: (Object e) {
          _lastError = 'Accelerometer error: $e';
          _startSimulator();
        },
      );
      _setStatus(PhoneSensorStatus.active);
    } catch (e) {
      _lastError = 'Accelerometer unavailable: $e';
      _startSimulator();
    }
  }

  void stop() {
    _sensorSub?.cancel();
    _sensorSub = null;
    _simTimer?.cancel();
    _simTimer = null;
    _setStatus(PhoneSensorStatus.stopped);
  }

  @override
  void dispose() {
    stop();
    _sampleController.close();
    super.dispose();
  }

  void _startSimulator() {
    _sensorSub?.cancel();
    _sensorSub = null;
    _setStatus(PhoneSensorStatus.simulating);
    _simT = 0;

    const rateHz = SensorConfig.xiaoLsm6ds3OdrHz;
    final intervalMs = (1000 / rateHz).round();

    _simTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _simT += 1.0 / rateHz;
      final phase = 2 * pi * _simStrideHz * _simT;
      // Pocket vertical oscillation during walking (m/s², gravity removed).
      _sampleController.add(
        PhoneAccelSample(
          x: 0.12 * sin(phase * 0.5) + _noise(),
          y: 0.55 * sin(phase) + _noise(),
          z: 0.35 * cos(phase) + _noise(),
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  double _noise() => (_rng.nextDouble() - 0.5) * 2 * _simNoise;

  void _setStatus(PhoneSensorStatus s) {
    _status = s;
    notifyListeners();
  }
}
