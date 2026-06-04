import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ble_service.dart';
import '../../models/patient_data.dart';
import '../../sensor_config.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared/shared_widgets.dart';

class PatientDeviceScreen extends StatelessWidget {
  const PatientDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AppDataService>(context);
    final ble = Provider.of<BleService>(context);
    final device = svc.getDeviceStatus('p001');

    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      appBar: AppBar(
        title: const Text('My device'),
        backgroundColor: AppTheme.neutral50,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          _ConnectionCard(ble: ble, device: device),

          const SizedBox(height: 24),

          // Wearing guide
          const SectionHeader(title: 'How to wear the device'),
          AppCard(
            child: Column(
              children: [
                _GuideStep(
                    step: 1,
                    text: 'Wear it on your non-dominant wrist, like a watch.'),
                _GuideStep(
                    step: 2,
                    text: 'Wear it snugly — it should not slide around, but not too tight.'),
                _GuideStep(
                    step: 3,
                    text: 'You can sleep with it on. Night-time data helps track rest quality.'),
                _GuideStep(
                    step: 4,
                    text: 'Charge it daily — it only takes about 30 minutes.',
                    isLast: true),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: 'Battery tips'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (device.batteryPercent > 0 && device.batteryPercent < 30)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.amber50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.battery_alert_rounded,
                            color: AppTheme.amber600, size: 18),
                        SizedBox(width: 8),
                        Text('Battery is low. Charge tonight.',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.amber700)),
                      ],
                    ),
                  ),
                const Text(
                    'Charge the device each evening when you\'re done for the day. '
                    'Keep it plugged in for at least 30 minutes.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.neutral700,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connection card — reacts to BleStatus ──────────────────────────────────
class _ConnectionCard extends StatelessWidget {
  final BleService ble;
  final DeviceStatus device;
  const _ConnectionCard({required this.ble, required this.device});

  @override
  Widget build(BuildContext context) {
    switch (ble.status) {
      case BleStatus.connected:
        return _ConnectedCard(device: device, deviceName: ble.connectedDevice);
      case BleStatus.simulating:
        return _ConnectedCard(device: device, deviceName: 'Simulator');
      case BleStatus.scanning:
        return _ScanningCard(label: 'Scanning for ${SensorConfig.bleDeviceDisplayName}…');
      case BleStatus.connecting:
        return _ScanningCard(label: 'Connecting to ${SensorConfig.bleDeviceDisplayName}…');
      case BleStatus.disconnected:
        return _DisconnectedCard(ble: ble);
    }
  }
}

class _ConnectedCard extends StatelessWidget {
  final DeviceStatus device;
  final String? deviceName;
  const _ConnectedCard({required this.device, this.deviceName});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.teal50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.watch_rounded,
                    size: 28, color: AppTheme.teal600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deviceName ?? SensorConfig.bleDeviceDisplayName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Connected and recording',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.teal600)),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.teal500,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 0),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(
                icon: Icons.battery_std_rounded,
                label: 'Battery',
                value: device.batteryPercent > 0
                    ? '${device.batteryPercent}%'
                    : '—',
                color: device.batteryPercent > 0 && device.batteryPercent <= 30
                    ? AppTheme.amber400
                    : AppTheme.teal500,
              ),
              _StatItem(
                icon: Icons.sync_rounded,
                label: 'Last sync',
                value: 'Just now',
                color: AppTheme.teal500,
              ),
              _StatItem(
                icon: Icons.radio_button_checked_rounded,
                label: 'Recording',
                value: 'Active',
                color: AppTheme.teal500,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanningCard extends StatelessWidget {
  final String label;
  const _ScanningCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.teal500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Keep the device nearby and powered on',
                    style: TextStyle(fontSize: 13, color: AppTheme.neutral500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisconnectedCard extends StatelessWidget {
  final BleService ble;
  const _DisconnectedCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.watch_off_outlined,
                    size: 28, color: AppTheme.neutral400),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Not connected',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(SensorConfig.bleDeviceDisplayName,
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.neutral400)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ble.reconnect(),
            icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
            label: const Text('Connect to device'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Make sure your device is charged, powered on, and within 1 metre of your phone.',
            style: TextStyle(
                fontSize: 12, color: AppTheme.neutral500, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.neutral400)),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int step;
  final String text;
  final bool isLast;
  const _GuideStep({required this.step, required this.text, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.teal50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$step',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.teal700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.neutral700, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
