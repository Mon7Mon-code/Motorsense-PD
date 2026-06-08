import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../models/patient_data.dart';
import '../../widgets/shared/shared_widgets.dart';

class PatientMyWeekScreen extends StatelessWidget {
  const PatientMyWeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<AppDataService>(context);
    const patientId = 'p001';
    final snapshots = svc.getWeeklySnapshots(patientId);
    final checkIns = svc.getCheckIns(patientId);
    final gait = svc.getLatestGait(patientId);

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE8),
                              appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D24),
        foregroundColor: Colors.white,
        title: const Text('My week',
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
          // Plain language insight cards
          _InsightCard(snapshots: snapshots),
          const SizedBox(height: 16),

          // Tremor chart — patient view (no numbers, just shape)
          const SectionHeader(title: 'Tremor over 7 days'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lower is better',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.neutral400,
                        letterSpacing: 0.3)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: _PatientLineChart(
                    snapshots: snapshots,
                    getValue: (s) => s.tremorScore,
                    color: AppTheme.teal500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _dayLabels(snapshots),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Gait / walking summary
          if (gait != null) ...[
            const SectionHeader(title: 'Walking'),
            AppCard(
              child: Column(
                children: [
                  _WalkingRow(
                    icon: Icons.directions_walk_rounded,
                    label: 'Steps today',
                    value: '${gait.stepCount}',
                    sub: 'Keep it up!',
                  ),
                  const Divider(height: 20),
                  _WalkingRow(
                    icon: Icons.speed_outlined,
                    label: 'Walking rhythm',
                    value: _rhythmLabel(gait.stepFrequency),
                    sub: 'Compared to your usual',
                  ),
                  const Divider(height: 20),
                  _WalkingRow(
                    icon: Icons.balance_outlined,
                    label: 'Balance symmetry',
                    value: _symmetryLabel(gait.gaitSymmetry),
                    sub: 'Left–right balance',
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Wellbeing check-ins history
          const SectionHeader(title: 'Your check-ins this week'),
          ...checkIns.take(7).map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CheckInTile(checkIn: c),
              )),
        ],
      ),
    );
  }

  List<Widget> _dayLabels(List<SymptomSnapshot> snapshots) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now().weekday - 1;
    return List.generate(
        snapshots.length,
        (i) => Text(
              days[(now - (snapshots.length - 1 - i)) % 7],
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.neutral400,
                  fontWeight: FontWeight.w500),
            ));
  }

  String _rhythmLabel(double freq) {
    if (freq > 105) return 'A bit fast';
    if (freq > 90) return 'Normal';
    return 'A bit slow';
  }

  String _symmetryLabel(double sym) {
    if (sym > 0.85) return 'Good';
    if (sym > 0.70) return 'Fair';
    return 'Uneven';
  }
}

// --- Insight card — plain English summary -------------------
class _InsightCard extends StatelessWidget {
  final List<SymptomSnapshot> snapshots;
  const _InsightCard({required this.snapshots});

  String _generateInsight() {
    if (snapshots.length < 2) return 'Not enough data yet.';
    final recent = snapshots.last.tremorScore;
    final prev = snapshots[snapshots.length - 2].tremorScore;
    final diff = recent - prev;

    if (diff < -0.3) return 'Your tremor improved compared to yesterday. Good progress.';
    if (diff > 0.3) return 'Your tremor was slightly higher today. This can be normal — look out for patterns.';
    return 'Your tremor has been fairly stable this week.';
  }

  String _generateBradyInsight() {
    if (snapshots.isEmpty) return '';
    final avg = snapshots.map((s) => s.bradykinesiaScore).reduce((a, b) => a + b) /
        snapshots.length;
    if (avg < 1.0) return 'Your movement speed has been normal this week.';
    if (avg < 2.0) return 'Some slowness of movement detected this week — common with Parkinson\'s.';
    return 'Movement slowness has been more noticeable. Mention this to your clinician.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InsightTile(
          icon: Icons.trending_up_rounded,
          color: AppTheme.teal600,
          bgColor: AppTheme.teal50,
          text: _generateInsight(),
        ),
        const SizedBox(height: 8),
        _InsightTile(
          icon: Icons.directions_walk_rounded,
          color: AppTheme.blue400,
          bgColor: AppTheme.blue50,
          text: _generateBradyInsight(),
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String text;

  const _InsightTile({
    required this.icon, required this.color,
    required this.bgColor, required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: color, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// --- Simple patient-friendly line chart ---------------------
class _PatientLineChart extends StatelessWidget {
  final List<SymptomSnapshot> snapshots;
  final double Function(SymptomSnapshot) getValue;
  final Color color;

  const _PatientLineChart({
    required this.snapshots, required this.getValue, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spots = snapshots.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), getValue(e.value))).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 4,
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppTheme.neutral100, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
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
    );
  }
}

class _WalkingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;

  const _WalkingRow({
    required this.icon, required this.label,
    required this.value, required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.neutral300),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.neutral700)),
              Text(sub,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.neutral400)),
            ],
          ),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutral900)),
      ],
    );
  }
}

class _CheckInTile extends StatelessWidget {
  final dynamic checkIn;
  const _CheckInTile({required this.checkIn});

  @override
  Widget build(BuildContext context) {
    final score = checkIn.feelingScore as int;
    final color = score == 3
        ? AppTheme.teal500
        : score == 2
            ? AppTheme.amber400
            : AppTheme.red400;
    final icon = score == 3
        ? Icons.sentiment_satisfied_alt_rounded
        : score == 2
            ? Icons.sentiment_neutral_rounded
            : Icons.sentiment_dissatisfied_rounded;

    final date = checkIn.date as DateTime;
    final dayLabel = _dayLabel(date);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayLabel,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.neutral900)),
                if ((checkIn.symptoms as List).isNotEmpty)
                  Text((checkIn.symptoms as List<String>).join(', '),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.neutral500)),
                if (checkIn.notes != null)
                  Text(checkIn.notes as String,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.neutral500)),
              ],
            ),
          ),
          Text(checkIn.feelingLabel as String,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }
}

const neutral400 = Color(0xFF888780);
