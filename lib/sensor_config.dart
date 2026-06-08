/// Sensor configuration for the PD-Monitor wristband (Seeed XIAO nRF52840 Sense).
///
/// The Seeed Arduino LSM6DS3 library defaults both accelerometer and gyroscope
/// ODR to 104 Hz. BLE firmware may stream lower (often ~50–100 Hz) depending on
/// connection interval; [estimateSampleRateHz] should be used on live streams.
library;

class SensorConfig {
  SensorConfig._();

  // ── PD-Monitor BLE (firmware contract) ─────────────────────────────────────

  /// Advertised BLE name for the wristband.
  static const String bleDeviceName = 'PD-Monitor';

  /// GATT service UUID for IMU streaming.
  static const String bleServiceUuid =
      'A1B2C3D4-E5F6-7890-ABCD-EF1234567890';

  /// Notify characteristic UUID (6× float32 IMU packet).
  static const String bleImuCharacteristicUuid =
      'B2C3D4E5-F6A7-8901-BCDE-F12345678901';

  /// Human-readable label shown in device/onboarding screens.
  static const String bleDeviceDisplayName = bleDeviceName;

  /// Set true to stream simulated IMU data (no hardware required).
  static const bool useBleSimulator = false;

  /// Set true to skip the 24-hour baseline window and show live data immediately.
  /// Revert to false before clinical deployment.
  static const bool demoMode = false;

  /// Raw hardware ODR of the LSM6DS3 (104 Hz). Used only for reference;
  /// the firmware outputs CSV at [bleCsvOdrHz], not at this rate.
  static const int xiaoLsm6ds3OdrHz = 104;

  /// Rate at which the firmware emits CSV lines over BLE (one line per sample).
  /// 10 lines are batched per BLE notification → notification interval ≈ 200 ms.
  static const int bleCsvOdrHz = 50;

  /// Nominal analysis window length (seconds).
  static const int gaitWindowSec = 20;

  /// Minimum buffered seconds before running inference.
  static const int gaitMinBufferSec = 10;

  /// Legacy binary packet size — kept for reference only; firmware now sends CSV.
  static const int bleRawPacketBytes = 24;

  /// Estimate effective sample rate from timestamped samples.
  static double estimateSampleRateHz(
    List<DateTime> timestamps, {
    double fallbackHz = 50.0, // matches bleCsvOdrHz
  }) {
    if (timestamps.length < 4) return fallbackHz;
    final spanSec =
        timestamps.last.difference(timestamps.first).inMicroseconds / 1e6;
    if (spanSec <= 0) return fallbackHz;
    final rate = (timestamps.length - 1) / spanSec;
    if (rate < 25 || rate > 500) return fallbackHz;
    return rate;
  }
}
