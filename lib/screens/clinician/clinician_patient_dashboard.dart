import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../models/patient_data.dart';
import '../../widgets/shared/shared_widgets.dart';

// ============================================================
// CLINICIAN PATIENT DASHBOARD
// Tabbed view: Overview | Symptoms | Medication | Gait | Reports
// ============================================================

class ClinicianPatientDashboard extends StatefulWidget {
  final String patientId;
  const ClinicianPatientDashboard({super.key, required this.patientId});

  @override
  State<ClinicianPatientDashboard> createState() =>
      _ClinicianPatientDashboardState();
}

class _ClinicianPatientDashboardState
    extends State<ClinicianPatientDashboard>
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
    final svc = Provider.of<AppDataService>(context);
    final patient = svc.getPatient(widget.patientId);
    if (patient == null) return const Scaffold(body: Center(child: Text('Patient not found')));

    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      appBar: AppBar(
        backgroundColor: AppTheme.neutral50,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(patient.name),
            Text(
              '${patient.age}y · Dx ${patient.diagnosisYear} · ${StatusBadgeText(patient.statusFlag)}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.neutral500),
            ),
          ],
        ),
        actions: [
          StatusPill(flag: patient.statusFlag),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTheme.teal600,
          unselectedLabelColor: AppTheme.neutral400,
          indicatorColor: AppTheme.teal600,
          indicatorWeight: 2,
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500),
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
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverviewTab(patient: patient, svc: svc),
          _SymptomsTab(patient: patient, svc: svc),
          _MedicationTab(patient: patient, svc: svc),
          _GaitTab(patient: patient, svc: svc),
          _ReportsTab(patient: patient),
        ],
      ),
    );
  }
}

String StatusBadgeText(String flag) {
  switch (flag) {
    case 'needs-attention': return 'Needs attention';
    case 'monitor': return 'Monitor';
    default: return 'Stable';
  }
}

// ============================================================
// TAB 1: OVERVIEW
// ============================================================
class _OverviewTab extends StatelessWidget {
  final Patient patient;
  final AppDataService svc;
  const _OverviewTab({required this.patient, required this.svc});

  @override
  Widget build(BuildContext context) {
    final snapshot = patient.latestSnapshot;
    final baseline = patient.baselineSnapshot;
    final device   = patient.deviceStatus;
    final state    = svc.sensorDataState;
    final syncAge  = svc.lastSyncAge;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
      children: [
        // Device & sync status
        DeviceStatusBar(
          isConnected: device.isConnected,
          batteryPercent: device.batteryPercent,
          isPatientView: false,
        ),
        const SizedBox(height: 16),

        // Current vs baseline — only when both are real
        const SectionHeader(title: 'Current vs baseline'),
        if (snapshot != null && baseline != null) ...[
          SensorCardShell(
            state: state,
            lastSyncAge: syncAge,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _BaselineTile(label: 'Tremor',
                        current: snapshot.tremorScore, baseline: baseline.tremorScore)),
                    const SizedBox(width: 10),
                    Expanded(child: _BaselineTile(label: 'Bradykinesia',
                        current: snapshot.bradykinesiaScore, baseline: baseline.bradykinesiaScore)),
                  ],
                ),
                const SizedBox(height: 10),
                _BaselineTile(label: 'Dyskinesia',
                    current: snapshot.dyskinesiaScore, baseline: baseline.dyskinesiaScore),
              ],
            ),
          ),
        ] else if (!svc.isBaselineComplete) ...[
          _ClinicalInfoCard(
            icon: Icons.timeline_rounded,
            message: 'Baseline collection in progress — comparison will be available after the 24-hour window.',
            color: AppTheme.teal600,
            bgColor: AppTheme.teal50,
            borderColor: AppTheme.teal100,
          ),
        ] else ...[
          SensorCardShell(
            state: state,
            lastSyncAge: syncAge,
            child: const SizedBox.shrink(),
          ),
        ],
        const SizedBox(height: 16),

        // Current symptom scores — sensor-derived, gated
        const SectionHeader(title: 'Current symptom scores (MDS-UPDRS)'),
        SensorCardShell(
          state: state,
          lastSyncAge: syncAge,
          child: snapshot != null
              ? AppCard(
                  child: Column(
                    children: [
                      ScoreBar(label: 'Tremor', score: snapshot.tremorScore, showLabel: false),
                      const SizedBox(height: 12),
                      ScoreBar(label: 'Bradykinesia', score: snapshot.bradykinesiaScore, showLabel: false),
                      const SizedBox(height: 12),
                      ScoreBar(label: 'Dyskinesia', score: snapshot.dyskinesiaScore, showLabel: false),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),

        // Last patient check-in
        const SectionHeader(title: 'Patient self-report'),
        if (patient.checkIns.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _feelingEmoji(patient.checkIns.first.feelingScore),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.checkIns.first.feelingLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Last check-in ${_timeAgo(patient.checkIns.first.date)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.neutral400),
                        ),
                      ],
                    ),
                  ],
                ),
                if ((patient.checkIns.first.symptoms).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: patient.checkIns.first.symptoms
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.neutral100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(s,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.neutral700)),
                            ))
                        .toList(),
                  ),
                ],
                if (patient.checkIns.first.notes != null) ...[
                  const SizedBox(height: 8),
                  Text('"${patient.checkIns.first.notes}"',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.neutral600,
                          fontStyle: FontStyle.italic,
                          height: 1.4)),
                ],
              ],
            ),
          )
        else
          AppCard(
            child: const Text('No check-ins recorded.',
                style: TextStyle(fontSize: 13, color: AppTheme.neutral400)),
          ),
      ],
    );
  }

  String _feelingEmoji(int score) =>
      score == 3 ? '😊' : score == 2 ? '😐' : '😞';

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _BaselineTile extends StatelessWidget {
  final String label;
  final double current;
  final double baseline;
  const _BaselineTile(
      {required this.label, required this.current, required this.baseline});

  double get _delta => current - baseline;
  bool get _worse => _delta > 0.2;
  bool get _better => _delta < -0.2;

  @override
  Widget build(BuildContext context) {
    final color = _worse
        ? AppTheme.red400
        : _better
            ? AppTheme.teal500
            : AppTheme.neutral700;
    final bg = _worse
        ? AppTheme.red50
        : _better
            ? AppTheme.teal50
            : Colors.white;
    final arrow = _worse ? '↑' : _better ? '↓' : '—';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutral200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.neutral500,
                  fontWeight: FontWeight.w500)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(current.toStringAsFixed(1),
                  style: AppTheme.monoLarge.copyWith(color: color)),
              const SizedBox(width: 4),
              Text(
                '$arrow ${_delta.abs().toStringAsFixed(1)}',
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// ============================================================
// TAB 2: SYMPTOMS — 7-day trends with full chart
// ============================================================
class _SymptomsTab extends StatelessWidget {
  final Patient patient;
  final AppDataService svc;
  const _SymptomsTab({required this.patient, required this.svc});

  @override
  Widget build(BuildContext context) {
    final snapshots = svc.getWeeklySnapshots(patient.id);
    final state     = svc.sensorDataState;
    final syncAge   = svc.lastSyncAge;

    if (snapshots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SensorCardShell(
          state: state,
          lastSyncAge: syncAge,
          child: const SizedBox.shrink(),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
      children: [
        // Stale/disconnected banner sits above the charts, not per-chart.
        if (state == SensorDataState.stale || state == SensorDataState.disconnected)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SensorCardShell(
              state: state,
              lastSyncAge: syncAge,
              child: const SizedBox.shrink(),
            ),
          ),
        const SectionHeader(title: '7-day tremor score'),
        AppCard(
          child: _ClinicalLineChart(
            snapshots: snapshots,
            getValue: (s) => s.tremorScore,
            color: AppTheme.teal500,
            baseline: patient.baselineSnapshot?.tremorScore,
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: '7-day bradykinesia score'),
        AppCard(
          child: _ClinicalLineChart(
            snapshots: snapshots,
            getValue: (s) => s.bradykinesiaScore,
            color: AppTheme.blue400,
            baseline: patient.baselineSnapshot?.bradykinesiaScore,
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: '7-day dyskinesia score'),
        AppCard(
          child: _ClinicalLineChart(
            snapshots: snapshots,
            getValue: (s) => s.dyskinesiaScore,
            color: AppTheme.amber400,
            baseline: patient.baselineSnapshot?.dyskinesiaScore,
          ),
        ),
        const SizedBox(height: 16),
        // Data table
        const SectionHeader(title: 'Daily values'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.neutral50,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Row(
                  children: [
                    Expanded(child: Text('Day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.neutral500))),
                    _HeaderCell('Tremor'),
                    _HeaderCell('Brady.'),
                    _HeaderCell('Dysk.'),
                  ],
                ),
              ),
              const Divider(height: 0),
              ...snapshots.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_dayLabel(s.timestamp, i),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.neutral700)),
                          ),
                          _ScoreCell(s.tremorScore),
                          _ScoreCell(s.bradykinesiaScore),
                          _ScoreCell(s.dyskinesiaScore),
                        ],
                      ),
                    ),
                    if (i < snapshots.length - 1)
                      const Divider(height: 0, indent: 16),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  String _dayLabel(DateTime dt, int i) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}';
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.neutral500)),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  final double score;
  const _ScoreCell(this.score);

  Color get _color {
    if (score < 1.0) return AppTheme.teal500;
    if (score < 2.0) return AppTheme.amber400;
    if (score < 3.0) return const Color(0xFFE07B30);
    return AppTheme.red400;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Text(
        score.toStringAsFixed(1),
        textAlign: TextAlign.center,
        style: AppTheme.mono.copyWith(fontSize: 13, color: _color),
      ),
    );
  }
}

// ============================================================
// TAB 3: MEDICATION — the centrepiece clinical insight
// ============================================================
class _MedicationTab extends StatelessWidget {
  final Patient patient;
  final AppDataService svc;
  const _MedicationTab({required this.patient, required this.svc});

  @override
  Widget build(BuildContext context) {
    final responsePoints = svc.getMedicationResponse(patient.id);
    final meds = svc.getMedications(patient.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
      children: [
        // Key insight banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.teal50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.teal100, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.insights_rounded,
                  color: AppTheme.teal600, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                    'Symptoms tracked against dose timing. Best response 30–180 min post-dose. '
                    'Wearing-off starts ~3 hours after dose.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.teal700,
                        height: 1.4)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // CORE CLINICAL CHART: Symptom score vs time since dose
        const SectionHeader(title: 'Symptom score vs time since dose'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Legend
              Wrap(
                spacing: 16,
                children: [
                  _LegendItem(color: AppTheme.teal500, label: 'Tremor'),
                  _LegendItem(color: AppTheme.blue400, label: 'Bradykinesia'),
                  _LegendItem(color: AppTheme.amber400, label: 'Dyskinesia'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: _MedResponseChart(points: responsePoints),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text('Minutes since last dose →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.neutral400,
                            letterSpacing: 0.3)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Medication schedule
        const SectionHeader(title: 'Current medications'),
        ...meds.map((med) {
          final color = Color(int.parse(
              'FF${med.color.replaceAll('#', '')}',
              radix: 16));
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(med.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(med.dose,
                            style: AppTheme.mono
                                .copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Schedule',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.neutral400)),
                      Text(med.scheduledTimes.join(' · '),
                          style: AppTheme.mono
                              .copyWith(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 2, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

class _MedResponseChart extends StatelessWidget {
  final List<MedicationResponsePoint> points;
  const _MedResponseChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final tremorSpots = points.map((p) =>
        FlSpot(p.minutesSinceDose, p.tremorScore)).toList();
    final bradySpots = points.map((p) =>
        FlSpot(p.minutesSinceDose, p.bradykinesiaScore)).toList();
    final dyskSpots = points.map((p) =>
        FlSpot(p.minutesSinceDose, p.dyskinesiaScore)).toList();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 360,
        minY: 0,
        maxY: 4,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 60,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppTheme.neutral100, strokeWidth: 0.5),
          getDrawingVerticalLine: (_) =>
              FlLine(color: AppTheme.neutral100, strokeWidth: 0.5, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: AppTheme.neutral200, width: 0.5),
            left: BorderSide(color: AppTheme.neutral200, width: 0.5),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: AppTheme.mono.copyWith(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 60,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}m',
                style: AppTheme.mono.copyWith(fontSize: 10),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: tremorSpots,
            color: AppTheme.teal500,
            barWidth: 2,
            isCurved: true,
            curveSmoothness: 0.3,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: bradySpots,
            color: AppTheme.blue400,
            barWidth: 2,
            isCurved: true,
            curveSmoothness: 0.3,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: dyskSpots,
            color: AppTheme.amber400,
            barWidth: 2,
            isCurved: true,
            curveSmoothness: 0.3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _ClinicalLineChart extends StatelessWidget {
  final List<SymptomSnapshot> snapshots;
  final double Function(SymptomSnapshot) getValue;
  final Color color;
  final double? baseline;

  const _ClinicalLineChart({
    required this.snapshots,
    required this.getValue,
    required this.color,
    this.baseline,
  });

  @override
  Widget build(BuildContext context) {
    final spots = snapshots.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), getValue(e.value))).toList();

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 4,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.neutral100, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              bottom: BorderSide(color: AppTheme.neutral200, width: 0.5),
              left: BorderSide(color: AppTheme.neutral200, width: 0.5),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: AppTheme.mono.copyWith(fontSize: 10),
                ),
              ),
            ),
          ),
          extraLinesData: baseline != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: baseline!,
                    color: AppTheme.neutral300,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      labelResolver: (_) => 'baseline',
                      style: TextStyle(fontSize: 9, color: AppTheme.neutral400),
                    ),
                  ),
                ])
              : null,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: color,
              barWidth: 2,
              isCurved: true,
              curveSmoothness: 0.3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.07),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================================================
// TAB 4: GAIT
// ============================================================
class _GaitTab extends StatelessWidget {
  final Patient patient;
  final AppDataService svc;
  const _GaitTab({required this.patient, required this.svc});

  @override
  Widget build(BuildContext context) {
    final gait       = svc.getLatestGait(patient.id);
    final weeklyGait = svc.getWeeklyGait(patient.id);

    if (gait == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SensorCardShell(
          state: svc.sensorDataState,
          lastSyncAge: svc.lastSyncAge,
          child: const SizedBox.shrink(),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
      children: [
        // Key gait metrics grid
        const SectionHeader(title: 'Current gait metrics'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            MetricTile(
              label: 'Stride length',
              value: gait.strideLength.toStringAsFixed(2),
              unit: 'm',
              icon: Icons.straighten_rounded,
            ),
            MetricTile(
              label: 'Step frequency',
              value: gait.stepFrequency.toStringAsFixed(0),
              unit: 'steps/min',
              icon: Icons.speed_rounded,
            ),
            MetricTile(
              label: 'Walking speed',
              value: gait.walkingSpeed.toStringAsFixed(2),
              unit: 'm/s',
              icon: Icons.directions_walk_rounded,
            ),
            MetricTile(
              label: 'Gait symmetry',
              value: (gait.gaitSymmetry * 100).toStringAsFixed(0),
              unit: '%',
              valueColor: gait.gaitSymmetry > 0.80
                  ? AppTheme.teal500
                  : AppTheme.amber400,
              icon: Icons.balance_rounded,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Arm swing score
        const SectionHeader(title: 'Arm swing asymmetry'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScoreBar(
                label: 'Arm swing reduction (MDS-UPDRS)',
                score: gait.armSwingScore,
                showLabel: false,
              ),
              const SizedBox(height: 6),
              Text(
                'Score ${gait.armSwingScore.toStringAsFixed(1)} / 4.0 · '
                '${gait.armSwingScore < 1.5 ? 'Normal' : gait.armSwingScore < 2.5 ? 'Mild reduction' : 'Significant reduction'}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.neutral500),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 7-day walking speed trend
        if (weeklyGait.isNotEmpty) ...[
          const SectionHeader(title: '7-day walking speed'),
          AppCard(
            child: Column(
              children: [
                SizedBox(
                  height: 140,
                  child: _GaitTrendChart(
                    weeklyGait: weeklyGait,
                    getValue: (g) => g.walkingSpeed,
                    color: AppTheme.teal500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: weeklyGait.map((g) => Text(
                    '${g.timestamp.day}/${g.timestamp.month}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.neutral400),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: '7-day gait symmetry'),
          AppCard(
            child: Column(
              children: [
                SizedBox(
                  height: 140,
                  child: _GaitTrendChart(
                    weeklyGait: weeklyGait,
                    getValue: (g) => g.gaitSymmetry * 4,
                    color: AppTheme.blue400,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: weeklyGait.map((g) => Text(
                    '${g.timestamp.day}/${g.timestamp.month}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.neutral400),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GaitTrendChart extends StatelessWidget {
  final List<GaitMetrics> weeklyGait;
  final double Function(GaitMetrics) getValue;
  final Color color;
  const _GaitTrendChart({
    required this.weeklyGait, required this.getValue, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spots = weeklyGait.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), getValue(e.value))).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 4,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppTheme.neutral100, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: AppTheme.mono.copyWith(fontSize: 9),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: color,
            barWidth: 2.5,
            isCurved: true,
            curveSmoothness: 0.3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.06),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 5: REPORTS
// ============================================================
class _ReportsTab extends StatelessWidget {
  final Patient patient;
  const _ReportsTab({required this.patient});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Generate report'),
              const Text(
                'Create a structured clinical report summarising recent symptom data, '
                'medication response, and gait metrics for referral or record keeping.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.neutral500,
                    height: 1.4),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PDF generation coming soon'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
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
        const SectionHeader(title: 'Report includes'),
        AppCard(
          child: Column(
            children: const [
              _ReportIncludesRow('7-day symptom trends', Icons.show_chart_rounded),
              Divider(height: 20),
              _ReportIncludesRow('Medication response curve', Icons.medication_rounded),
              Divider(height: 20),
              _ReportIncludesRow('Gait analysis summary', Icons.directions_walk_rounded),
              Divider(height: 20),
              _ReportIncludesRow('Patient self-report check-ins', Icons.sentiment_satisfied_alt_rounded),
              Divider(height: 20),
              _ReportIncludesRow('Baseline comparison', Icons.compare_arrows_rounded),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportIncludesRow extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ReportIncludesRow(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.teal500),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.neutral700)),
        const Spacer(),
        const Icon(Icons.check_rounded,
            size: 16, color: AppTheme.teal400),
      ],
    );
  }
}

// Reusable info banner for clinician empty states (baseline / insufficient data).
class _ClinicalInfoCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _ClinicalInfoCard({
    required this.icon,
    required this.message,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: color, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

const neutral400 = Color(0xFF888780);
const neutral600 = Color(0xFF5F5E5A);
const neutral700 = Color(0xFF3D3D3A);
