import 'package:flutter/material.dart';
import 'clinician_patient_list.dart';

// ============================================================
// CLINICIAN SHELL
// Entry: patient list → select patient → full dashboard tabs
// ============================================================

class ClinicianShell extends StatelessWidget {
  const ClinicianShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClinicianPatientList();
  }
}
