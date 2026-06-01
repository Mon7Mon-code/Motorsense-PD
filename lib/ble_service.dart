import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'sensor_config.dart';

/// Raw IMU sample from the Seeed XIAO nRF52840 Sense (wrist).
class ImuSample {
  final double accX, accY, accZ;
  final double gyrX, gyrY, gyrZ;
  final DateTime timestamp;

  ImuSample({
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyrX,
    required this.gyrY,
    required this.gyrZ,
    required this.timestamp,
  });

  /// Parse from raw BLE notification (current firmware contract).
  ///
  /// Layout: 6× float32 little-endian — accX, accY, accZ, gyrX, gyrY, gyrZ.
  /// Future firmware may send compressed feature packets instead; those require
  /// a separate parser and must not use [fromBytes].
  factory ImuSample.fromBytes(List<int> bytes) {
    if (bytes.length < SensorConfig.bleRawPacketBytes) {
      throw FormatException('IMU packet too short: ${bytes.length} bytes');
    }
    final buf = Uint8List.fromList(bytes).buffer;
    final view = ByteData.view(buf);
    return ImuSample(
      accX: view.getFloat32(0, Endian.little),
      accY: view.getFloat32(4, Endian.little),
      accZ: view.getFloat32(8, Endian.little),
      gyrX: view.getFloat32(12, Endian.little),
      gyrY: view.getFloat32(16, Endian.little),
      gyrZ: view.getFloat32(20, Endian.little),
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() =>
      'ImuSample(acc=[${accX.toStringAsFixed(2)}, ${accY.toStringAsFixed(2)}, ${accZ.toStringAsFixed(2)}] '
      'gyr=[${gyrX.toStringAsFixed(2)}, ${gyrY.toStringAsFixed(2)}, ${gyrZ.toStringAsFixed(2)}])';
}

enum BleStatus { disconnected, scanning, connecting, connected, simulating }

/// BLE service — wraps real flutter_blue_plus in production,
/// exposes a simulator stream for development without hardware.
///
/// SIMULATOR MODE: set simulatorMode = true (default until hardware arrives).
/// REAL BLE: set simulatorMode = false — then plug in XIAO BLE Sense and
/// update _imuCharUuid to match your firmware.
class BleService extends ChangeNotifier {
  // ── Configuration ─────────────────────────────────────────────────────────
  static const bool simulatorMode = true; // ← flip to false when XIAO arrives

  /// XIAO BLE device name as advertised (update to match firmware)
  static const String _targetDeviceName = 'XIAO_PD_Monitor';

  /// IMU notification characteristic UUID — update once firmware confirms
  static const String _imuCharUuid = '12345678-1234-1234-1234-123456789abc';

  /// Nominal ODR for XIAO LSM6DS3 (Seeed library default: 104 Hz).
  static const int nominalSampleRateHz = SensorConfig.xiaoLsm6ds3OdrHz;

  // ── Simulator parameters (mimics a moderately-impaired gait pattern) ──────
  static const int _simSampleRateHz = nominalSampleRateHz;
  static const double _simStrideHz  = 0.9;      // ~108 steps/min cadence
  static const double _simArmAmpDeg = 18.0;     // arm swing amplitude (degrees)
  static const double _simNoise     = 0.08;     // sensor noise level

  // ── State ─────────────────────────────────────────────────────────────────
  BleStatus _status = BleStatus.disconnected;
  String?   _connectedDevice;
  String?   _lastError;

  BleStatus get status          => _status;
  String?   get connectedDevice => _connectedDevice;
  String?   get lastError       => _lastError;
  bool      get isActive        => _status == BleStatus.connected ||
                                   _status == BleStatus.simulating;

  // ── Streams ───────────────────────────────────────────────────────────────
  final _sampleController = StreamController<ImuSample>.broadcast();
  Stream<ImuSample> get sampleStream => _sampleController.stream;

  Timer?  _simTimer;
  double  _simT = 0.0;
  final   _rng  = Random();

  // Real BLE subscriptions
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>?        _charSub;
  BluetoothDevice?                      _bleDevice;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Start streaming IMU data (simulator or real BLE)
  Future<void> start() async {
    if (isActive) return;
    if (simulatorMode) {
      _startSimulator();
    } else {
      await _startBle();
    }
  }

  /// Stop streaming
  void stop() {
    _simTimer?.cancel();
    _simTimer = null;
    _scanSub?.cancel();
    _scanSub = null;
    _charSub?.cancel();
    _charSub = null;
    _bleDevice?.disconnect();
    _bleDevice = null;
    _setStatus(BleStatus.disconnected);
    _connectedDevice = null;
  }

  @override
  void dispose() {
    stop();
    _sampleController.close();
    super.dispose();
  }

  // ── Simulator ─────────────────────────────────────────────────────────────

  void _startSimulator() {
    _setStatus(BleStatus.simulating);
    _connectedDevice = 'Simulator';
    final intervalMs = (1000 / _simSampleRateHz).round();

    _simTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _simT += 1.0 / _simSampleRateHz;

      // Wrist accelerometer — small sway; cadence comes from phone sensor.
      final armPhase = 2 * pi * _simStrideHz * _simT;
      final accZ = 9.8 + 0.12 * sin(armPhase) + _noise();
      final accX = 0.08 * sin(armPhase * 0.5 + 0.3) + _noise();
      final accY = 0.15 * cos(armPhase) + _noise();

      // Wrist gyro — arm swing (deg/s scale)
      final gyrZ = _simArmAmpDeg * sin(armPhase) + _noise() * 5;
      final gyrX = 8.0 * cos(armPhase * 0.5) + _noise() * 3;
      final gyrY = 3.0 * sin(armPhase + 0.8) + _noise() * 2;

      _sampleController.add(ImuSample(
        accX: accX,
        accY: accY,
        accZ: accZ,
        gyrX: gyrX,
        gyrY: gyrY,
        gyrZ: gyrZ,
        timestamp: DateTime.now(),
      ));
    });
  }

  double _noise() => (_rng.nextDouble() - 0.5) * 2 * _simNoise;

  // ── Real BLE ──────────────────────────────────────────────────────────────

  Future<void> _startBle() async {
    _setStatus(BleStatus.scanning);

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          if (r.device.platformName == _targetDeviceName) {
            await FlutterBluePlus.stopScan();
            await _scanSub?.cancel();
            _scanSub = null;

            _setStatus(BleStatus.connecting);
            _bleDevice = r.device;

            try {
              await r.device.connect(timeout: const Duration(seconds: 10));
              _connectedDevice = r.device.platformName;
              _setStatus(BleStatus.connected);

              final services = await r.device.discoverServices();
              for (final s in services) {
                for (final c in s.characteristics) {
                  if (c.uuid.toString().toLowerCase() ==
                      _imuCharUuid.toLowerCase()) {
                    await c.setNotifyValue(true);
                    _charSub = c.onValueReceived.listen((bytes) {
                      try {
                        _sampleController.add(ImuSample.fromBytes(bytes));
                      } catch (e) {
                        debugPrint('[BleService] parse error: $e');
                      }
                    });
                    return; // found characteristic — done
                  }
                }
              }
              _lastError = 'IMU characteristic $_imuCharUuid not found';
              debugPrint('[BleService] $_lastError');
              notifyListeners();
            } catch (e) {
              _lastError = 'Connection failed: $e';
              _setStatus(BleStatus.disconnected);
              notifyListeners();
            }
            return;
          }
        }
      });
    } catch (e) {
      _lastError = 'Scan failed: $e';
      _setStatus(BleStatus.disconnected);
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setStatus(BleStatus s) {
    _status = s;
    notifyListeners();
  }
}
