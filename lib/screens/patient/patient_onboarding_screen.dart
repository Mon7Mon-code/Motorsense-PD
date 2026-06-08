import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ble_service.dart';
import '../../sensor_config.dart';
import '../../services/app_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared/shared_widgets.dart';
import '../patient/patient_shell.dart';

// ============================================================
// PATIENT ONBOARDING FLOW
// 5 steps: Welcome → Profile → Device → Medications → Baseline
// ============================================================

class PatientOnboardingScreen extends StatefulWidget {
  const PatientOnboardingScreen({super.key});

  @override
  State<PatientOnboardingScreen> createState() =>
      _PatientOnboardingScreenState();
}

class _PatientOnboardingScreenState extends State<PatientOnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5;

  // Collected data
  final _nameController = TextEditingController();
  final _diagnosisYearController = TextEditingController();
  String? _selectedSide = 'Left'; // dominant symptom side

  // Medication setup
  final List<Map<String, dynamic>> _medications = [
    {'name': 'Levodopa / Carbidopa', 'dose': '100mg / 25mg',
     'times': ['07:30', '12:30', '17:30'], 'color': '#1D9E75'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _diagnosisYearController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  Future<void> _finish(BuildContext context) async {
    final svc = Provider.of<AppDataService>(context, listen: false);
    final nav = Navigator.of(context);
    await svc.saveOnboardingProfile(
      name:          _nameController.text.trim(),
      diagnosisYear: _diagnosisYearController.text.trim(),
      affectedSide:  _selectedSide ?? 'Left',
    );
    if (!mounted) return;
    nav.pushReplacement(
      MaterialPageRoute(builder: (_) => const PatientShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            _ProgressBar(current: _currentPage, total: _totalPages),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(onNext: _nextPage),
                  _ProfilePage(
                    nameController: _nameController,
                    diagnosisYearController: _diagnosisYearController,
                    selectedSide: _selectedSide,
                    onSideChanged: (s) => setState(() => _selectedSide = s),
                    onNext: _nextPage,
                    onBack: _prevPage,
                  ),
                  _DevicePage(onNext: _nextPage, onBack: _prevPage),
                  _MedicationsPage(
                    medications: _medications,
                    onNext: _nextPage,
                    onBack: _prevPage,
                  ),
                  _BaselinePage(
                    onFinish: () => _finish(context),
                    onBack: _prevPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Progress bar -------------------------------------------
class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 3,
              decoration: BoxDecoration(
                color: i <= current ? AppTheme.teal500 : AppTheme.neutral200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// --- Page shell ---------------------------------------------
class _OnboardingPage extends StatelessWidget {
  final Widget child;
  final String? buttonLabel;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  const _OnboardingPage({
    required this.child,
    this.buttonLabel,
    this.onNext,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: child,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              if (buttonLabel != null)
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: AppTheme.neutral100,
                    disabledForegroundColor: AppTheme.neutral400,
                  ),
                  child: Text(buttonLabel!),
                ),
              if (onBack != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onBack,
                  child: const Text('Back',
                      style: TextStyle(color: AppTheme.neutral500)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PAGE 1: WELCOME
// ============================================================
class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      buttonLabel: 'Get started',
      onNext: onNext,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.monitor_heart_outlined,
                color: AppTheme.teal600, size: 32),
          ),
          const SizedBox(height: 28),
          Text('Welcome to\nParkinsonsTracker',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 16),
          Text(
            'This app works with your wrist device to monitor your symptoms '
            'throughout the day — automatically, in the background.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          _BulletPoint(
            icon: Icons.watch_outlined,
            title: 'Passive monitoring',
            subtitle: 'Your wristband collects data — no effort needed.',
          ),
          const SizedBox(height: 16),
          _BulletPoint(
            icon: Icons.bar_chart_outlined,
            title: 'Daily insights',
            subtitle: 'See how you\'re moving in plain, simple language.',
          ),
          const SizedBox(height: 16),
          _BulletPoint(
            icon: Icons.people_outline_rounded,
            title: 'Shared with your care team',
            subtitle: 'Your clinician sees your trends before each appointment.',
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Setup takes about 3 minutes.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.neutral600,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _BulletPoint(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.teal50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.teal600, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.neutral500, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PAGE 2: PROFILE
// ============================================================
class _ProfilePage extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController diagnosisYearController;
  final String? selectedSide;
  final ValueChanged<String?> onSideChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _ProfilePage({
    required this.nameController,
    required this.diagnosisYearController,
    required this.selectedSide,
    required this.onSideChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      buttonLabel: 'Continue',
      onNext: onNext,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About you',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text('This helps personalise your experience.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 32),

          const Text('Your first name',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.neutral700)),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Margaret'),
          ),

          const SizedBox(height: 20),

          const Text('Year of diagnosis',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.neutral700)),
          const SizedBox(height: 8),
          TextField(
            controller: diagnosisYearController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 2019'),
          ),

          const SizedBox(height: 20),

          const Text('Which side is more affected?',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.neutral700)),
          const SizedBox(height: 8),
          Row(
            children: ['Left', 'Right', 'Both'].map((side) {
              final selected = selectedSide == side;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onSideChanged(side),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.teal50 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppTheme.teal500
                              : AppTheme.neutral200,
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(side,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? AppTheme.teal700
                                  : AppTheme.neutral500)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.neutral100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Your data stays on your device and is only shared with your assigned clinician.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutral500,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE 3: DEVICE CONNECTION
// ============================================================
class _DevicePage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const _DevicePage({required this.onNext, required this.onBack});

  @override
  State<_DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<_DevicePage> {
  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BleService>(context);
    final isConnected = ble.isActive;

    return _OnboardingPage(
      buttonLabel: isConnected ? 'Continue' : 'Skip for now',
      onNext: widget.onNext,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect your device',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text('Put on your wristband and make sure it\'s charged.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppTheme.neutral500)),
          const SizedBox(height: 32),

          // Connection status card
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isConnected ? AppTheme.teal50 : AppTheme.neutral100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isConnected ? AppTheme.teal200 : AppTheme.neutral200,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isConnected ? AppTheme.teal100 : AppTheme.neutral200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.watch_rounded
                        : Icons.watch_off_outlined,
                    color: isConnected
                        ? AppTheme.teal700
                        : AppTheme.neutral400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected
                            ? 'Device connected!'
                            : 'Searching for ${SensorConfig.bleDeviceName}…',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isConnected
                                ? AppTheme.teal700
                                : AppTheme.neutral600),
                      ),
                      Text(
                        isConnected
                            ? '${SensorConfig.bleDeviceDisplayName} is ready'
                            : 'Looking for ${SensorConfig.bleDeviceName}…',
                        style: TextStyle(
                            fontSize: 13,
                            color: isConnected
                                ? AppTheme.teal600
                                : AppTheme.neutral400),
                      ),
                    ],
                  ),
                ),
                if (!isConnected)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.neutral400,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const SectionHeader(title: 'How to wear it'),
          AppCard(
            child: Column(
              children: [
                _GuideRow(step: 1,
                    text: 'Wear it on your non-dominant wrist, like a watch.'),
                _GuideRow(step: 2,
                    text: 'It should be snug but comfortable — not sliding.'),
                _GuideRow(step: 3,
                    text: 'Keep it within 1 metre of your phone.',
                    isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  final int step;
  final String text;
  final bool isLast;
  const _GuideRow(
      {required this.step, required this.text, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$step',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.teal700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.neutral700,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE 4: MEDICATIONS
// ============================================================
class _MedicationsPage extends StatefulWidget {
  final List<Map<String, dynamic>> medications;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _MedicationsPage({
    required this.medications,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_MedicationsPage> createState() => _MedicationsPageState();
}

class _MedicationsPageState extends State<_MedicationsPage> {
  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      buttonLabel: 'Continue',
      onNext: widget.onNext,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your medications',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            'We\'ve added common Parkinson\'s medications. '
            'Edit or add your own.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.neutral500),
          ),
          const SizedBox(height: 24),

          ...widget.medications.asMap().entries.map((entry) {
            final med = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(int.parse(
                            'FF${(med['color'] as String).replaceAll('#', '')}',
                            radix: 16)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(med['name'] as String,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(med['dose'] as String,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.neutral500)),
                          const SizedBox(height: 4),
                          Text(
                            (med['times'] as List).cast<String>().join(' · '),
                            style: AppTheme.mono.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppTheme.neutral300),
                      onPressed: () =>
                          setState(() => widget.medications.remove(med)),
                    ),
                  ],
                ),
              ),
            );
          }),

          TextButton.icon(
            onPressed: () => _showAddMedicationSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add medication'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.teal600),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.amber50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Timing matters — your wristband tracks how symptoms change after each dose. '
              'Set your actual schedule for the best insights.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.amber700,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMedicationSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add medication',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Medication name',
                  hintText: 'e.g. Levodopa'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: doseCtrl,
              decoration: const InputDecoration(
                  labelText: 'Dose',
                  hintText: 'e.g. 100mg'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    widget.medications.add({
                      'name': nameCtrl.text,
                      'dose': doseCtrl.text,
                      'times': ['08:00'],
                      'color': '#1D9E75',
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PAGE 5: BASELINE
// ============================================================
class _BaselinePage extends StatefulWidget {
  final VoidCallback onFinish;
  final VoidCallback onBack;
  const _BaselinePage({required this.onFinish, required this.onBack});

  @override
  State<_BaselinePage> createState() => _BaselinePageState();
}

class _BaselinePageState extends State<_BaselinePage> {
  late final DateTime _pageEnteredAt;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  static const _baselineDuration = Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _pageEnteredAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_pageEnteredAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double get _progress =>
      (_elapsed.inSeconds / _baselineDuration.inSeconds).clamp(0.0, 1.0);

  String get _remainingText {
    final remaining = _baselineDuration - _elapsed;
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    if (h > 0) return '~${h}h ${m}m remaining';
    return '~${m}m remaining';
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      buttonLabel: 'Start using the app',
      onNext: widget.onFinish,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Almost done!',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Your device will now establish a baseline — '
            'a snapshot of your normal movement to compare future readings against.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppTheme.neutral500),
          ),
          const SizedBox(height: 32),

          // Baseline progress card
          Container(
            padding: const EdgeInsets.all(20),
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
                        color: AppTheme.teal600, size: 22),
                    const SizedBox(width: 10),
                    const Text('Baseline collection',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.teal700)),
                    const Spacer(),
                    Text(
                      '${(_progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.teal600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: AppTheme.teal100,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.teal500),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _remainingText,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.teal600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Wear your device and go about your normal day. '
                  'No action is needed from you.',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.teal600,
                      height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: 'What happens next'),
          AppCard(
            child: Column(
              children: [
                _NextStepRow(
                  icon: Icons.watch_rounded,
                  text: 'Wear the device throughout the day.',
                ),
                const Divider(height: 20),
                _NextStepRow(
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  text: 'Do your daily check-in each morning.',
                ),
                const Divider(height: 20),
                _NextStepRow(
                  icon: Icons.medication_outlined,
                  text: 'Log your medication doses when you take them.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NextStepRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.teal500),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.neutral700, height: 1.4)),
        ),
      ],
    );
  }
}

const neutral400 = Color(0xFF888780);
const neutral600 = Color(0xFF5F5E5A);
const teal800    = Color(0xFF085041);
const amber700   = Color(0xFF854F0B);