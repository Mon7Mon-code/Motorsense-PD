import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';
import 'patient/patient_shell.dart';
import 'patient/patient_onboarding_screen.dart';
import 'clinician/clinician_shell.dart';

// ============================================================
// LOGIN SCREEN
// Role selection: Patient or Clinician
// In production: replace mock login with real auth
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enter(BuildContext context, bool asClinicianMode) {
    final svc = Provider.of<AppDataService>(context, listen: false);
    svc.login(
      userId: asClinicianMode ? 'c001' : 'p001',
      asClinicianMode: asClinicianMode,
    );
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => asClinicianMode
            ? const ClinicianShell()
            : PatientOnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.teal800,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),

                  // Logomark
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.teal600,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.teal500.withOpacity(0.4), width: 1),
                    ),
                    child: const Icon(Icons.monitor_heart_outlined,
                        color: Colors.white, size: 28),
                  ),

                  const SizedBox(height: 24),

                  Text('ParkinsonsTracker',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Continuous monitoring.\nSimplified.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.65), height: 1.5)),

                  const Spacer(flex: 3),

                  // Role selection
                  Text('I am a...',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: 0.5)),
                  const SizedBox(height: 14),

                  _RoleCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Patient',
                    subtitle: 'View my daily monitoring',
                    onTap: () => _enter(context, false),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    icon: Icons.medical_services_outlined,
                    title: 'Clinician',
                    subtitle: 'View patient dashboards',
                    onTap: () => _enter(context, true),
                  ),

                  const Spacer(flex: 1),

                  Center(
                    child: Text(
                      'Imperial College London · Group 10',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.3),
                          letterSpacing: 0.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: Colors.white.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withOpacity(0.15), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.teal500.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.teal100, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.55))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
