import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../models/patient_data.dart';
import 'patient_episodes_screen.dart';
import 'patient_settings_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc        = Provider.of<AppDataService>(context);
    final snapshot   = svc.getLatestSnapshot('p001');
    final device     = svc.getDeviceStatus('p001');
    final checkIns   = svc.getCheckIns('p001');
    final meds       = svc.getMedications('p001');
    final firstName  = svc.patientName.split(' ').first;
    final hour       = DateTime.now().hour;
    final greeting   = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE8),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ══ HERO ══════════════════════════════════════════
            _Hero(
              greeting:  greeting,
              name:      firstName,
              snapshot:  snapshot,
              device:    device,
              onSettings: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PatientSettingsScreen())),
              onHistory:  () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PatientEpisodesScreen())),
            ),

            // ══ BODY ══════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Next dose + check-in row
                  Row(
                    children: [
                      Expanded(child: _NextDoseBlock(meds: meds)),
                      const SizedBox(width: 12),
                      Expanded(child: _CheckInBlock(checkIns: checkIns)),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Section title
                  _Title('How you\'re moving'),
                  const SizedBox(height: 12),

                  // Symptom blocks — big bold cards
                  if (snapshot != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _SymptomBlock(
                            label: 'Tremor',
                            value: snapshot.tremorLabel,
                            score: snapshot.tremorScore,
                            icon:  Icons.vibration_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SymptomBlock(
                            label: 'Slowness',
                            value: snapshot.bradykinesiaLabel,
                            score: snapshot.bradykinesiaScore,
                            icon:  Icons.directions_walk_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SymptomBlock(
                            label: 'Involuntary',
                            value: snapshot.dyskinesiaLabel,
                            score: snapshot.dyskinesiaScore,
                            icon:  Icons.swap_horiz_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _UpdatedLabel(snapshot.timestamp),
                  ] else
                    _NoDataCard(),

                  const SizedBox(height: 22),

                  // This week
                  _Title('This week'),
                  const SizedBox(height: 12),
                  _WeekCard(checkIns: checkIns),

                  const SizedBox(height: 22),

                  // Reassurance
                  _ReassuranceBar(isConnected: device.isConnected),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══ HERO ═════════════════════════════════════════════════════
class _Hero extends StatelessWidget {
  final String greeting;
  final String name;
  final SymptomSnapshot? snapshot;
  final DeviceStatus device;
  final VoidCallback onSettings;
  final VoidCallback onHistory;

  const _Hero({
    required this.greeting, required this.name,
    required this.snapshot, required this.device,
    required this.onSettings, required this.onHistory,
  });

  double? get _wellness => snapshot?.overallWellness;

  String get _wellnessLabel {
    final w = _wellness;
    if (w == null)  return 'Collecting data';
    if (w > 0.80)   return 'Doing well today';
    if (w > 0.60)   return 'A comfortable day';
    if (w > 0.40)   return 'A harder day';
    return 'A challenging day';
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _wellness != null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.6, 1.0],
          colors: [
            Color(0xFF0F3D24),
            Color(0xFF1A6B3E),
            Color(0xFF28A05A),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.monitor_heart_outlined,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 6),
                    Text('ParkinsonsTracker',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha:0.55),
                            fontWeight: FontWeight.w500)),
                  ]),
                  Row(children: [
                    _Btn(icon: Icons.history_rounded,   onTap: onHistory),
                    const SizedBox(width: 8),
                    _Btn(icon: Icons.settings_outlined, onTap: onSettings),
                  ]),
                ],
              ),

              const SizedBox(height: 22),

              // Name + ring
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha:0.6))),
                        const SizedBox(height: 2),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.05,
                                letterSpacing: -1.0)),
                        const SizedBox(height: 10),
                        // Wellness label pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha:0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_wellnessLabel,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Ring — empty state when no data yet
                  SizedBox(
                    width: 86,
                    height: 86,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 86, height: 86,
                          child: CircularProgressIndicator(
                            value: hasData ? _wellness : 0.0,
                            strokeWidth: 7,
                            backgroundColor: Colors.white.withValues(alpha:0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                hasData ? Colors.white : Colors.white30),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasData ? '${(_wellness! * 100).round()}' : '––',
                              style: TextStyle(
                                  fontSize: hasData ? 22 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: hasData
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  height: 1.0),
                            ),
                            Text('/100',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white.withValues(alpha:0.55),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Device pill
              Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: device.isConnected
                        ? const Color(0xFF4CD97B)
                        : Colors.white30,
                    shape: BoxShape.circle,
                    boxShadow: device.isConnected ? [
                      BoxShadow(
                        color: const Color(0xFF4CD97B).withValues(alpha:0.6),
                        blurRadius: 6, spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  device.isConnected
                      ? 'Device active  ·  syncing live'
                      : 'Device not connected',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha:0.7),
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.13),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: Colors.white70, size: 17),
      ),
    );
  }
}

// ══ NEXT DOSE BLOCK ══════════════════════════════════════════
class _NextDoseBlock extends StatelessWidget {
  final List<MedicationEntry> meds;
  const _NextDoseBlock({required this.meds});

  @override
  Widget build(BuildContext context) {
    if (meds.isEmpty) return const SizedBox.shrink();
    final med      = meds.first;
    final nextTime = med.scheduledTimes.length > 1
        ? med.scheduledTimes[1]
        : med.scheduledTimes.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE5A0), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE9A020).withValues(alpha:0.12),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4820F), Color(0xFFE9A020)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.medication_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          const Text('Next dose',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB8690F),
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(nextTime,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92530A),
                  letterSpacing: -0.5)),
          Text(med.name.split('/').first.trim(),
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB8690F))),
        ],
      ),
    );
  }
}

// ══ CHECK-IN BLOCK ════════════════════════════════════════════
class _CheckInBlock extends StatelessWidget {
  final List<WellbeingCheckIn> checkIns;
  const _CheckInBlock({required this.checkIns});

  bool get _doneToday {
    if (checkIns.isEmpty) return false;
    final now = DateTime.now();
    final last = checkIns.first.date;
    return last.year == now.year && last.month == now.month && last.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    if (_doneToday) {
      final score = checkIns.first.feelingScore;
      final color = score == 3
          ? const Color(0xFF1A6B3E)
          : score == 2
              ? const Color(0xFFB8690F)
              : const Color(0xFFAB2828);
      final bg = score == 3
          ? const Color(0xFFEEF9F3)
          : score == 2
              ? const Color(0xFFFFF8EC)
              : const Color(0xFFFDF0F0);
      final icon = score == 3
          ? Icons.sentiment_satisfied_alt_rounded
          : score == 2
              ? Icons.sentiment_neutral_rounded
              : Icons.sentiment_dissatisfied_rounded;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: color.withValues(alpha:0.2), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 10),
            Text('Feeling',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha:0.7),
                    letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Text(checkIns.first.feelingLabel,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text('Today\'s check-in',
                style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha:0.6))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A6B3E), Color(0xFF28A05A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A6B3E).withValues(alpha:0.3),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
                Icons.sentiment_satisfied_alt_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          const Text('Check-in',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          const Text('How are\nyou?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Tap to log',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ══ SYMPTOM BLOCK ════════════════════════════════════════════
class _SymptomBlock extends StatelessWidget {
  final String label;
  final String value;
  final double score;
  final IconData icon;
  const _SymptomBlock({
    required this.label, required this.value,
    required this.score, required this.icon,
  });

  Color get _accent {
    if (score < 0.5) return const Color(0xFF1A6B3E);
    if (score < 1.5) return const Color(0xFFB8690F);
    if (score < 2.5) return const Color(0xFFD04A0A);
    return const Color(0xFFAB2828);
  }

  Color get _bg {
    if (score < 0.5) return const Color(0xFFEEF9F3);
    if (score < 1.5) return const Color(0xFFFFF8EC);
    if (score < 2.5) return const Color(0xFFFFF3EC);
    return const Color(0xFFFDF0F0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha:0.15), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha:0.08),
            blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                  letterSpacing: -0.3)),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: _accent.withValues(alpha:0.7),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score == 0 ? 0.04 : score / 4.0,
              minHeight: 4,
              backgroundColor: _accent.withValues(alpha:0.12),
              valueColor: AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ══ NO DATA CARD ═════════════════════════════════════════════
class _NoDataCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBE5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.neutral200, width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.watch_outlined, size: 20, color: AppTheme.neutral400),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'No data collected yet.\nWear your device and connect it to begin monitoring.',
            style: TextStyle(fontSize: 13, color: AppTheme.neutral500, height: 1.45),
          ),
        ),
      ]),
    );
  }
}

// ══ UPDATED LABEL ════════════════════════════════════════════
class _UpdatedLabel extends StatelessWidget {
  final DateTime timestamp;
  const _UpdatedLabel(this.timestamp);

  String _timeAgo() {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 2) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(children: [
        const Icon(Icons.access_time_rounded,
            size: 11, color: AppTheme.neutral400),
        const SizedBox(width: 4),
        Text('Updated ${_timeAgo()}',
            style: const TextStyle(
                fontSize: 11, color: AppTheme.neutral400)),
      ]),
    );
  }
}

// ══ TITLE ════════════════════════════════════════════════════
class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
            letterSpacing: -0.3));
  }
}

// ══ WEEK CARD ════════════════════════════════════════════════
class _WeekCard extends StatelessWidget {
  final List<WellbeingCheckIn> checkIns;
  const _WeekCard({required this.checkIns});

  @override
  Widget build(BuildContext context) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now  = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1917).withValues(alpha:0.06),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final checkIn = i < checkIns.length
              ? checkIns[checkIns.length - 1 - i]
              : null;
          final score   = checkIn?.feelingScore;
          final dayIdx  = (now.weekday - 1 - (6 - i)) % 7;
          final isToday = i == 6;

          final bg = score == null
              ? const Color(0xFFF0EBE5)
              : score == 3
                  ? const Color(0xFFD4F2E2)
                  : score == 2
                      ? const Color(0xFFFADFA0)
                      : const Color(0xFFF8DADA);

          final iconColor = score == null
              ? const Color(0xFFC4BDB8)
              : score == 3
                  ? const Color(0xFF1A6B3E)
                  : score == 2
                      ? const Color(0xFFB8690F)
                      : const Color(0xFFAB2828);

          final icon = score == null
              ? Icons.remove
              : score == 3
                  ? Icons.sentiment_satisfied_alt_rounded
                  : score == 2
                      ? Icons.sentiment_neutral_rounded
                      : Icons.sentiment_dissatisfied_rounded;

          return Column(children: [
            Text(
              days[dayIdx],
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color: isToday
                      ? const Color(0xFF1A6B3E)
                      : const Color(0xFFA8A29E)),
            ),
            const SizedBox(height: 6),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(
                        color: const Color(0xFF2D9E63), width: 2)
                    : null,
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
          ]);
        }),
      ),
    );
  }
}

// ══ REASSURANCE BAR ══════════════════════════════════════════
class _ReassuranceBar extends StatelessWidget {
  final bool isConnected;
  const _ReassuranceBar({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isConnected
            ? const Color(0xFFEEF9F3)
            : const Color(0xFFF0EBE5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF2D9E63).withValues(alpha:0.25)
              : const Color(0xFFC4BDB8),
          width: 0.5,
        ),
      ),
      child: Row(children: [
        Icon(
          isConnected
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          size: 18,
          color: isConnected
              ? const Color(0xFF1A6B3E)
              : const Color(0xFFA8A29E),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isConnected
                ? 'Device collecting data · care team can see your progress'
                : 'Device not connected — open Device settings to reconnect',
            style: TextStyle(
                fontSize: 12,
                color: isConnected
                    ? const Color(0xFF1A6B3E)
                    : const Color(0xFF78716C),
                height: 1.4),
          ),
        ),
      ]),
    );
  }
}