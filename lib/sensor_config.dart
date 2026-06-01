/// Sensor configuration for Seeed XIAO nRF52840 Sense (LSM6DS3TR-C).
///
/// The Seeed Arduino LSM6DS3 library defaults both accelerometer and gyroscope
/// ODR to 104 Hz. BLE firmware may stream lower (often ~50–100 Hz) depending on
/// connection interval; [estimateSampleRateHz] should be used on live streams.
library;

class SensorConfig {
  SensorConfig._();

  /// Default ODR when using Seeed's LSM6DS3 library defaults (104 Hz).
  static const int xiaoLsm6ds3OdrHz = 104;

  /// Nominal analysis window length (seconds).
  static const int gaitWindowSec = 20;

  /// Minimum buffered seconds before running inference.
  static const int gaitMinBufferSec = 10;

  /// BLE packet layout for raw IMU notifications (current firmware contract).
  /// Six float32 values little-endian: accX, accY, accZ, gyrX, gyrY, gyrZ.
  static const int bleRawPacketBytes = 24;

  /// Estimate effective sample rate from timestamped samples.
  static double estimateSampleRateHz(
    List<DateTime> timestamps, {
    double fallbackHz = 104.0,
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
