import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../models/patient_data.dart';
import '../../widgets/shared/shared_widgets.dart';

class PatientAppointmentsScreen extends StatelessWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AppDataService>(context);
    const patientId = 'p001';
    final appointments = svc.getAppointments(patientId);
    final upcoming = appointments.where((a) => a.dateTime.isAfter(DateTime.now())).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE8),
                              appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D24),
        foregroundColor: Colors.white,
        title: const Text('Appointments',
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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          if (upcoming.isNotEmpty) ...[
            _NextAppointmentHero(appointment: upcoming.first),
            const SizedBox(height: 24),
          ],

          if (upcoming.length > 1) ...[
            const SectionHeader(title: 'Upcoming'),
            ...upcoming.skip(1).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AppointmentCard(appointment: a),
                )),
            const SizedBox(height: 24),
          ],

          // What to bring up
          if (upcoming.isNotEmpty)
            _DiscussionPointsCard(appointment: upcoming.first),

          const SizedBox(height: 16),

          // Reassurance
          AppCard(
            backgroundColor: AppTheme.blue50,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.blue400, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your wristband data is automatically shared with your clinician before each appointment, so they arrive prepared.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.blue600,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextAppointmentHero extends StatelessWidget {
  final Appointment appointment;
  const _NextAppointmentHero({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final daysUntil = appointment.dateTime.difference(DateTime.now()).inDays;
    final daysLabel = daysUntil == 0
        ? 'Today'
        : daysUntil == 1
            ? 'Tomorrow'
            : 'In $daysUntil days';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.teal700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next appointment',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.6),
                  letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Text(daysLabel,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1)),
          const SizedBox(height: 4),
          Text(
            '${_formatDate(appointment.dateTime)} · ${_formatTime(appointment.dateTime)}',
            style: TextStyle(
                fontSize: 14, color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 16),
          Container(
            height: 0.5,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(appointment.clinicianName,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                appointment.type == 'phone'
                    ? Icons.phone_outlined
                    : Icons.location_on_outlined,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(appointment.location,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              appointment.type == 'phone'
                  ? Icons.phone_outlined
                  : Icons.local_hospital_outlined,
              color: AppTheme.neutral500,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appointment.clinicianName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(appointment.dateTime)} · ${appointment.location}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.neutral500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}

class _DiscussionPointsCard extends StatelessWidget {
  final Appointment appointment;
  const _DiscussionPointsCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'What to discuss'),
          const Text(
              'Your device data has highlighted these topics for your next visit:',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.neutral500,
                  height: 1.4)),
          const SizedBox(height: 14),
          ...appointment.discussionPoints.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.teal500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(point,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.neutral700,
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
