import 'package:flutter/material.dart';
import 'app_theme.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  List<Map<String, dynamic>> medications = [
    {
      'name': 'Levodopa',
      'dosage': '100mg',
      'times': ['08:00', '14:00', '20:00'],
      'taken': [true, true, false],
      'color': const Color(0xFF42A5F5),
    },
    {
      'name': 'Carbidopa',
      'dosage': '25mg',
      'times': ['08:00', '14:00', '20:00'],
      'taken': [true, false, false],
      'color': const Color(0xFF66BB6A),
    },
    {
      'name': 'Ropinirole',
      'dosage': '2mg',
      'times': ['22:00'],
      'taken': [false],
      'color': const Color(0xFFAB47BC),
    },
  ];

  int get totalScheduled {
    return medications.fold(0, (sum, med) => sum + (med['times'] as List).length);
  }

  int get totalTaken {
    return medications.fold(0, (sum, med) {
      final taken = med['taken'] as List<bool>;
      return sum + taken.where((t) => t).length;
    });
  }

  int get adherencePercentage {
    if (totalScheduled == 0) return 0;
    return ((totalTaken / totalScheduled) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medications',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add medication feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withAlpha(204),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                      const SizedBox(width: AppTheme.spacingS),
                      const Text(
                        'Today\'s Schedule',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Scheduled', '$totalScheduled', Colors.white),
                      ),
                      Expanded(
                        child: _buildStatItem('Taken', '$totalTaken', Colors.white),
                      ),
                      Expanded(
                        child: _buildStatItem('Adherence', '$adherencePercentage%', Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),

            Text(
              'Your Medications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            ...medications.asMap().entries.map((entry) {
              return _buildMedicationCard(entry.key, entry.value);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withAlpha(179),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationCard(int medIndex, Map<String, dynamic> med) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: med['color'],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        med['dosage'],
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  onPressed: () {
                    _showMedicationOptions(medIndex, med);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                for (int i = 0; i < (med['times'] as List).length; i++) ...[
                  if (i > 0) const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleMedication(medIndex, i),
                      child: _buildTimeSlot(
                        med['times'][i],
                        med['taken'][i],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlot(String time, bool taken) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: taken
            ? AppTheme.successColor.withAlpha(26)
            : AppTheme.textLight.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: taken ? AppTheme.successColor : AppTheme.textLight,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            taken ? Icons.check_circle : Icons.circle_outlined,
            color: taken ? AppTheme.successColor : AppTheme.textLight,
            size: 16,
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: taken ? AppTheme.successColor : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMedication(int medIndex, int timeIndex) {
    setState(() {
      medications[medIndex]['taken'][timeIndex] = !medications[medIndex]['taken'][timeIndex];
    });
    
    final taken = medications[medIndex]['taken'][timeIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          taken 
            ? 'Marked ${medications[medIndex]['name']} as taken' 
            : 'Unmarked ${medications[medIndex]['name']}'
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showMedicationOptions(int medIndex, Map<String, dynamic> med) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Medication'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Medication', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  medications.removeAt(medIndex);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${med['name']} deleted')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}