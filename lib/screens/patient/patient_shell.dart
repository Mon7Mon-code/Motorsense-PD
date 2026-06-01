import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'patient_home_screen.dart';
import 'patient_medications_screen.dart';
import 'patient_checkin_screen.dart';
import 'patient_my_week_screen.dart';
import 'patient_appointments_screen.dart';
import 'patient_device_screen.dart';

// ============================================================
// PATIENT SHELL — bottom navigation container
// ============================================================

class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _currentIndex = 0;

  final _screens = const [
    PatientHomeScreen(),
    PatientMedicationsScreen(),
    PatientCheckInScreen(),
    PatientMyWeekScreen(),
    PatientAppointmentsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.neutral100, width: 0.5)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded,
                    label: 'Home', index: 0, current: _currentIndex,
                    onTap: () => setState(() => _currentIndex = 0)),
                _NavItem(icon: Icons.medication_outlined, activeIcon: Icons.medication_rounded,
                    label: 'Meds', index: 1, current: _currentIndex,
                    onTap: () => setState(() => _currentIndex = 1)),
                _CheckInNavItem(current: _currentIndex,
                    onTap: () => setState(() => _currentIndex = 2)),
                _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded,
                    label: 'My week', index: 3, current: _currentIndex,
                    onTap: () => setState(() => _currentIndex = 3)),
                _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month_rounded,
                    label: 'Appts', index: 4, current: _currentIndex,
                    onTap: () => setState(() => _currentIndex = 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon, required this.activeIcon, required this.label,
    required this.index, required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon,
                size: 24,
                color: isActive ? AppTheme.teal600 : AppTheme.neutral300),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? AppTheme.teal600 : AppTheme.neutral400)),
          ],
        ),
      ),
    );
  }
}

// The central check-in button — prominent, different style
class _CheckInNavItem extends StatelessWidget {
  final int current;
  final VoidCallback onTap;

  const _CheckInNavItem({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = current == 2;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.teal600 : AppTheme.teal50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: isActive ? Colors.white : AppTheme.teal600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keep this for the device screen accessible from home
const neutral400 = Color(0xFF888780);
