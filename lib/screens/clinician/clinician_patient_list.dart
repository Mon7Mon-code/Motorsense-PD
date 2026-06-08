import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../models/patient_data.dart';
import '../../widgets/shared/shared_widgets.dart';
import '../login_screen.dart';
import 'clinician_patient_dashboard.dart';

class ClinicianPatientList extends StatelessWidget {
  const ClinicianPatientList({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AppDataService>(context);
    final patients = svc.getPatients('c001');

    final needsAttention =
        patients.where((p) => p.statusFlag == 'needs-attention').toList();
    final monitor = patients.where((p) => p.statusFlag == 'monitor').toList();
    final stable = patients.where((p) => p.statusFlag == 'stable').toList();

    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      appBar: AppBar(
        backgroundColor: AppTheme.neutral50,
        title: Row(
          children: [
            const Icon(Icons.monitor_heart_outlined,
                color: AppTheme.teal600, size: 20),
            const SizedBox(width: 8),
            const Text('Clinician View'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            color: AppTheme.neutral400,
            onPressed: () {
              svc.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          // Summary stats
          Row(
            children: [
              _StatChip(
                count: patients.length,
                label: 'patients',
                color: AppTheme.neutral700,
                bg: AppTheme.neutral100,
              ),
              const SizedBox(width: 8),
              _StatChip(
                count: needsAttention.length,
                label: 'need attention',
                color: AppTheme.red600,
                bg: AppTheme.red50,
              ),
              const SizedBox(width: 8),
              _StatChip(
                count: monitor.length,
                label: 'monitor',
                color: AppTheme.amber600,
                bg: AppTheme.amber50,
              ),
            ],
          ),

          if (needsAttention.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Needs attention'),
            ...needsAttention.map((p) => _PatientTile(patient: p)),
          ],

          if (monitor.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Monitor'),
            ...monitor.map((p) => _PatientTile(patient: p)),
          ],

          if (stable.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Stable'),
            ...stable.map((p) => _PatientTile(patient: p)),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final Color bg;

  const _StatChip({
    required this.count, required this.label,
    required this.color, required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color.withValues(alpha:0.8))),
        ],
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  final Patient patient;
  const _PatientTile({required this.patient});

  @override
  Widget build(BuildContext context) {
    final snapshot = patient.latestSnapshot;
    final device = patient.deviceStatus;
    final lastSeen = snapshot?.timestamp;
    final lastSeenLabel = lastSeen == null
        ? 'No data'
        : _timeAgo(lastSeen);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicianPatientDashboard(
              patientId: patient.id,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            _InitialsAvatar(name: patient.name, flag: patient.statusFlag),
            const SizedBox(width: 14),

            // Name, age, last sync
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${patient.age}y · Dx ${patient.diagnosisYear}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.neutral400)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        device.isConnected
                            ? Icons.watch_rounded
                            : Icons.watch_off_outlined,
                        size: 11,
                        color: device.isConnected
                            ? AppTheme.teal500
                            : AppTheme.neutral300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        device.isConnected
                            ? 'Last sync $lastSeenLabel'
                            : 'Device offline',
                        style: TextStyle(
                          fontSize: 11,
                          color: device.isConnected
                              ? AppTheme.teal600
                              : AppTheme.neutral400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status + scores
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(flag: patient.statusFlag),
                const SizedBox(height: 6),
                if (snapshot != null)
                  Text(
                    'T: ${snapshot.tremorScore.toStringAsFixed(1)} · B: ${snapshot.bradykinesiaScore.toStringAsFixed(1)}',
                    style: AppTheme.mono.copyWith(fontSize: 11),
                  ),
              ],
            ),

            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.neutral300),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 2) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  final String flag;
  const _InitialsAvatar({required this.name, required this.flag});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join();
    final dotColor = AppTheme.statusColor(flag);

    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.neutral100,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutral600)),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

const neutral400 = Color(0xFF888780);
const neutral600 = Color(0xFF5F5E5A);
