import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'app_theme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final Random _random = Random();

  // Generate medication times (8am, 2pm, 8pm)
  List<double> medicationTimes = [8.0, 14.0, 20.0];

  // Generate symptom severity data showing response to medication
  List<FlSpot> _generateSymptomData() {
    List<FlSpot> data = [];
    for (double hour = 0; hour <= 24; hour += 0.5) {
      double severity;
      
      // Find nearest medication time
      double timeSinceLastDose = double.infinity;
      for (var medTime in medicationTimes) {
        double diff = hour - medTime;
        if (diff >= 0 && diff < timeSinceLastDose) {
          timeSinceLastDose = diff;
        }
      }
      
      // Simulate wearing-off effect
      if (timeSinceLastDose < 4) {
        // Within 4 hours of dose - good control
        severity = 20 + timeSinceLastDose * 5 + _random.nextDouble() * 5;
      } else {
        // Wearing off - symptoms worsen
        severity = 40 + timeSinceLastDose * 3 + _random.nextDouble() * 10;
      }
      
      data.add(FlSpot(hour, severity.clamp(15, 75)));
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Clinical Insights',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Insight Card
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5E35B1),
                    const Color(0xFF5E35B1).withAlpha(204),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💡 AI Insight',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tremor severity increases 3-4 hours after medication, suggesting wearing-off effect. Consider dose timing adjustment.',
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),

            // Medication-Symptom Correlation Chart
            Text(
              'Medication Response',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Symptom severity vs medication timing (Today)',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            Container(
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [AppTheme.cardShadow],
              ),
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.white,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          return LineTooltipItem(
                            '${barSpot.y.toStringAsFixed(0)}%',
                            const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 4,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${value.toInt()}:00',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 24,
                  minY: 0,
                  maxY: 80,
                  lineBarsData: [
                    // Symptom severity line
                    LineChartBarData(
                      spots: _generateSymptomData(),
                      isCurved: true,
                      color: AppTheme.dangerColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.dangerColor.withAlpha(26),
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    verticalLines: medicationTimes.map((time) {
                      return VerticalLine(
                        x: time,
                        color: AppTheme.successColor,
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: VerticalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => '💊',
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Symptom Severity', AppTheme.dangerColor),
                const SizedBox(width: AppTheme.spacingL),
                _buildLegendItem('Medication Dose', AppTheme.successColor),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXL),

            // Time-of-Day Breakdown
            Text(
              'Symptom Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Average severity by time of day',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [AppTheme.cardShadow],
              ),
              child: Column(
                children: [
                  _buildTimeOfDayBar('Morning (6-12)', 0.45, const Color(0xFFFFA726)),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildTimeOfDayBar('Afternoon (12-18)', 0.60, const Color(0xFFEF5350)),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildTimeOfDayBar('Evening (18-24)', 0.38, const Color(0xFF66BB6A)),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),

            // Weekly Comparison
            Text(
              'Weekly Comparison',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Change from baseline',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [AppTheme.cardShadow],
              ),
              child: Column(
                children: [
                  _buildComparisonRow('Tremor Severity', 34.2, 8.0, true),
                  const Divider(height: AppTheme.spacingL),
                  _buildComparisonRow('Walking Speed', 1.2, -0.3, false),
                  const Divider(height: AppTheme.spacingL),
                  _buildComparisonRow('Step Cadence', 112, 5.0, false),
                  const Divider(height: AppTheme.spacingL),
                  _buildComparisonRow('Medication Adherence', 71, -12.0, true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeOfDayBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(String label, double current, double delta, bool isPercentage) {
    bool isWorse = delta > 0;
    Color deltaColor = isWorse ? AppTheme.dangerColor : AppTheme.successColor;
    IconData icon = isWorse ? Icons.arrow_upward : Icons.arrow_downward;
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Current: ${current.toStringAsFixed(1)}${isPercentage ? '%' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: deltaColor.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, color: deltaColor, size: 14),
              const SizedBox(width: 4),
              Text(
                '${delta.abs().toStringAsFixed(1)}${isPercentage ? '%' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: deltaColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}