import 'package:flutter/material.dart';
import 'app_theme.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  List<Map<String, dynamic>> recentSymptoms = [
    {
      'type': 'Tremor',
      'severity': 'Moderate',
      'time': '2 hours ago',
      'duration': '15 min',
      'icon': Icons.vibration,
      'color': const Color(0xFFFF9800),
    },
    {
      'type': 'Rigidity',
      'severity': 'Mild',
      'time': '5 hours ago',
      'duration': '30 min',
      'icon': Icons.accessibility_new,
      'color': const Color(0xFF66BB6A),
    },
    {
      'type': 'Bradykinesia',
      'severity': 'Severe',
      'time': '1 day ago',
      'duration': '45 min',
      'icon': Icons.slow_motion_video,
      'color': const Color(0xFFF44336),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Symptoms',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showLogSymptomDialog();
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Log New Symptom',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),

            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: [AppTheme.cardShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSymptomStat(
                          'Episodes',
                          '${recentSymptoms.length}',
                          Icons.warning_amber_rounded,
                          AppTheme.warningColor,
                        ),
                      ),
                      Expanded(
                        child: _buildSymptomStat(
                          'Avg Duration',
                          '22 min',
                          Icons.timer_outlined,
                          AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),

            Text(
              'Recent Logs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            ...recentSymptoms.asMap().entries.map((entry) {
              return _buildSymptomCard(entry.key, entry.value);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomCard(int index, Map<String, dynamic> symptom) {
    return Dismissible(
      key: Key('symptom_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        alignment: Alignment.centerRight,
        child: const Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: Icon(Icons.delete, color: Colors.white),
        ),
      ),
      onDismissed: (direction) {
        setState(() {
          recentSymptoms.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${symptom['type']} deleted')),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: symptom['color'].withAlpha(26),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Icon(
                symptom['icon'],
                color: symptom['color'],
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symptom['type'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${symptom['time']} • ${symptom['duration']}',
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
                color: symptom['color'].withAlpha(26),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                symptom['severity'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: symptom['color'],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogSymptomDialog() {
    String selectedType = 'Tremor';
    String selectedSeverity = 'Mild';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Symptom'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Symptom Type',
                  border: OutlineInputBorder(),
                ),
                items: ['Tremor', 'Rigidity', 'Bradykinesia', 'Dyskinesia']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSeverity,
                decoration: const InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder(),
                ),
                items: ['Mild', 'Moderate', 'Severe']
                    .map((severity) => DropdownMenuItem(
                          value: severity,
                          child: Text(severity),
                        ))
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedSeverity = value!;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                recentSymptoms.insert(0, {
                  'type': selectedType,
                  'severity': selectedSeverity,
                  'time': 'Just now',
                  'duration': '0 min',
                  'icon': Icons.vibration,
                  'color': selectedSeverity == 'Mild' 
                      ? const Color(0xFF66BB6A)
                      : selectedSeverity == 'Moderate'
                      ? const Color(0xFFFF9800)
                      : const Color(0xFFF44336),
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Symptom logged successfully')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}