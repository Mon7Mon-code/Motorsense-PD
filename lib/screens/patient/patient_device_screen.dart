import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared/shared_widgets.dart';

class PatientDeviceScreen extends StatelessWidget {
  const PatientDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AppDataService>(context);
    final device = svc.getDeviceStatus('p001');

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE8),
                              appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D24),
        foregroundColor: Colors.white,
        title: const Text('My device',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F3D24), Color(0xFF1A6B3E)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // Status card
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: device.isConnected
                            ? AppTheme.teal50
                            : AppTheme.neutral100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.watch_rounded,
                        size: 28,
                        color: device.isConnected
                            ? AppTheme.teal600
                            : AppTheme.neutral400,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PK-Tracker Wristband',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            device.isConnected
                                ? 'Connected and recording'
                                : 'Not connected',
                            style: TextStyle(
                              fontSize: 13,
                              color: device.isConnected
                                  ? AppTheme.teal600
                                  : AppTheme.neutral400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (device.isConnected) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 0),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                     _DeviceStatItem(
  icon: Icons.battery_std_rounded,
  label: 'Battery',
  value: device.batteryPercent > 0
      ? '${device.batteryPercent}%'
      : 'Unknown',
  color: AppTheme.neutral400,
),
                      _DeviceStatItem(
                        icon: Icons.sync_rounded,
                        label: 'Last sync',
                        value: 'Just now',
                        color: AppTheme.teal500,
                      ),
                      _DeviceStatItem(
                        icon: Icons.radio_button_checked_rounded,
                        label: 'Recording',
                        value: 'Active',
                        color: AppTheme.teal500,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (!device.isConnected) ...[
            _TroubleshootCard(),
            const SizedBox(height: 24),
          ],

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
                    text:
                        'Wear it snugly — it should not slide around, but not too tight.'),
                _GuideStep(
                    step: 3,
                    text:
                        'You can sleep with it on. Night-time data helps track rest quality.'),
                _GuideStep(
                    step: 4,
                    text:
                        'Charge it daily — it only takes about 30 minutes.',
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
                    child: Row(
                      children: [
                        const Icon(Icons.battery_alert_rounded,
                            color: AppTheme.amber600, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                            'Battery is low. Charge tonight.',
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

class _DeviceStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DeviceStatItem({
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.neutral400)),
        ],
      ),
    );
  }
}

class _TroubleshootCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppTheme.red50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.watch_off_outlined, color: AppTheme.red400, size: 18),
              SizedBox(width: 8),
              Text('Device not found',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.red600)),
            ],
          ),
          SizedBox(height: 10),
          Text('Try these steps:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.red700)),
          SizedBox(height: 6),
          Text('1. Make sure the device is charged\n'
              '2. Keep it within 1 metre of your phone\n'
              '3. Check Bluetooth is turned on in Settings\n'
              '4. Restart the app if the problem continues',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.red700, height: 1.5)),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int step;
  final String text;
  final bool isLast;

  const _GuideStep({
    required this.step, required this.text, this.isLast = false,
  });

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
            decoration: BoxDecoration(
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
                    fontSize: 13,
                    color: AppTheme.neutral700,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

const neutral400 = Color(0xFF888780);
const red600 = Color(0xFFA32D2D);
const red700 = Color(0xFF791F1F);
const amber700 = Color(0xFF854F0B);
