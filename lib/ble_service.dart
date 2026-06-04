import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'sensor_config.dart';

/// Raw IMU sample from the PD-Monitor wristband (Seeed XIAO nRF52840 Sense).
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

  /// Parse from raw BLE notification (firmware contract).
  ///
  /// Layout: 6× float32 little-endian — accX, accY, accZ, gyrX, gyrY, gyrZ.
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

/// BLE service — streams IMU from [SensorConfig.bleDeviceName] or a simulator.
class BleService extends ChangeNotifier {
  static final Guid _serviceGuid =
      Guid(SensorConfig.bleServiceUuid);
  static final Guid _imuCharGuid =
      Guid(SensorConfig.bleImuCharacteristicUuid);

  // Standard BLE Battery Service (Bluetooth SIG assigned numbers).
  static final Guid _batteryServiceGuid =
      Guid('0000180F-0000-1000-8000-00805F9B34FB');
  static final Guid _batteryLevelCharGuid =
      Guid('00002A19-0000-1000-8000-00805F9B34FB');

  /// Nominal ODR for wrist LSM6DS3 (Seeed default: 104 Hz).
  static const int nominalSampleRateHz = SensorConfig.xiaoLsm6ds3OdrHz;

  static const int _simSampleRateHz = SensorConfig.bleCsvOdrHz;
  static const double _simStrideHz = 0.9;
  static const double _simArmAmpDeg = 18.0;
  static const double _simNoise = 0.08;

  BleStatus _status = BleStatus.disconnected;
  String? _connectedDevice;
  String? _lastError;
  bool _connecting = false;
  int _batteryPercent = 0;

  BleStatus get status => _status;
  String? get connectedDevice => _connectedDevice;
  String? get lastError => _lastError;
  int get batteryPercent => _batteryPercent;
  bool get isActive =>
      _status == BleStatus.connected || _status == BleStatus.simulating;

  final _sampleController = StreamController<ImuSample>.broadcast();
  Stream<ImuSample> get sampleStream => _sampleController.stream;

  // Emits one raw CSV line per sample (11 columns). Consumed by TremorPipeline
  // to call ingestReading() without creating a circular import dependency.
  final _csvLineController = StreamController<String>.broadcast();
  Stream<String> get csvLineStream => _csvLineController.stream;

  Timer? _simTimer;
  double _simT = 0.0;
  final _rng = Random();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _charSub;
  StreamSubscription<List<int>>? _batterySub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  BluetoothDevice? _bleDevice;

  /// Start streaming IMU data (simulator or PD-Monitor BLE).
  Future<void> start() async {
    if (isActive) return;
    if (SensorConfig.useBleSimulator) {
      _startSimulator();
    } else {
      await _startBle();
    }
  }

  void stop() {
    _connecting = false;
    _simTimer?.cancel();
    _simTimer = null;
    _scanSub?.cancel();
    _scanSub = null;
    _charSub?.cancel();
    _charSub = null;
    _batterySub?.cancel();
    _batterySub = null;
    _connStateSub?.cancel();
    _connStateSub = null;
    _bleDevice?.disconnect();
    _bleDevice = null;
    _batteryPercent = 0;
    _setStatus(BleStatus.disconnected);
    _connectedDevice = null;
  }

  /// Trigger a fresh scan + connect from the UI after a disconnect.
  Future<void> reconnect() async {
    if (isActive || _status == BleStatus.scanning ||
        _status == BleStatus.connecting) {
      return;
    }
    await _startBle();
  }

  @override
  void dispose() {
    stop();
    _sampleController.close();
    _csvLineController.close();
    super.dispose();
  }

  void _startSimulator() {
    _setStatus(BleStatus.simulating);
    _connectedDevice = 'Simulator';
    _batteryPercent = 85;
    final intervalMs = (1000 / _simSampleRateHz).round();

    _simTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _simT += 1.0 / _simSampleRateHz;

      final armPhase = 2 * pi * _simStrideHz * _simT;
      final accZ = 9.8 + 0.12 * sin(armPhase) + _noise();
      final accX = 0.08 * sin(armPhase * 0.5 + 0.3) + _noise();
      final accY = 0.15 * cos(armPhase) + _noise();

      final gyrZ = _simArmAmpDeg * sin(armPhase) + _noise() * 5;
      final gyrX = 8.0 * cos(armPhase * 0.5) + _noise() * 3;
      final gyrY = 3.0 * sin(armPhase + 0.8) + _noise() * 2;

      final ts = DateTime.now();
      _sampleController.add(ImuSample(
        accX: accX, accY: accY, accZ: accZ,
        gyrX: gyrX, gyrY: gyrY, gyrZ: gyrZ,
        timestamp: ts,
      ));

      // Synthesise a NONE-severity CSV line so TremorPipeline.ingestReading()
      // fires in simulator mode through the same code path as real hardware.
      final axRms = sqrt(accX * accX + accY * accY + accZ * accZ);
      _csvLineController.add(
        '${axRms.toStringAsFixed(4)},-2.0000,0,0.0500,NONE,'
        '${accX.toStringAsFixed(4)},${accY.toStringAsFixed(4)},${accZ.toStringAsFixed(4)},'
        '${gyrX.toStringAsFixed(4)},${gyrY.toStringAsFixed(4)},${gyrZ.toStringAsFixed(4)}',
      );
    });
  }

  double _noise() => (_rng.nextDouble() - 0.5) * 2 * _simNoise;

  /// Decode one BLE notification (up to 10 CSV lines) into ImuSamples and
  /// raw CSV strings. Timestamps are interpolated backwards from reception
  /// time using [SensorConfig.bleCsvOdrHz] so downstream frequency analysis
  /// sees evenly-spaced samples rather than a burst with identical timestamps.
  void _parseCsvBatch(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;

    final now = DateTime.now();
    const intervalMs = 1000 ~/ SensorConfig.bleCsvOdrHz; // 20 ms

    for (int i = 0; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.length < 11) {
        debugPrint('[BleService] short CSV line (${parts.length} cols): ${lines[i]}');
        continue;
      }

      // Oldest sample is at index 0; newest (closest to now) is at index n-1.
      final offsetMs = (lines.length - 1 - i) * intervalMs;
      final ts = now.subtract(Duration(milliseconds: offsetMs));

      try {
        _sampleController.add(ImuSample(
          accX: double.parse(parts[5]),
          accY: double.parse(parts[6]),
          accZ: double.parse(parts[7]),
          gyrX: double.parse(parts[8]),
          gyrY: double.parse(parts[9]),
          gyrZ: double.parse(parts[10]),
          timestamp: ts,
        ));
        _csvLineController.add(lines[i]);
      } catch (e) {
        debugPrint('[BleService] CSV line parse error: $e (${lines[i]})');
      }
    }
  }

  Future<void> _startBle() async {
    _setStatus(BleStatus.scanning);
    _lastError = null;

    try {
      await _ensureAdapterReady();

      await FlutterBluePlus.startScan(
        withServices: [_serviceGuid],
        timeout: const Duration(seconds: 30),
      );

      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          if (!_matchesTargetDevice(r) || _connecting || isActive) continue;

          _connecting = true;
          await FlutterBluePlus.stopScan();
          await _scanSub?.cancel();
          _scanSub = null;

          _setStatus(BleStatus.connecting);
          _bleDevice = r.device;

          try {
            await r.device.connect(timeout: const Duration(seconds: 15));
            _connectedDevice =
                _displayNameFor(r) ?? SensorConfig.bleDeviceDisplayName;
            _setStatus(BleStatus.connected);

            _connStateSub?.cancel();
            _connStateSub = r.device.connectionState.listen((state) {
              if (state == BluetoothConnectionState.disconnected &&
                  _status == BleStatus.connected) {
                _handleUnexpectedDisconnect();
              }
            });

            final subscribed = await _subscribeToImuCharacteristic(r.device);
            unawaited(_readBatteryLevel(r.device));
            if (!subscribed) {
              _lastError =
                  'IMU characteristic ${SensorConfig.bleImuCharacteristicUuid} '
                  'not found on service ${SensorConfig.bleServiceUuid}';
              debugPrint('[BleService] $_lastError');
              await r.device.disconnect();
              _bleDevice = null;
              _connectedDevice = null;
              _setStatus(BleStatus.disconnected);
            }
          } catch (e) {
            _lastError = 'Connection failed: $e';
            _setStatus(BleStatus.disconnected);
            debugPrint('[BleService] $_lastError');
          } finally {
            _connecting = false;
            notifyListeners();
          }
          return;
        }
      });
    } catch (e) {
      _lastError = 'Scan failed: $e';
      _setStatus(BleStatus.disconnected);
      debugPrint('[BleService] $_lastError');
      notifyListeners();
    }
  }

  Future<void> _ensureAdapterReady() async {
    if (await FlutterBluePlus.isSupported == false) {
      throw StateError('Bluetooth is not supported on this device');
    }

    if (!kIsWeb && Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }

    var state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      state = await FlutterBluePlus.adapterState.first;
    }
    if (state != BluetoothAdapterState.on) {
      throw StateError('Bluetooth adapter is off ($state)');
    }
  }

  bool _matchesTargetDevice(ScanResult r) {
    if (r.advertisementData.serviceUuids.contains(_serviceGuid)) {
      return true;
    }
    return _deviceNameMatches(r);
  }

  bool _deviceNameMatches(ScanResult r) {
    final target = SensorConfig.bleDeviceName.toLowerCase();
    final candidates = <String>[
      r.device.platformName,
      r.advertisementData.advName,
    ];
    for (final name in candidates) {
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      if (lower == target || lower.contains(target)) return true;
    }
    return false;
  }

  String? _displayNameFor(ScanResult r) {
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    if (r.advertisementData.advName.isNotEmpty) {
      return r.advertisementData.advName;
    }
    return null;
  }

  Future<bool> _subscribeToImuCharacteristic(BluetoothDevice device) async {
    final services = await device.discoverServices();

    BluetoothCharacteristic? imuChar;

    for (final service in services) {
      if (service.uuid != _serviceGuid) continue;
      for (final c in service.characteristics) {
        if (c.uuid == _imuCharGuid) {
          imuChar = c;
          break;
        }
      }
      if (imuChar != null) break;
    }

    if (imuChar == null) {
      for (final service in services) {
        for (final c in service.characteristics) {
          if (c.uuid == _imuCharGuid) {
            imuChar = c;
            break;
          }
        }
        if (imuChar != null) break;
      }
    }

    if (imuChar == null) return false;

    await imuChar.setNotifyValue(true);
    await _charSub?.cancel();
    _charSub = imuChar.onValueReceived.listen((bytes) {
      try {
        _parseCsvBatch(bytes);
      } catch (e) {
        debugPrint('[BleService] parse error: $e');
      }
    });
    return true;
  }

  Future<void> _readBatteryLevel(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      BluetoothCharacteristic? battChar;

      for (final service in services) {
        if (service.uuid != _batteryServiceGuid) continue;
        for (final c in service.characteristics) {
          if (c.uuid == _batteryLevelCharGuid) {
            battChar = c;
            break;
          }
        }
        if (battChar != null) break;
      }

      if (battChar == null) return;

      final value = await battChar.read();
      if (value.isNotEmpty) {
        _batteryPercent = value[0].clamp(0, 100);
        notifyListeners();
      }

      if (battChar.properties.notify) {
        await battChar.setNotifyValue(true);
        _batterySub = battChar.onValueReceived.listen((bytes) {
          if (bytes.isNotEmpty) {
            _batteryPercent = bytes[0].clamp(0, 100);
            notifyListeners();
          }
        });
      }
    } catch (e) {
      debugPrint('[BleService] battery read failed: $e');
    }
  }

  void _handleUnexpectedDisconnect() {
    _charSub?.cancel();
    _charSub = null;
    _batterySub?.cancel();
    _batterySub = null;
    _connStateSub?.cancel();
    _connStateSub = null;
    _bleDevice = null;
    _batteryPercent = 0;
    _connectedDevice = null;
    _setStatus(BleStatus.disconnected);
    debugPrint('[BleService] device disconnected unexpectedly');
  }

  void _setStatus(BleStatus s) {
    _status = s;
    notifyListeners();
  }
}
