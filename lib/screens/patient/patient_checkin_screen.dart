import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared/shared_widgets.dart';

class PatientCheckInScreen extends StatefulWidget {
  const PatientCheckInScreen({super.key});

  @override
  State<PatientCheckInScreen> createState() => _PatientCheckInScreenState();
}

class _PatientCheckInScreenState extends State<PatientCheckInScreen> {
  int? _selectedFeeling;
  final Set<String> _selectedSymptoms = {};
  final _notesController = TextEditingController();
  bool _submitted = false;

  static const _symptoms = [
    'Tremor', 'Stiffness', 'Slowness', 'Balance issues',
    'Fatigue', 'Sleep issues', 'Mood changes', 'Pain',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_selectedFeeling == null) return;
    final svc = Provider.of<AppDataService>(context, listen: false);
    svc.logCheckIn(
      patientId: 'p001',
      feelingScore: _selectedFeeling!,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      symptoms: _selectedSymptoms.toList(),
    );
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _SubmittedView(onNewCheckIn: () => setState(() {
        _submitted = false;
        _selectedFeeling = null;
        _selectedSymptoms.clear();
        _notesController.clear();
      }));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE8),
                              appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D24),
        foregroundColor: Colors.white,
        title: const Text('Daily check-in',
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text('How are you feeling today?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('This takes about 30 seconds and helps your care team.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.neutral500)),

          const SizedBox(height: 28),

          // Feeling selector — large touch targets
          Row(
            children: [
              _FeelingTile(
                score: 1,
                icon: Icons.sentiment_dissatisfied_rounded,
                label: 'Not great',
                color: AppTheme.red400,
                bgColor: AppTheme.red50,
                selected: _selectedFeeling == 1,
                onTap: () => setState(() => _selectedFeeling = 1),
              ),
              const SizedBox(width: 8),
              _FeelingTile(
                score: 2,
                icon: Icons.sentiment_neutral_rounded,
                label: 'Okay',
                color: AppTheme.amber400,
                bgColor: AppTheme.amber50,
                selected: _selectedFeeling == 2,
                onTap: () => setState(() => _selectedFeeling = 2),
              ),
              const SizedBox(width: 8),
              _FeelingTile(
                score: 3,
                icon: Icons.sentiment_satisfied_alt_rounded,
                label: 'Good',
                color: AppTheme.teal500,
                bgColor: AppTheme.teal50,
                selected: _selectedFeeling == 3,
                onTap: () => setState(() => _selectedFeeling = 3),
              ),
            ],
          ),

          const SizedBox(height: 28),

          const SectionHeader(title: 'Any symptoms today? (optional)'),
          Text('Select any that apply',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _symptoms
                .map((s) => _SymptomChip(
                      label: s,
                      selected: _selectedSymptoms.contains(s),
                      onTap: () => setState(() {
                        if (_selectedSymptoms.contains(s)) {
                          _selectedSymptoms.remove(s);
                        } else {
                          _selectedSymptoms.add(s);
                        }
                      }),
                    ))
                .toList(),
          ),

          const SizedBox(height: 28),

          const SectionHeader(title: 'Anything else? (optional)'),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. had a bad night, felt stiff after lunch...',
            ),
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _selectedFeeling != null
                ? () => _submit(context)
                : null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AppTheme.neutral100,
              disabledForegroundColor: AppTheme.neutral400,
            ),
            child: const Text('Submit check-in'),
          ),
        ],
      ),
    );
  }
}

class _FeelingTile extends StatelessWidget {
  final int score;
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final bool selected;
  final VoidCallback onTap;

  const _FeelingTile({
    required this.score, required this.icon, required this.label,
    required this.color, required this.bgColor,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha:0.12) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : AppTheme.neutral200,
              width: selected ? 2 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 36,
                  color: selected ? color : AppTheme.neutral300),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected ? color : AppTheme.neutral500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SymptomChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.teal50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.teal400 : AppTheme.neutral200,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? AppTheme.teal700 : AppTheme.neutral700)),
      ),
    );
  }
}

class _SubmittedView extends StatelessWidget {
  final VoidCallback onNewCheckIn;
  const _SubmittedView({required this.onNewCheckIn});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE8),
                        appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D24),
        foregroundColor: Colors.white,
        title: const Text('Daily check-in',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.teal50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppTheme.teal600, size: 40),
              ),
              const SizedBox(height: 24),
              Text('Check-in saved',
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 12),
              Text(
                'Thank you. Your care team can now see how you\'re feeling today alongside your sensor data.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppTheme.neutral500),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: onNewCheckIn,
                child: const Text('Update check-in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const neutral400 = Color(0xFF888780);
