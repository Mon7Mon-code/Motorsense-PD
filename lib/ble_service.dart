import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Raw IMU sample from the XIAO BLE sensor
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

  /// Parse from raw BLE packet bytes: 6x float32 little-endian
  /// Packet layout: [accX, accY, accZ, gyrX, gyrY, gyrZ] each 4 bytes
  factory ImuSample.fromBytes(List<int> bytes) {
    if (bytes.length < 24) {
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
/// update _targetDeviceName and _imuCharUuid to match your firmware.
class BleService extends ChangeNotifier {
  // ── Configuration ─────────────────────────────────────────────────────────
  static const bool simulatorMode = true; // ← flip to false when XIAO arrives

  /// XIAO BLE device name as advertised (update to match firmware)
  static const String _targetDeviceName = 'XIAO_PD_Monitor';

  /// IMU notification characteristic UUID (update to match firmware)
  static const String _imuCharUuid = '12345678-1234-1234-1234-123456789abc';

  // ── Simulator parameters (mimics a moderately-impaired gait pattern) ──────
  static const int _simSampleRateHz = 50;       // samples per second
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
    // TODO (real BLE): disconnect flutter_blue_plus device here
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

      // Trunk vertical acceleration — gait oscillation at stride frequency
      final stridePhase = 2 * pi * _simStrideHz * _simT;
      final accZ = 9.8 + 0.8 * sin(stridePhase) + _noise();

      // Mediolateral sway
      final accX = 0.15 * sin(stridePhase * 0.5 + 0.3) + _noise();

      // Anteroposterior
      final accY = 0.4 * cos(stridePhase) + _noise();

      // Arm swing — wrist gyroscope (simulates wrist rotation during walking)
      final armPhase = 2 * pi * _simStrideHz * _simT + pi; // antiphase to trunk
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

  // ── Real BLE (stub — implement when XIAO arrives) ─────────────────────────

  Future<void> _startBle() async {
    _setStatus(BleStatus.scanning);

    // ── TODO: replace this stub with flutter_blue_plus implementation ──────
    //
    // 1. Add to pubspec.yaml:
    //      flutter_blue_plus: ^1.32.12
    //
    // 2. Replace this block with:
    //
    //    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    //    FlutterBluePlus.scanResults.listen((results) async {
    //      for (final r in results) {
    //        if (r.device.platformName == _targetDeviceName) {
    //          await FlutterBluePlus.stopScan();
    //          await r.device.connect();
    //          _connectedDevice = r.device.platformName;
    //          _setStatus(BleStatus.connected);
    //
    //          final services = await r.device.discoverServices();
    //          for (final s in services) {
    //            for (final c in s.characteristics) {
    //              if (c.uuid.toString() == _imuCharUuid) {
    //                await c.setNotifyValue(true);
    //                c.onValueReceived.listen((bytes) {
    //                  try {
    //                    _sampleController.add(ImuSample.fromBytes(bytes));
    //                  } catch (e) {
    //                    debugPrint('BLE parse error: $e');
    //                  }
    //                });
    //              }
    //            }
    //          }
    //        }
    //      }
    //    });
    //
    // ── End TODO ─────────────────────────────────────────────────────────────

    _lastError = 'Real BLE not implemented yet — use simulatorMode = true';
    _setStatus(BleStatus.disconnected);
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setStatus(BleStatus s) {
    _status = s;
    notifyListeners();
  }
}
