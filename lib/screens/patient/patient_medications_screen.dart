import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared/shared_widgets.dart';

class PatientMedicationsScreen extends StatelessWidget {
  const PatientMedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AppDataService>(context);
    const patientId = 'p001';
    final meds = svc.getMedications(patientId);

    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      appBar: AppBar(
    title: const Text('Medications',
        style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700)),
    backgroundColor: const Color(0xFF0F3D24),
    foregroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(24),
      ),
    ),
    actions: [
          IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('About medication tracking'),
                    content: const Text(
                        'Logging your doses helps your care team understand how well your medication is working. '
                        'This data is combined with your wrist sensor readings to spot patterns.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Got it')),
                    ],
                  ),
                );
              }),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          // Today's schedule header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.teal100, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.today_outlined,
                    color: AppTheme.teal600, size: 20),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today\'s schedule',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.teal700)),
                    Text(
                      '${meds.fold(0, (n, m) => n + m.scheduledTimes.length)} doses across ${meds.length} medications',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.teal600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: 'Your medications'),

          ...meds.map((med) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MedCard(
                  med: med,
                  onTaken: () => svc.logMedicationTaken(patientId, med.id),
                ),
              )),

          const SizedBox(height: 24),
          const SectionHeader(title: 'Today\'s timeline'),
          _DoseTimeline(meds: meds),

          const SizedBox(height: 24),

          // Reminder about why timing matters
          AppCard(
            backgroundColor: AppTheme.amber50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        color: AppTheme.amber600, size: 18),
                    const SizedBox(width: 8),
                    Text('Why timing matters',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.amber700)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                    'Taking your medication at consistent times helps keep symptoms stable throughout the day. '
                    'Your wristband records how your symptoms change after each dose.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.amber700,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedCard extends StatefulWidget {
  final dynamic med;
  final VoidCallback onTaken;
  const _MedCard({required this.med, required this.onTaken});

  @override
  State<_MedCard> createState() => _MedCardState();
}

class _MedCardState extends State<_MedCard> {
  bool _justLogged = false;

  @override
  Widget build(BuildContext context) {
    final color = Color(
        int.parse('FF${widget.med.color.replaceAll('#', '')}', radix: 16));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.med.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.med.dose,
                    style: AppTheme.mono.copyWith(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: (widget.med.scheduledTimes as List<String>)
                .map<Widget>((t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _DosePill(time: t, taken: false),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          if (_justLogged)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.teal500, size: 18),
                const SizedBox(width: 6),
                Text('Logged at ${TimeOfDay.now().format(context)}',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.teal600)),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  widget.onTaken();
                  setState(() => _justLogged = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.med.name} logged'),
                      backgroundColor: AppTheme.teal600,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Log dose taken'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DosePill extends StatelessWidget {
  final String time;
  final bool taken;
  const _DosePill({required this.time, required this.taken});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: taken ? AppTheme.teal50 : AppTheme.neutral100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: taken ? AppTheme.teal100 : AppTheme.neutral200,
            width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (taken)
            const Icon(Icons.check_rounded,
                size: 10, color: AppTheme.teal600),
          if (taken) const SizedBox(width: 4),
          Text(time,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: taken ? AppTheme.teal700 : AppTheme.neutral700)),
        ],
      ),
    );
  }
}

class _DoseTimeline extends StatelessWidget {
  final List<dynamic> meds;
  const _DoseTimeline({required this.meds});

  @override
  Widget build(BuildContext context) {
    // Flatten all doses with their times
    final doses = <Map<String, dynamic>>[];
    for (final med in meds) {
      for (final t in (med.scheduledTimes as List<String>)) {
        doses.add({'time': t, 'name': med.name, 'color': med.color});
      }
    }
    doses.sort((a, b) => a['time'].compareTo(b['time']));

    return AppCard(
      child: Column(
        children: doses.asMap().entries.map((entry) {
          final i = entry.key;
          final dose = entry.value;
          final color = Color(int.parse(
              'FF${(dose['color'] as String).replaceAll('#', '')}',
              radix: 16));
          final isLast = i == doses.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    if (!isLast)
                      Expanded(
                        child: Container(
                            width: 1,
                            color: AppTheme.neutral200,
                            margin:
                                const EdgeInsets.symmetric(vertical: 4)),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Row(
                      children: [
                        Text(dose['time'] as String,
                            style: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppTheme.neutral700)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(dose['name'] as String,
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.neutral700)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

