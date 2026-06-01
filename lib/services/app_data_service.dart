// ============================================================
// DATA SERVICE — Mock implementation
//
// HOW TO INTEGRATE WITH PROCESSING TEAM:
// 1. Keep this file's public interface (method signatures) identical
// 2. Replace the body of each method with real BLE / backend calls
// 3. The UI will work without any changes
//
// SEARCH FOR: "// REPLACE WITH PROCESSING TEAM OUTPUT"
// to find every point of integration.
// ============================================================

import 'package:flutter/foundation.dart';
import '../models/patient_data.dart';

class AppDataService extends ChangeNotifier {
  // ----------------------------------------------------------
  // Auth state
  // ----------------------------------------------------------
  String? _currentUserId;
  bool _isClinicianMode = false;

  bool get isClinicianMode => _isClinicianMode;
  String? get currentUserId => _currentUserId;

  void login({required String userId, required bool asClinicianMode}) {
    _currentUserId = userId;
    _isClinicianMode = asClinicianMode;
    notifyListeners();
  }

  void logout() {
    _currentUserId = null;
    notifyListeners();
  }

  // ----------------------------------------------------------
  // Live device status
  // REPLACE WITH PROCESSING TEAM OUTPUT: BLE stream
  // ----------------------------------------------------------
  DeviceStatus getDeviceStatus(String patientId) {
    return const DeviceStatus(
      isConnected: true,
      batteryPercent: 72,
      lastSyncTime: null, // will be DateTime.now() in live version
      isWorn: true,
    );
  }

  // ----------------------------------------------------------
  // Latest symptom snapshot
  // REPLACE WITH PROCESSING TEAM OUTPUT: real-time classifier output
  // Expected output format: SymptomSnapshot with MDS-UPDRS scores 0.0–4.0
  // ----------------------------------------------------------
  SymptomSnapshot? getLatestSnapshot(String patientId) {
    return SymptomSnapshot(
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      tremorScore: _mockTremor[patientId] ?? 1.2,
      bradykinesiaScore: _mockBradykinesia[patientId] ?? 0.8,
      dyskinesiaScore: _mockDyskinesia[patientId] ?? 0.3,
      rigidityScore: 0.6,
    );
  }

  // ----------------------------------------------------------
  // 7-day symptom history
  // REPLACE WITH PROCESSING TEAM OUTPUT: historical classifier results
  // ----------------------------------------------------------
  List<SymptomSnapshot> getWeeklySnapshots(String patientId) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final base = _mockTremor[patientId] ?? 1.2;
      return SymptomSnapshot(
        timestamp: now.subtract(Duration(days: 6 - i)),
        tremorScore: (base + _variation[i % _variation.length]).clamp(0, 4),
        bradykinesiaScore: (0.8 + _variation2[i % _variation2.length]).clamp(0, 4),
        dyskinesiaScore: (0.3 + _variation3[i % _variation3.length]).clamp(0, 4),
        rigidityScore: 0.6,
      );
    });
  }

  // ----------------------------------------------------------
  // Gait metrics
  // REPLACE WITH PROCESSING TEAM OUTPUT: gait analysis pipeline
  // ----------------------------------------------------------
  GaitMetrics? getLatestGait(String patientId) {
    return GaitMetrics(
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      strideLength: 0.58,
      stepFrequency: 98,
      armSwingScore: 1.4,
      gaitSymmetry: 0.81,
      walkingSpeed: 0.94,
      stepCount: 4820,
    );
  }

  List<GaitMetrics> getWeeklyGait(String patientId) {
    final now = DateTime.now();
    return List.generate(7, (i) => GaitMetrics(
      timestamp: now.subtract(Duration(days: 6 - i)),
      strideLength: 0.55 + (i * 0.005),
      stepFrequency: 96 + (i % 3) * 2.0,
      armSwingScore: 1.4 + (i % 2) * 0.2,
      gaitSymmetry: 0.79 + (i * 0.004),
      walkingSpeed: 0.90 + (i * 0.01),
      stepCount: 4200 + (i * 150),
    ));
  }

  // ----------------------------------------------------------
  // Medication response correlation
  // REPLACE WITH PROCESSING TEAM OUTPUT: dose-symptom correlation analysis
  // This is the key clinical insight — symptom scores binned by
  // minutes since last levodopa dose
  // ----------------------------------------------------------
  List<MedicationResponsePoint> getMedicationResponse(String patientId) {
    // Simulates typical levodopa on/off cycle: good response 30–180 min post-dose
    final now = DateTime.now();
    final points = <MedicationResponsePoint>[];
    for (int min = 0; min <= 360; min += 15) {
      double tremor;
      double brady;
      if (min < 30) {
        tremor = 2.2 - (min / 30) * 0.8;
        brady = 2.0 - (min / 30) * 0.7;
      } else if (min <= 180) {
        tremor = 1.0 + ((min - 30) / 150) * 0.3;
        brady = 0.9 + ((min - 30) / 150) * 0.4;
      } else {
        tremor = 1.3 + ((min - 180) / 180) * 1.2;
        brady = 1.3 + ((min - 180) / 180) * 1.0;
      }
      points.add(MedicationResponsePoint(
        timestamp: now.subtract(Duration(minutes: 360 - min)),
        minutesSinceDose: min.toDouble(),
        tremorScore: tremor.clamp(0, 4),
        bradykinesiaScore: brady.clamp(0, 4),
        dyskinesiaScore: (0.2 + (min / 360) * 0.4).clamp(0, 4),
        medicationName: 'Levodopa',
      ));
    }
    return points;
  }

  // ----------------------------------------------------------
  // Patient list (for clinician)
  // REPLACE WITH PROCESSING TEAM OUTPUT: patient database / backend
  // ----------------------------------------------------------
  List<Patient> getPatients(String clinicianId) {
    return _mockPatients;
  }

  Patient? getPatient(String patientId) {
    try {
      return _mockPatients.firstWhere((p) => p.id == patientId);
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------------
  // Wellbeing check-ins (patient self-report — stored locally)
  // ----------------------------------------------------------
  final List<WellbeingCheckIn> _checkIns = [];

  List<WellbeingCheckIn> getCheckIns(String patientId) {
    return _mockCheckIns;
  }

  void logCheckIn({
    required String patientId,
    required int feelingScore,
    String? notes,
    List<String> symptoms = const [],
  }) {
    _checkIns.add(WellbeingCheckIn(
      date: DateTime.now(),
      feelingScore: feelingScore,
      notes: notes,
      symptoms: symptoms,
    ));
    notifyListeners();
  }

  // ----------------------------------------------------------
  // Medications
  // ----------------------------------------------------------
  List<MedicationEntry> getMedications(String patientId) {
    return _mockMedications;
  }

  void logMedicationTaken(String patientId, String medicationId) {
    // REPLACE WITH PROCESSING TEAM OUTPUT: log to backend / trigger dose tracking
    notifyListeners();
  }

  // ----------------------------------------------------------
  // Appointments
  // ----------------------------------------------------------
  List<Appointment> getAppointments(String patientId) {
    return _mockAppointments;
  }

  // ----------------------------------------------------------
  // Baseline snapshot
  // REPLACE WITH PROCESSING TEAM OUTPUT: baseline established at onboarding
  // ----------------------------------------------------------
  SymptomSnapshot? getBaseline(String patientId) {
    return SymptomSnapshot(
      timestamp: DateTime(2025, 10, 15),
      tremorScore: 0.8,
      bradykinesiaScore: 0.6,
      dyskinesiaScore: 0.1,
      rigidityScore: 0.5,
    );
  }

  // ----------------------------------------------------------
  // Mock data — all values below will be replaced
  // ----------------------------------------------------------
  static const _mockTremor = {
    'p001': 1.2, 'p002': 2.4, 'p003': 0.6, 'p004': 1.8,
  };
  static const _mockBradykinesia = {
    'p001': 0.8, 'p002': 2.1, 'p003': 0.4, 'p004': 1.5,
  };
  static const _mockDyskinesia = {
    'p001': 0.3, 'p002': 1.2, 'p003': 0.1, 'p004': 0.8,
  };

  static const _variation = [0.0, 0.3, -0.1, 0.5, 0.2, -0.2, 0.4];
  static const _variation2 = [0.0, -0.2, 0.3, 0.1, -0.3, 0.4, 0.0];
  static const _variation3 = [0.0, 0.1, 0.0, 0.2, -0.1, 0.1, 0.0];

  static final _mockPatients = [
    Patient(
      id: 'p001',
      name: 'Margaret Ellis',
      age: 68,
      diagnosisYear: '2019',
      assignedClinicianId: 'c001',
      deviceStatus: const DeviceStatus(
        isConnected: true, batteryPercent: 72, isWorn: true),
      medications: _mockMedications,
      weeklySnapshots: [],
      weeklyGait: [],
      medicationResponse: [],
      checkIns: _mockCheckIns,
      appointments: _mockAppointments,
      latestSnapshot: SymptomSnapshot(
        timestamp: DateTime(2026, 6, 1),
        tremorScore: 1.2, bradykinesiaScore: 0.8,
        dyskinesiaScore: 0.3, rigidityScore: 0.6),
      baselineSnapshot: SymptomSnapshot(
        timestamp: DateTime(2025, 10, 15),
        tremorScore: 0.8, bradykinesiaScore: 0.6,
        dyskinesiaScore: 0.1, rigidityScore: 0.5),
    ),
    Patient(
      id: 'p002',
      name: 'Robert Chen',
      age: 74,
      diagnosisYear: '2016',
      assignedClinicianId: 'c001',
      deviceStatus: const DeviceStatus(
        isConnected: true, batteryPercent: 31, isWorn: true),
      medications: _mockMedications,
      weeklySnapshots: [],
      weeklyGait: [],
      medicationResponse: [],
      checkIns: [],
      appointments: _mockAppointments,
      latestSnapshot: SymptomSnapshot(
        timestamp: DateTime(2026, 6, 1),
        tremorScore: 2.4, bradykinesiaScore: 2.1,
        dyskinesiaScore: 1.2, rigidityScore: 1.8),
      baselineSnapshot: SymptomSnapshot(
        timestamp: DateTime(2025, 9, 10),
        tremorScore: 1.8, bradykinesiaScore: 1.6,
        dyskinesiaScore: 0.6, rigidityScore: 1.2),
    ),
    Patient(
      id: 'p003',
      name: 'Patricia Okafor',
      age: 61,
      diagnosisYear: '2022',
      assignedClinicianId: 'c001',
      deviceStatus: const DeviceStatus(
        isConnected: false, batteryPercent: 0, isWorn: false),
      medications: _mockMedications,
      weeklySnapshots: [],
      weeklyGait: [],
      medicationResponse: [],
      checkIns: [],
      appointments: _mockAppointments,
      latestSnapshot: SymptomSnapshot(
        timestamp: DateTime(2026, 5, 29),
        tremorScore: 0.6, bradykinesiaScore: 0.4,
        dyskinesiaScore: 0.1, rigidityScore: 0.3),
      baselineSnapshot: SymptomSnapshot(
        timestamp: DateTime(2025, 11, 20),
        tremorScore: 0.5, bradykinesiaScore: 0.3,
        dyskinesiaScore: 0.0, rigidityScore: 0.2),
    ),
    Patient(
      id: 'p004',
      name: 'David Whitmore',
      age: 71,
      diagnosisYear: '2018',
      assignedClinicianId: 'c001',
      deviceStatus: const DeviceStatus(
        isConnected: true, batteryPercent: 88, isWorn: false),
      medications: _mockMedications,
      weeklySnapshots: [],
      weeklyGait: [],
      medicationResponse: [],
      checkIns: [],
      appointments: _mockAppointments,
      latestSnapshot: SymptomSnapshot(
        timestamp: DateTime(2026, 6, 1),
        tremorScore: 1.8, bradykinesiaScore: 1.5,
        dyskinesiaScore: 0.8, rigidityScore: 1.1),
      baselineSnapshot: SymptomSnapshot(
        timestamp: DateTime(2025, 10, 5),
        tremorScore: 1.4, bradykinesiaScore: 1.2,
        dyskinesiaScore: 0.4, rigidityScore: 0.9),
    ),
  ];

  static final _mockMedications = [
    MedicationEntry(
      id: 'm001',
      name: 'Levodopa / Carbidopa',
      dose: '100mg / 25mg',
      scheduledTimes: ['07:30', '12:30', '17:30'],
      takenAt: [],
      color: '#1D9E75',
    ),
    MedicationEntry(
      id: 'm002',
      name: 'Pramipexole',
      dose: '0.5mg',
      scheduledTimes: ['08:00', '20:00'],
      takenAt: [],
      color: '#185FA5',
    ),
  ];

  static final _mockAppointments = [
    Appointment(
      id: 'a001',
      dateTime: DateTime(2026, 6, 18, 10, 30),
      clinicianName: 'Dr. Sarah Okonkwo',
      location: 'Movement Disorders Clinic, Floor 3',
      type: 'routine',
      discussionPoints: [
        'Tremor slightly increased since last visit',
        'Review Levodopa timing based on wrist data',
        'Discuss recent sleep quality from check-ins',
      ],
    ),
    Appointment(
      id: 'a002',
      dateTime: DateTime(2026, 8, 5, 14, 0),
      clinicianName: 'Dr. Sarah Okonkwo',
      location: 'Phone consultation',
      type: 'phone',
      discussionPoints: [
        '3-month progress review',
        'Medication adjustment follow-up',
      ],
    ),
  ];

  static final _mockCheckIns = [
    WellbeingCheckIn(
      date: DateTime.now().subtract(const Duration(days: 0)),
      feelingScore: 2,
      symptoms: ['fatigue'],
      notes: 'A bit stiff this morning',
    ),
    WellbeingCheckIn(
      date: DateTime.now().subtract(const Duration(days: 1)),
      feelingScore: 3,
      symptoms: [],
    ),
    WellbeingCheckIn(
      date: DateTime.now().subtract(const Duration(days: 2)),
      feelingScore: 2,
      symptoms: ['tremor', 'stiffness'],
    ),
    WellbeingCheckIn(
      date: DateTime.now().subtract(const Duration(days: 3)),
      feelingScore: 3,
      symptoms: [],
    ),
    WellbeingCheckIn(
      date: DateTime.now().subtract(const Duration(days: 4)),
      feelingScore: 1,
      symptoms: ['fatigue', 'tremor'],
      notes: 'Had a bad night',
    ),
    WellbeingCheckIn(
      date: DateTime.now().subtract(const Duration(days: 5)),
      feelingScore: 2,
      symptoms: ['stiffness'],
    ),
    WellbeingCheckIn(
      date: DateTime.now().subtract(const Duration(days: 6)),
      feelingScore: 3,
      symptoms: [],
    ),
  ];
}
