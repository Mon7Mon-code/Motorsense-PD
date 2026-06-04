import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../models/patient_data.dart';
import '../../widgets/shared/shared_widgets.dart';
import 'patient_checkin_screen.dart';
import 'patient_device_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AppDataService>(context);
    const patientId = 'p001';
    final patient = svc.getPatient(patientId);
    final snapshot = svc.getLatestSnapshot(patientId);
    final device = svc.getDeviceStatus(patientId);
    final checkIns = svc.getCheckIns(patientId);
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppTheme.neutral50,
            expandedHeight: 0,
            pinned: true,
            title: Image.asset('assets/logo.png',
                height: 26,
                errorBuilder: (_, __, ___) => Row(
                  children: [
                    Icon(Icons.monitor_heart_outlined,
                        color: AppTheme.teal600, size: 22),
                    const SizedBox(width: 8),
                    Text('ParkinsonsTracker',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                )),
            actions: [
              IconButton(
                icon: const Icon(Icons.watch_outlined, size: 22),
                color: AppTheme.neutral700,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PatientDeviceScreen())),
              ),
              const SizedBox(width: 4),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Greeting
                Text('$greeting,',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: AppTheme.neutral500)),
                Text(patient?.name.split(' ').first ?? 'Margaret',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(height: 1.1)),
                const SizedBox(height: 16),

                // Device status
                DeviceStatusBar(
                  isConnected: device.isConnected,
                  batteryPercent: device.batteryPercent,
                  lastSync: device.lastSyncTime,
                  isPatientView: true,
                ),

                const SizedBox(height: 24),

                // Baseline progress card — visible only during first 24h
                if (!svc.isBaselineComplete) ...[
                  _BaselineProgressCard(svc: svc),
                  const SizedBox(height: 16),
                ],

                // Wellness card — sensor-derived, gated by SensorCardShell
                SensorCardShell(
                  state: svc.sensorDataState,
                  lastSyncAge: svc.lastSyncAge,
                  child: snapshot != null
                      ? _WellnessCard(snapshot: snapshot)
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 16),

                // Next medication reminder — always shown (user-entered data)
                _NextDoseCard(svc: svc, patientId: patientId),

                const SizedBox(height: 16),

                // Today's check-in prompt — always shown (user-entered data)
                _CheckInPromptCard(checkIns: checkIns),

                const SizedBox(height: 24),

                // Today's symptoms — sensor-derived, gated
                const SectionHeader(title: 'How you\'re moving today'),
                SensorCardShell(
                  state: svc.sensorDataState,
                  lastSyncAge: svc.lastSyncAge,
                  child: snapshot != null
                      ? AppCard(
                          child: Column(
                            children: [
                              ScoreBar(
                                  label: 'Tremor',
                                  score: snapshot.tremorScore,
                                  showLabel: true),
                              const SizedBox(height: 14),
                              ScoreBar(
                                  label: 'Slowness of movement',
                                  score: snapshot.bradykinesiaScore,
                                  showLabel: true),
                              const SizedBox(height: 14),
                              ScoreBar(
                                  label: 'Involuntary movements',
                                  score: snapshot.dyskinesiaScore,
                                  showLabel: true),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // 7-day mood summary
                const SectionHeader(title: 'This week'),
                _WeekMoodRow(checkIns: checkIns),

                const SizedBox(height: 24),

                // Reassurance footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.teal50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.teal100, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: AppTheme.teal600, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your device is collecting data. Your care team can see your progress.',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.teal700,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Wellness hero card -------------------------------------
class _WellnessCard extends StatelessWidget {
  final SymptomSnapshot snapshot;
  const _WellnessCard({required this.snapshot});

  String get _overallLabel {
    final w = snapshot.overallWellness;
    if (w > 0.75) return 'You\'re doing well today';
    if (w > 0.5) return 'A fairly comfortable day';
    if (w > 0.3) return 'A harder day — that\'s okay';
    return 'A challenging day';
  }

  Color get _cardColor {
    final w = snapshot.overallWellness;
    if (w > 0.75) return AppTheme.teal50;
    if (w > 0.5) return AppTheme.teal50;
    if (w > 0.3) return AppTheme.amber50;
    return AppTheme.red50.withOpacity(0.5);
  }

  Color get _accentColor {
    final w = snapshot.overallWellness;
    if (w > 0.5) return AppTheme.teal600;
    if (w > 0.3) return AppTheme.amber600;
    return AppTheme.red600;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _accentColor.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s overview',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _accentColor.withOpacity(0.7),
                        letterSpacing: 0.3)),
                const SizedBox(height: 6),
                Text(_overallLabel,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _accentColor,
                        height: 1.2)),
                const SizedBox(height: 8),
                Text(
                  'Last updated ${_timeAgo(snapshot.timestamp)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: _accentColor.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: snapshot.overallWellness,
                    strokeWidth: 5,
                    backgroundColor: _accentColor.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '${(snapshot.overallWellness * 100).round()}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _accentColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 2) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }
}

// --- Next dose card -----------------------------------------
class _NextDoseCard extends StatelessWidget {
  final AppDataService svc;
  final String patientId;
  const _NextDoseCard({required this.svc, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final meds = svc.getMedications(patientId);
    if (meds.isEmpty) return const SizedBox.shrink();
    final med = meds.first;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.amber50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication_outlined,
                color: AppTheme.amber600, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next dose due',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.neutral500)),
                const SizedBox(height: 2),
                Text(
                    '${med.name} ${med.dose} at ${med.scheduledTimes.isNotEmpty ? med.scheduledTimes[1] : "—"}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.neutral900)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.amber50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.amber100, width: 0.5),
            ),
            child: Text('12:30',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.amber600)),
          ),
        ],
      ),
    );
  }
}

// --- Check-in prompt ----------------------------------------
class _CheckInPromptCard extends StatelessWidget {
  final List<WellbeingCheckIn> checkIns;
  const _CheckInPromptCard({required this.checkIns});

  bool get _doneToday {
    if (checkIns.isEmpty) return false;
    final last = checkIns.first.date;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  void _openCheckIn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PatientCheckInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_doneToday) {
      return GestureDetector(
        onTap: () => _openCheckIn(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.teal50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_rounded, color: AppTheme.teal500, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("Today's check-in done · tap to edit",
                    style: TextStyle(fontSize: 13, color: AppTheme.teal700)),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppTheme.teal400),
            ],
          ),
        ),
      );
    }

    return AppCard(
      backgroundColor: AppTheme.teal600,
      onTap: () => _openCheckIn(context),
      child: Row(
        children: [
          const Icon(Icons.sentiment_satisfied_alt_outlined,
              color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How are you feeling today?',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Text('Tap to do your daily check-in',
                    style:
                        TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Colors.white60),
        ],
      ),
    );
  }
}

// --- Baseline progress card ---------------------------------
class _BaselineProgressCard extends StatefulWidget {
  final AppDataService svc;
  const _BaselineProgressCard({required this.svc});

  @override
  State<_BaselineProgressCard> createState() => _BaselineProgressCardState();
}

class _BaselineProgressCardState extends State<_BaselineProgressCard> {
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _remainingText {
    final r = widget.svc.baselineTimeRemaining;
    final h = r.inHours;
    final m = r.inMinutes % 60;
    if (h > 0) return '~${h}h ${m}m remaining';
    return '~${m}m remaining';
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final progress = widget.svc.baselineProgress;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.teal50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.teal100, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  color: AppTheme.teal600, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Establishing your baseline',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.teal700),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppTheme.teal500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.teal100,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.teal500),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _remainingText,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.teal600),
              ),
              Text(
                '${(progress * 100).round()}% complete',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.teal600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- 7-day mood dots ----------------------------------------
class _WeekMoodRow extends StatelessWidget {
  final List<WellbeingCheckIn> checkIns;
  const _WeekMoodRow({required this.checkIns});

  @override
  Widget build(BuildContext context) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final checkIn = i < checkIns.length ? checkIns[checkIns.length - 1 - i] : null;
          final score = checkIn?.feelingScore;
          final color = score == null
              ? AppTheme.neutral100
              : score == 3
                  ? AppTheme.teal400
                  : score == 2
                      ? AppTheme.amber100
                      : AppTheme.red50;
          final dotColor = score == null
              ? AppTheme.neutral300
              : score == 3
                  ? AppTheme.teal600
                  : score == 2
                      ? AppTheme.amber400
                      : AppTheme.red400;

          return Column(
            children: [
              Text(days[(DateTime.now().weekday - 1 - (6 - i)) % 7],
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.neutral500,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  score == null
                      ? Icons.remove
                      : score == 3
                          ? Icons.sentiment_satisfied_alt_rounded
                          : score == 2
                              ? Icons.sentiment_neutral_rounded
                              : Icons.sentiment_dissatisfied_rounded,
                  size: 18,
                  color: dotColor,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
