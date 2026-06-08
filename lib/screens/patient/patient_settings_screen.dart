import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/app_data_service.dart';
import '../../widgets/shared/shared_widgets.dart';
import '../login_screen.dart';
import 'patient_device_screen.dart';

// ============================================================
// SETTINGS SCREEN
// Medication management, notifications, account
// ============================================================

class PatientSettingsScreen extends StatefulWidget {
  const PatientSettingsScreen({super.key});

  @override
  State<PatientSettingsScreen> createState() => _PatientSettingsScreenState();
}

class _PatientSettingsScreenState extends State<PatientSettingsScreen> {
  bool _medicationReminders = true;
  bool _checkInReminders = true;
  bool _clinicianAlerts = true;

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AppDataService>(context);
    final meds = svc.getMedications('p001');

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE8),
                              appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D24),
        foregroundColor: Colors.white,
        title: const Text('Settings',
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
        children: [
          // ── Medications ──────────────────────────────────
          const SectionHeader(title: 'Medications'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...meds.asMap().entries.map((entry) {
                  final i   = entry.key;
                  final med = entry.value;
                  final color = Color(int.parse(
                      'FF${med.color.replaceAll('#', '')}', radix: 16));
                  return Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        title: Text(med.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          '${med.dose} · ${med.scheduledTimes.join(', ')}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.neutral500),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: AppTheme.neutral400),
                          onPressed: () =>
                              _showEditMedSheet(context, med.name, med.dose,
                                  med.scheduledTimes),
                        ),
                      ),
                      if (i < meds.length - 1)
                        const Divider(height: 0, indent: 16),
                    ],
                  );
                }),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.add_rounded,
                      color: AppTheme.teal600, size: 20),
                  title: const Text('Add medication',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.teal600)),
                  onTap: () => _showAddMedSheet(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Notifications ─────────────────────────────────
          const SectionHeader(title: 'Notifications'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwitchTile(
                  title: 'Medication reminders',
                  subtitle: 'Remind me when a dose is due',
                  value: _medicationReminders,
                  onChanged: (v) =>
                      setState(() => _medicationReminders = v),
                ),
                const Divider(height: 0),
                _SwitchTile(
                  title: 'Daily check-in reminder',
                  subtitle: 'Remind me to log how I\'m feeling',
                  value: _checkInReminders,
                  onChanged: (v) =>
                      setState(() => _checkInReminders = v),
                ),
                const Divider(height: 0),
                _SwitchTile(
                  title: 'Clinician alerts',
                  subtitle: 'Notify me when my care team sends a message',
                  value: _clinicianAlerts,
                  onChanged: (v) =>
                      setState(() => _clinicianAlerts = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Device ────────────────────────────────────────
          const SectionHeader(title: 'Device'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.watch_outlined,
                      color: AppTheme.neutral500, size: 20),
                  title: const Text('Device settings',
                      style: TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppTheme.neutral300),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PatientDeviceScreen())),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.bluetooth_outlined,
                      color: AppTheme.neutral500, size: 20),
                  title: const Text('Reconnect device',
                      style: TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppTheme.neutral300),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PatientDeviceScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── About ─────────────────────────────────────────
          const SectionHeader(title: 'About'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded,
                      color: AppTheme.neutral500, size: 20),
                  title: Text('Version', style: TextStyle(fontSize: 14)),
                  trailing: Text('1.0.0',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.neutral400)),
                ),
                const Divider(height: 0),
                const ListTile(
                  leading: Icon(Icons.school_outlined,
                      color: AppTheme.neutral500, size: 20),
                  title: Text('Imperial College London · Group 10',
                      style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Sign out ──────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () {
              svc.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.red400,
              side: const BorderSide(color: AppTheme.red400),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditMedSheet(BuildContext context, String name, String dose,
      List<String> times) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(dose,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.neutral500)),
            const SizedBox(height: 20),
            const Text('Scheduled times',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.neutral700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: times
                  .map((t) => Chip(
                        label: Text(t,
                            style: AppTheme.mono.copyWith(fontSize: 12)),
                        backgroundColor: AppTheme.teal50,
                        side: const BorderSide(
                            color: AppTheme.teal100, width: 0.5),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            // TODO: add time editing when medication management is wired to storage
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.neutral100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Full medication editing coming soon. '
                'For now, update your schedule with your clinician.',
                style: TextStyle(fontSize: 12, color: AppTheme.neutral500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMedSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add medication',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Medication name',
                hintText: 'e.g. Levodopa',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: doseCtrl,
              decoration: const InputDecoration(
                labelText: 'Dose',
                hintText: 'e.g. 100mg',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // TODO: wire to AppDataService when medication persistence is added
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Medication added'),
                    backgroundColor: AppTheme.teal600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.neutral500)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.teal600,
    );
  }
}