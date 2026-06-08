import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../models/patient_data.dart';

// ============================================================
// CLINICIAN PATIENT DASHBOARD v2 — Poster-worthy
// ============================================================

class ClinicianPatientDashboard extends StatefulWidget {
  final String patientId;
  const ClinicianPatientDashboard({super.key, required this.patientId});

  @override
  State<ClinicianPatientDashboard> createState() =>
      _ClinicianPatientDashboardState();
}

class _ClinicianPatientDashboardState extends State<ClinicianPatientDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc     = Provider.of<AppDataService>(context);
    final patient = svc.getPatient(widget.patientId);
    if (patient == null) {
      return const Scaffold(
          body: Center(child: Text('Patient not found')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE8),
      body: Column(
        children: [
          // ── Floating header card ──────────────────────────────
          _PatientHeaderCard(patient: patient, tabs: _tabs),
          // ── Tab content ──────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(patient: patient, svc: svc),
                _SymptomsTab(patient: patient, svc: svc),
                _MedicationTab(patient: patient, svc: svc),
                _GaitTab(patient: patient, svc: svc),
                _ReportsTab(patient: patient),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating header card (matches screenshot style) ───────────
class _PatientHeaderCard extends StatelessWidget {
  final Patient patient;
  final TabController tabs;
  const _PatientHeaderCard({required this.patient, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      margin: EdgeInsets.zero,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F3D24), Color(0xFF1A6B3E)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar: back button + actions ──
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Clinician view',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.more_horiz_rounded,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Patient name + score ring ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.1),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${patient.age}y · Dx ${patient.diagnosisYear} · ${patient.assignedClinicianId}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Score ring — mirrors the 74/100 ring in the screenshot
                _ScoreRing(
                  score: patient.latestSnapshot != null
                      ? _overallScore(patient.latestSnapshot!)
                      : 0,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Device status + status badge ──
            Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: patient.deviceStatus.isConnected
                        ? const Color(0xFF4CD97B)
                        : Colors.white38,
                    shape: BoxShape.circle,
                    boxShadow: patient.deviceStatus.isConnected
                        ? [BoxShadow(
                            color: const Color(0xFF4CD97B).withValues(alpha: 0.6),
                            blurRadius: 6)]
                        : null,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  patient.deviceStatus.isConnected
                      ? 'Device active · syncing live'
                      : 'Device offline',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7)),
                ),
                const Spacer(),
                _StatusBadge(flag: patient.statusFlag),
              ],
            ),

            const SizedBox(height: 16),

            // ── TabBar inside the card so it clips with the rounded corners ──
            TabBar(
              controller: tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              indicatorColor: const Color(0xFF4CD97B),
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w400),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Symptoms'),
                Tab(text: 'Medication'),
                Tab(text: 'Gait'),
                Tab(text: 'Reports'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _overallScore(SymptomSnapshot s) {
    final avg = (s.tremorScore + s.bradykinesiaScore +
                 s.dyskinesiaScore + s.rigidityScore) / 4;
    return ((1 - avg / 4) * 100).round().clamp(0, 100);
  }
}

// ── Score ring (matches the 74/100 circle in the screenshot) ──
class _ScoreRing extends StatelessWidget {
  final int score;
  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72, height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72, height: 72,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1)),
              Text('/100',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String flag;
  const _StatusBadge({required this.flag});

  @override
  Widget build(BuildContext context) {
    final color = flag == 'needs-attention'
        ? const Color(0xFFD94F4F)
        : flag == 'monitor'
            ? const Color(0xFFE9A020)
            : const Color(0xFF4CD97B);
    final label = flag == 'needs-attention'
        ? 'Needs attention'
        : flag == 'monitor'
            ? 'Monitor'
            : 'Stable';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ══ TAB 1: OVERVIEW ══════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final Patient patient;
  final AppDataService svc;
  const _OverviewTab({required this.patient, required this.svc});

  @override
  Widget build(BuildContext context) {
    final snapshot = patient.latestSnapshot;
    final baseline = patient.baselineSnapshot;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Current vs baseline
        if (snapshot != null && baseline != null) ...[
          _CardLabel('Current vs baseline  ·  MDS-UPDRS scale 0–4'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _BaselineCard(
              label: 'Tremor',
              current: snapshot.tremorScore,
              baseline: baseline.tremorScore,
            )),
            const SizedBox(width: 10),
            Expanded(child: _BaselineCard(
              label: 'Bradykinesia',
              current: snapshot.bradykinesiaScore,
              baseline: baseline.bradykinesiaScore,
            )),
            const SizedBox(width: 10),
            Expanded(child: _BaselineCard(
              label: 'Dyskinesia',
              current: snapshot.dyskinesiaScore,
              baseline: baseline.dyskinesiaScore,
            )),
            const SizedBox(width: 10),
            Expanded(child: _BaselineCard(
              label: 'Rigidity',
              current: snapshot.rigidityScore,
              baseline: baseline.rigidityScore,
            )),
          ]),
          const SizedBox(height: 20),
        ],

        // Score bars
        _CardLabel('Current symptom scores'),
        const SizedBox(height: 10),
        _ClinicalCard(
          child: Column(children: [
            if (snapshot != null) ...[
              _ClinicalScoreBar('Tremor', snapshot.tremorScore),
              const SizedBox(height: 14),
              _ClinicalScoreBar('Bradykinesia', snapshot.bradykinesiaScore),
              const SizedBox(height: 14),
              _ClinicalScoreBar('Dyskinesia', snapshot.dyskinesiaScore),
              const SizedBox(height: 14),
              _ClinicalScoreBar('Rigidity', snapshot.rigidityScore),
            ],
          ]),
        ),

        const SizedBox(height: 20),

        // Patient self-report
        _CardLabel('Patient self-report'),
        const SizedBox(height: 10),
        _ClinicalCard(
          child: patient.checkIns.isEmpty
              ? const Text('No check-ins recorded.',
                  style: TextStyle(fontSize: 13, color: AppTheme.neutral400))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        patient.checkIns.first.feelingScore == 3
                            ? '😊' : patient.checkIns.first.feelingScore == 2
                            ? '😐' : '😞',
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patient.checkIns.first.feelingLabel,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(_timeAgo(patient.checkIns.first.date),
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.neutral400)),
                        ],
                      ),
                    ]),
                    if (patient.checkIns.first.symptoms.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, children:
                        patient.checkIns.first.symptoms.map((s) =>
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.neutral100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(s, style: const TextStyle(
                                fontSize: 11, color: AppTheme.neutral700)),
                          ),
                        ).toList(),
                      ),
                    ],
                    if (patient.checkIns.first.notes != null) ...[
                      const SizedBox(height: 8),
                      Text('"${patient.checkIns.first.notes}"',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.neutral500,
                              fontStyle: FontStyle.italic, height: 1.4)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ══ TAB 2: SYMPTOMS ═══════════════════════════════════════════
class _SymptomsTab extends StatelessWidget {
  final Patient patient;
  final AppDataService svc;
  const _SymptomsTab({required this.patient, required this.svc});

  @override
  Widget build(BuildContext context) {
    final snapshots = svc.getWeeklySnapshots(patient.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _CardLabel('7-day tremor  ·  MDS-UPDRS'),
        const SizedBox(height: 10),
        _ClinicalCard(child: _RichChart(
          snapshots: snapshots,
          getValue: (s) => s.tremorScore,
          color: const Color(0xFF2D9E63),
          baseline: patient.baselineSnapshot?.tremorScore,
          label: 'Tremor score',
        )),
        const SizedBox(height: 16),

        _CardLabel('7-day bradykinesia  ·  MDS-UPDRS'),
        const SizedBox(height: 10),
        _ClinicalCard(child: _RichChart(
          snapshots: snapshots,
          getValue: (s) => s.bradykinesiaScore,
          color: const Color(0xFF3B82D4),
          baseline: patient.baselineSnapshot?.bradykinesiaScore,
          label: 'Bradykinesia score',
        )),
        const SizedBox(height: 16),

        _CardLabel('7-day dyskinesia  ·  MDS-UPDRS'),
        const SizedBox(height: 10),
        _ClinicalCard(child: _RichChart(
          snapshots: snapshots,
          getValue: (s) => s.dyskinesiaScore,
          color: const Color(0xFFE9A020),
          baseline: patient.baselineSnapshot?.dyskinesiaScore,
          label: 'Dyskinesia score',
        )),
        const SizedBox(height: 16),

        // Data table
        _CardLabel('Daily values'),
        const SizedBox(height: 10),
        _ClinicalCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF2EDE8),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16)),
              ),
              child: const Row(children: [
                Expanded(child: Text('Day',
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.neutral500))),
                _TH('Tremor'),
                _TH('Brady.'),
                _TH('Dysk.'),
              ]),
            ),
            const Divider(height: 0),
            ...snapshots.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              final diff = DateTime.now().difference(s.timestamp).inDays;
              final dayLabel = diff == 0 ? 'Today'
                  : diff == 1 ? 'Yesterday'
                  : '${s.timestamp.day}/${s.timestamp.month}';
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  child: Row(children: [
                    Expanded(child: Text(dayLabel,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.neutral700,
                            fontWeight: FontWeight.w500))),
                    _ScoreCell(s.tremorScore),
                    _ScoreCell(s.bradykinesiaScore),
                    _ScoreCell(s.dyskinesiaScore),
                  ]),
                ),
                if (i < snapshots.length - 1)
                  const Divider(height: 0, indent: 16),
              ]);
            }),
          ]),
        ),
      ],
    );
  }
}

// ══ TAB 3: MEDICATION — THE HERO SCREEN ══════════════════════
class _MedicationTab extends StatelessWidget {
  final Patient patient;
  final AppDataService svc;
  const _MedicationTab({required this.patient, required this.svc});

  @override
  Widget build(BuildContext context) {
    final responsePoints = svc.getMedicationResponse(patient.id);
    final meds = svc.getMedications(patient.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [

        // Key insight banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3D24), Color(0xFF1A6B3E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A6B3E).withValues(alpha: 0.3),
                blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clinical insight',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: Colors.white70, letterSpacing: 0.3)),
                    SizedBox(height: 3),
                    Text(
                      'Peak therapeutic window: 30–180 min post-dose. '
                      'Wearing-off detected ~3h after dose. '
                      'Consider dose interval adjustment.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.white, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // THE CENTREPIECE CHART
        _CardLabel('Symptom score vs time since dose'),
        const SizedBox(height: 10),
        _ClinicalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Legend
              Wrap(spacing: 16, children: [
                _Legend(color: const Color(0xFF2D9E63), label: 'Tremor'),
                _Legend(color: const Color(0xFF3B82D4), label: 'Bradykinesia'),
                _Legend(color: const Color(0xFFE9A020), label: 'Dyskinesia'),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: _MedResponseChart(points: responsePoints),
              ),
              const SizedBox(height: 8),
              // Zone labels
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF9F3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('← Onset',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10,
                            color: Color(0xFF1A6B3E),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF9F3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Peak therapeutic window',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10,
                            color: Color(0xFF1A6B3E),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF0F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Wearing off →',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10,
                            color: Color(0xFFAB2828),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              const Center(
                child: Text('Minutes since last dose →',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.neutral400)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Medication schedule
        _CardLabel('Current medications'),
        const SizedBox(height: 10),
        ...meds.map((med) {
          final color = Color(int.parse(
              'FF${med.color.replaceAll('#', '')}', radix: 16));
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ClinicalCard(
              child: Row(children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(med.dose, style: AppTheme.mono.copyWith(
                        fontSize: 12, color: AppTheme.neutral500)),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Schedule', style: TextStyle(
                        fontSize: 10, color: AppTheme.neutral400,
                        fontWeight: FontWeight.w500)),
                    Text(med.scheduledTimes.join(' · '),
                        style: AppTheme.mono.copyWith(fontSize: 12)),
                  ],
                ),
              ]),
            ),
          );
        }),
      ],
    );
  }
}

// ── Medication response chart ──────────────────────────────────
class _MedResponseChart extends StatelessWidget {
  final List<MedicationResponsePoint> points;
  const _MedResponseChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
          child: Text('Insufficient data', style: TextStyle(
              color: AppTheme.neutral400)));
    }

    final tremorSpots = points.map((p) =>
        FlSpot(p.minutesSinceDose, p.tremorScore)).toList();
    final bradySpots = points.map((p) =>
        FlSpot(p.minutesSinceDose, p.bradykinesiaScore)).toList();
    final dyskSpots = points.map((p) =>
        FlSpot(p.minutesSinceDose, p.dyskinesiaScore)).toList();

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: const Color(0xFFEDE8E3),
            tooltipRoundedRadius: 8,
            tooltipBorder: const BorderSide(color: Color(0xFFD6CFC8)),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(2),
                  TextStyle(
                    color: spot.bar.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minX: 0, maxX: 360,
        minY: 0, maxY: 4,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 60,
          getDrawingHorizontalLine: (_) => FlLine(
              color: const Color(0xFFF0EBE5), strokeWidth: 1),
          getDrawingVerticalLine: (_) => FlLine(
              color: const Color(0xFFF0EBE5),
              strokeWidth: 1,
              dashArray: [4, 4]),
        ),
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: [
            VerticalRangeAnnotation(
              x1: 30, x2: 180,
              color: const Color(0xFF2D9E63).withValues(alpha: 0.06),
            ),
          ],
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: const Color(0xFFE7E0DA), width: 1),
            left:   BorderSide(color: const Color(0xFFE7E0DA), width: 1),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 30,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: AppTheme.mono.copyWith(
                    fontSize: 10, color: AppTheme.neutral400),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 60,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}m',
                style: AppTheme.mono.copyWith(
                    fontSize: 10, color: AppTheme.neutral400),
              ),
            ),
          ),
        ),
        lineBarsData: [
          _line(tremorSpots, const Color(0xFF2D9E63), 2.5),
          _line(bradySpots,  const Color(0xFF3B82D4), 2.5),
          _line(dyskSpots,   const Color(0xFFE9A020), 2.0),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, double width) {
    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: width,
      isCurved: true,
      curveSmoothness: 0.35,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.05),
      ),
    );
  }
}

// ══ TAB 4: GAIT ═══════════════════════════════════════════════
class _GaitTab extends StatelessWidget {
  final Patient patient;
  final AppDataService svc;
  const _GaitTab({required this.patient, required this.svc});

  @override
  Widget build(BuildContext context) {
    final gait = svc.getLatestGait(patient.id);
    final weeklyGait = svc.getWeeklyGait(patient.id);

    if (gait == null) {
      return const Center(
          child: Text('No gait data available.',
              style: TextStyle(color: AppTheme.neutral400)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _CardLabel('Current gait metrics'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _GaitMetricCard(
            label: 'Stride length',
            value: gait.strideLength.toStringAsFixed(2),
            unit: 'm',
            icon: Icons.straighten_rounded,
          )),
          const SizedBox(width: 10),
          Expanded(child: _GaitMetricCard(
            label: 'Cadence',
            value: gait.stepFrequency.toStringAsFixed(0),
            unit: 'steps/min',
            icon: Icons.speed_rounded,
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _GaitMetricCard(
            label: 'Walking speed',
            value: gait.walkingSpeed.toStringAsFixed(2),
            unit: 'm/s',
            icon: Icons.directions_walk_rounded,
          )),
          const SizedBox(width: 10),
          Expanded(child: _GaitMetricCard(
            label: 'Symmetry',
            value: (gait.gaitSymmetry * 100).toStringAsFixed(0),
            unit: '%',
            icon: Icons.balance_rounded,
            highlight: gait.gaitSymmetry > 0.80,
          )),
        ]),
        const SizedBox(height: 20),

        _CardLabel('7-day walking speed'),
        const SizedBox(height: 10),
        _ClinicalCard(child: _GaitTrendChart(
          weeklyGait: weeklyGait,
          getValue: (g) => g.walkingSpeed,
          color: const Color(0xFF2D9E63),
        )),
      ],
    );
  }
}

class _GaitMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final bool highlight;
  const _GaitMetricCard({
    required this.label, required this.value,
    required this.unit, required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFEEF9F3)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1917).withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18,
              color: highlight
                  ? const Color(0xFF1A6B3E)
                  : AppTheme.neutral400),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTheme.monoLarge.copyWith(
                  color: highlight
                      ? const Color(0xFF1A6B3E)
                      : AppTheme.neutral900,
                  fontSize: 20)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(
                  fontSize: 10, color: AppTheme.neutral400)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(
              fontSize: 11, color: AppTheme.neutral500,
              fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _GaitTrendChart extends StatelessWidget {
  final List<GaitMetrics> weeklyGait;
  final double Function(GaitMetrics) getValue;
  final Color color;
  const _GaitTrendChart({
    required this.weeklyGait,
    required this.getValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spots = weeklyGait.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), getValue(e.value)))
        .toList();

    return SizedBox(
      height: 140,
      child: LineChart(LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: const Color(0xFFEDE8E3),
            tooltipRoundedRadius: 8,
            tooltipBorder: const BorderSide(color: Color(0xFFD6CFC8)),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(2),
                  TextStyle(
                    color: spot.bar.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minY: 0, maxY: 4,
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          horizontalInterval: 0.5,
          getDrawingHorizontalLine: (_) => FlLine(
              color: const Color(0xFFF0EBE5), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= weeklyGait.length) {
                  return const SizedBox.shrink();
                }
                final dt = weeklyGait[i].timestamp;
                return Text('${dt.day}/${dt.month}',
                    style: const TextStyle(
                        fontSize: 9, color: AppTheme.neutral400));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: AppTheme.mono.copyWith(
                    fontSize: 9, color: AppTheme.neutral400),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: color, barWidth: 2.5,
            isCurved: true, curveSmoothness: 0.3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 3, color: color,
                strokeWidth: 2, strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true, color: color.withValues(alpha: 0.08)),
          ),
        ],
      )),
    );
  }
}

// ══ TAB 5: REPORTS ════════════════════════════════════════════
class _ReportsTab extends StatelessWidget {
  final Patient patient;
  const _ReportsTab({required this.patient});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _ClinicalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardLabel('Generate clinical report'),
              const SizedBox(height: 8),
              const Text(
                'Export a structured report for referral or records. '
                'Includes 7-day symptom trends, medication response '
                'curve, gait analysis, and patient self-reports.',
                style: TextStyle(fontSize: 13,
                    color: AppTheme.neutral500, height: 1.4)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export coming soon'),
                      behavior: SnackBarBehavior.floating)),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download PDF report'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Send to patient record'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CardLabel('Report includes'),
        const SizedBox(height: 10),
        _ClinicalCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _ReportRow('7-day symptom trends', Icons.show_chart_rounded),
            const Divider(height: 0),
            _ReportRow('Medication response curve', Icons.medication_rounded),
            const Divider(height: 0),
            _ReportRow('Gait analysis summary', Icons.directions_walk_rounded),
            const Divider(height: 0),
            _ReportRow('Patient self-report check-ins', Icons.sentiment_satisfied_alt_rounded),
            const Divider(height: 0),
            _ReportRow('Baseline comparison', Icons.compare_arrows_rounded),
          ]),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ReportRow(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF2D9E63)),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.neutral700))),
        const Icon(Icons.check_rounded, size: 16,
            color: Color(0xFF4CD97B)),
      ]),
    );
  }
}

// ══ SHARED COMPONENTS ════════════════════════════════════════

class _ClinicalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _ClinicalCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1917).withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _CardLabel extends StatelessWidget {
  final String text;
  const _CardLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutral500,
            letterSpacing: 0.3));
  }
}

class _BaselineCard extends StatelessWidget {
  final String label;
  final double current;
  final double baseline;
  const _BaselineCard({
    required this.label,
    required this.current,
    required this.baseline,
  });

  double get _delta => current - baseline;
  bool get _worse  => _delta >  0.2;
  bool get _better => _delta < -0.2;

  @override
  Widget build(BuildContext context) {
    final color = _worse
        ? const Color(0xFFD94F4F)
        : _better
            ? const Color(0xFF2D9E63)
            : AppTheme.neutral700;
    final bg = _worse
        ? const Color(0xFFFDF0F0)
        : _better
            ? const Color(0xFFEEF9F3)
            : Colors.white;
    final arrow = _worse ? '↑' : _better ? '↓' : '—';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C1917).withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.neutral500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(current.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(width: 3),
              Text('$arrow${_delta.abs().toStringAsFixed(1)}',
                  style: TextStyle(
                      fontSize: 10, color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClinicalScoreBar extends StatelessWidget {
  final String label;
  final double score;
  const _ClinicalScoreBar(this.label, this.score);

  Color get _color {
    if (score < 1.0) return const Color(0xFF2D9E63);
    if (score < 2.0) return const Color(0xFFE9A020);
    if (score < 3.0) return const Color(0xFFE07030);
    return const Color(0xFFD94F4F);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.neutral700,
                    fontWeight: FontWeight.w500)),
            Text(score.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 4.0,
            minHeight: 7,
            backgroundColor: const Color(0xFFF0EBE5),
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 3,
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(fontSize: 11, color: color,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Text(text, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11,
              fontWeight: FontWeight.w700, color: AppTheme.neutral500)),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  final double score;
  const _ScoreCell(this.score);

  Color get _color {
    if (score < 1.0) return const Color(0xFF2D9E63);
    if (score < 2.0) return const Color(0xFFE9A020);
    if (score < 3.0) return const Color(0xFFE07030);
    return const Color(0xFFD94F4F);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Text(score.toStringAsFixed(1),
          textAlign: TextAlign.center,
          style: AppTheme.mono.copyWith(
              fontSize: 13, color: _color,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _RichChart extends StatelessWidget {
  final List<SymptomSnapshot> snapshots;
  final double Function(SymptomSnapshot) getValue;
  final Color color;
  final double? baseline;
  final String label;

  const _RichChart({
    required this.snapshots, required this.getValue,
    required this.color, required this.label,
    this.baseline,
  });

  @override
  Widget build(BuildContext context) {
    final spots = snapshots.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), getValue(e.value)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: LineChart(LineChartData(
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: const Color(0xFFEDE8E3),
                tooltipRoundedRadius: 8,
                tooltipBorder: const BorderSide(color: Color(0xFFD6CFC8)),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      spot.y.toStringAsFixed(2),
                      TextStyle(
                        color: spot.bar.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            minY: 0, maxY: 4,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: const Color(0xFFF0EBE5), strokeWidth: 1),
            ),
            extraLinesData: baseline != null
                ? ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: baseline!,
                      color: AppTheme.neutral300,
                      strokeWidth: 1,
                      dashArray: [5, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        labelResolver: (_) => 'baseline',
                        style: const TextStyle(
                            fontSize: 9, color: AppTheme.neutral400),
                      ),
                    ),
                  ])
                : null,
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(
                    color: const Color(0xFFE7E0DA), width: 1),
                left: BorderSide(
                    color: const Color(0xFFE7E0DA), width: 1),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 26,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(0),
                    style: AppTheme.mono.copyWith(
                        fontSize: 9, color: AppTheme.neutral400),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                color: color, barWidth: 2.5,
                isCurved: true, curveSmoothness: 0.3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, _, _, _) =>
                      FlDotCirclePainter(
                    radius: 3.5, color: color,
                    strokeWidth: 2, strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true, color: color.withValues(alpha: 0.08)),
              ),
            ],
          )),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: snapshots.map((s) {
            final diff = DateTime.now().difference(s.timestamp).inDays;
            return Text(
              diff == 0 ? 'Today'
                  : diff == 1 ? 'Yest.'
                  : '${s.timestamp.day}/${s.timestamp.month}',
              style: const TextStyle(
                  fontSize: 9, color: AppTheme.neutral400),
            );
          }).toList(),
        ),
      ],
    );
  }
}