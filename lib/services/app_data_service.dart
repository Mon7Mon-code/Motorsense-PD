import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/patient_data.dart';
import '../tremor_pipeline.dart';
import '../gait_pipeline.dart';
import '../ble_service.dart';

class AppDataService extends ChangeNotifier {
  final TremorPipeline tremorPipeline;
  final GaitPipeline   gaitPipeline;
  final BleService     bleService;

  AppDataService({
    required this.tremorPipeline,
    required this.gaitPipeline,
    required this.bleService,
  }) {
    _subscribeToUpdates();
  }

  // --- Auth ---------------------------------------------------
  String? _currentUserId;
  bool    _isClinicianMode = false;
  bool    get isClinicianMode => _isClinicianMode;
  String? get currentUserId   => _currentUserId;

  void login({required String userId, required bool asClinicianMode}) {
    _currentUserId   = userId;
    _isClinicianMode = asClinicianMode;
    notifyListeners();
  }

  void logout() {
    _currentUserId = null;
    notifyListeners();
  }

  // --- Patient name -------------------------------------------
  String _patientName = 'Patient';
  String _patientDiagnosisYear = '';
  String get patientName => _patientName;

  void updatePatientName({required String name, required String diagnosisYear}) {
    _patientName = name;
    _patientDiagnosisYear = diagnosisYear;
    notifyListeners();
  }

  // --- Pipeline subscriptions ---------------------------------
  TremorResult?       _latestTremor;
  GaitAnalysisResult? _latestGait;
  final List<TremorResult>       _tremorHistory = [];
  final List<GaitAnalysisResult> _gaitHistory   = [];
  StreamSubscription? _tremorSub;
  StreamSubscription? _gaitSub;

  void _subscribeToUpdates() {
    _tremorSub = tremorPipeline.resultStream.listen((result) {
      _latestTremor = result;
      _tremorHistory.add(result);
      if (_tremorHistory.length > 500) _tremorHistory.removeAt(0);
      notifyListeners();
    });
    _gaitSub = gaitPipeline.resultStream.listen((result) {
      _latestGait = result;
      _gaitHistory.add(result);
      if (_gaitHistory.length > 500) _gaitHistory.removeAt(0);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _tremorSub?.cancel();
    _gaitSub?.cancel();
    super.dispose();
  }

  // --- Device status ------------------------------------------
  DeviceStatus getDeviceStatus(String patientId) {
    return DeviceStatus(
      isConnected:    bleService.isActive,
      batteryPercent: 0,
      lastSyncTime:   _latestTremor?.timestamp ?? _latestGait?.timestamp,
      isWorn:         bleService.isActive,
    );
  }

  // --- Symptom snapshots (mock for now) -----------------------
  SymptomSnapshot? getLatestSnapshot(String patientId) {
    return _mockSnapshot();
  }

  List<SymptomSnapshot> getWeeklySnapshots(String patientId) {
    return _mockWeeklySnapshots();
  }

  // --- Gait ---------------------------------------------------
  GaitMetrics? getLatestGait(String patientId) {
    final r = _latestGait ?? gaitPipeline.latestResult;
    if (r == null) return _mockWeeklyGait().last;
    final cad   = r.cadenceStepsPerMin ?? 0.0;
    final speed = r.walkingSpeedMs     ?? 0.0;
    return GaitMetrics(
      timestamp:     r.timestamp,
      strideLength:  cad > 0 ? speed * 60.0 / cad : 0.58,
      stepFrequency: cad > 0 ? cad : 98,
      armSwingScore: r.bradykinesiaSeverity.toDouble(),
      gaitSymmetry:  (r.features['SYM_U'] ?? 0.80).clamp(0.0, 1.0),
      walkingSpeed:  speed > 0 ? speed : 0.90,
      stepCount:     r.validation.stepCount,
    );
  }

  List<GaitMetrics> getWeeklyGait(String patientId) {
    return _mockWeeklyGait();
  }

  // --- Medication response ------------------------------------
  List<MedicationResponsePoint> getMedicationResponse(String patientId) {
    return _mockMedicationResponse();
  }

  // --- Patients -----------------------------------------------
  List<Patient> getPatients(String clinicianId) => _buildPatients();

  Patient? getPatient(String patientId) =>
      _buildPatients().firstWhere((p) => p.id == patientId,
          orElse: () => _buildPatients().first);

  List<Patient> _buildPatients() => [
    Patient(
      id:                  'p001',
      name:                _patientName,
      age:                 68,
      diagnosisYear:       _patientDiagnosisYear.isNotEmpty
                               ? _patientDiagnosisYear : '2019',
      assignedClinicianId: 'c001',
      deviceStatus:        getDeviceStatus('p001'),
      medications:         _staticMedications,
      weeklySnapshots:     getWeeklySnapshots('p001'),
      weeklyGait:          getWeeklyGait('p001'),
      medicationResponse:  getMedicationResponse('p001'),
      checkIns:            getCheckIns('p001'),
      appointments:        _staticAppointments,
      latestSnapshot:      getLatestSnapshot('p001'),
      baselineSnapshot:    getBaseline('p001'),
    ),
  ];

  // --- Baseline -----------------------------------------------
  SymptomSnapshot? getBaseline(String patientId) => SymptomSnapshot(
    timestamp:         DateTime(2025, 10, 15),
    tremorScore:       0.8,
    bradykinesiaScore: 0.6,
    dyskinesiaScore:   0.1,
    rigidityScore:     0.5,
  );

  // --- Check-ins ----------------------------------------------
  final List<WellbeingCheckIn> _checkIns = [
    WellbeingCheckIn(date: DateTime.now(),
        feelingScore: 2, symptoms: ['fatigue'],
        notes: 'A bit stiff this morning'),
    WellbeingCheckIn(date: DateTime.now().subtract(const Duration(days: 1)),
        feelingScore: 3, symptoms: []),
    WellbeingCheckIn(date: DateTime.now().subtract(const Duration(days: 2)),
        feelingScore: 2, symptoms: ['tremor']),
    WellbeingCheckIn(date: DateTime.now().subtract(const Duration(days: 3)),
        feelingScore: 3, symptoms: []),
    WellbeingCheckIn(date: DateTime.now().subtract(const Duration(days: 4)),
        feelingScore: 1, symptoms: ['fatigue', 'tremor'],
        notes: 'Bad night'),
    WellbeingCheckIn(date: DateTime.now().subtract(const Duration(days: 5)),
        feelingScore: 2, symptoms: ['stiffness']),
    WellbeingCheckIn(date: DateTime.now().subtract(const Duration(days: 6)),
        feelingScore: 3, symptoms: []),
  ];

  List<WellbeingCheckIn> getCheckIns(String patientId) => _checkIns;

  void logCheckIn({
    required String patientId,
    required int feelingScore,
    String? notes,
    List<String> symptoms = const [],
  }) {
    _checkIns.insert(0, WellbeingCheckIn(
      date:         DateTime.now(),
      feelingScore: feelingScore,
      notes:        notes,
      symptoms:     symptoms,
    ));
    notifyListeners();
  }

  // --- Medications & appointments -----------------------------
  List<MedicationEntry> getMedications(String patientId) => _staticMedications;
  void logMedicationTaken(String patientId, String medicationId) =>
      notifyListeners();
  List<Appointment> getAppointments(String patientId) => _staticAppointments;

  static final _staticMedications = [
    MedicationEntry(
      id: 'm001', name: 'Levodopa / Carbidopa', dose: '100mg / 25mg',
      scheduledTimes: ['07:30', '12:30', '17:30'], takenAt: [], color: '#1D9E75'),
    MedicationEntry(
      id: 'm002', name: 'Pramipexole', dose: '0.5mg',
      scheduledTimes: ['08:00', '20:00'], takenAt: [], color: '#185FA5'),
  ];

  static final _staticAppointments = [
    Appointment(
      id: 'a001', dateTime: DateTime(2026, 6, 18, 10, 30),
      clinicianName: 'Dr. Sarah Okonkwo',
      location: 'Movement Disorders Clinic, Floor 3',
      type: 'routine',
      discussionPoints: [
        'Tremor slightly increased since last visit',
        'Review Levodopa timing based on wrist data',
        'Discuss recent sleep quality from check-ins',
      ]),
    Appointment(
      id: 'a002', dateTime: DateTime(2026, 8, 5, 14, 0),
      clinicianName: 'Dr. Sarah Okonkwo',
      location: 'Phone consultation',
      type: 'phone',
      discussionPoints: [
        '3-month progress review',
        'Medication adjustment follow-up',
      ]),
  ];

  // --- Mock data ----------------------------------------------
  SymptomSnapshot _mockSnapshot() => SymptomSnapshot(
    timestamp:         DateTime.now().subtract(const Duration(minutes: 8)),
    tremorScore:       1.4,
    bradykinesiaScore: 1.1,
    dyskinesiaScore:   0.6,
    rigidityScore:     0.8,
  );

  List<SymptomSnapshot> _mockWeeklySnapshots() {
    final now     = DateTime.now();
    final tremors = [1.8, 1.2, 2.1, 1.4, 0.9, 1.6, 1.4];
    final bradys  = [1.2, 0.8, 1.5, 1.1, 0.7, 1.3, 1.1];
    final dysks   = [0.4, 0.2, 0.8, 0.6, 0.3, 0.5, 0.6];
    return List.generate(7, (i) => SymptomSnapshot(
      timestamp:         now.subtract(Duration(days: 6 - i)),
      tremorScore:       tremors[i],
      bradykinesiaScore: bradys[i],
      dyskinesiaScore:   dysks[i],
      rigidityScore:     0.6,
    ));
  }

  List<GaitMetrics> _mockWeeklyGait() {
    final now = DateTime.now();
    final speeds  = [0.82, 0.91, 0.78, 0.94, 0.88, 0.85, 0.90];
    final cadence = [92.0, 98.0, 88.0, 102.0, 96.0, 94.0, 98.0];
    return List.generate(7, (i) => GaitMetrics(
      timestamp:     now.subtract(Duration(days: 6 - i)),
      strideLength:  0.54 + (i * 0.008),
      stepFrequency: cadence[i],
      armSwingScore: 1.2,
      gaitSymmetry:  0.78 + (i * 0.005),
      walkingSpeed:  speeds[i],
      stepCount:     4200 + (i * 180),
    ));
  }

  List<MedicationResponsePoint> _mockMedicationResponse() {
    final now    = DateTime.now();
    final points = <MedicationResponsePoint>[];
    for (int min = 0; min <= 360; min += 15) {
      double tremor;
      double brady;
      if (min < 30) {
        tremor = 2.2 - (min / 30) * 0.9;
        brady  = 2.0 - (min / 30) * 0.8;
      } else if (min <= 180) {
        tremor = 1.0 + ((min - 30) / 150) * 0.4;
        brady  = 0.8 + ((min - 30) / 150) * 0.5;
      } else {
        tremor = 1.4 + ((min - 180) / 180) * 1.4;
        brady  = 1.3 + ((min - 180) / 180) * 1.2;
      }
      points.add(MedicationResponsePoint(
        timestamp:         now.subtract(Duration(minutes: 360 - min)),
        minutesSinceDose:  min.toDouble(),
        tremorScore:       tremor.clamp(0.0, 4.0),
        bradykinesiaScore: brady.clamp(0.0, 4.0),
        dyskinesiaScore:   (0.3 + (min / 360) * 0.8).clamp(0.0, 4.0),
        medicationName:    'Levodopa',
      ));
    }
    return points;
  }
}