import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/patient_data.dart';
import '../tremor_pipeline.dart';
import '../gait_pipeline.dart';
import '../ble_service.dart';
import 'local_storage_service.dart';

class AppDataService extends ChangeNotifier {
  final TremorPipeline        tremorPipeline;
  final GaitPipeline          gaitPipeline;
  final BleService            bleService;
  final LocalStorageService   _storage;

  AppDataService({
    required this.tremorPipeline,
    required this.gaitPipeline,
    required this.bleService,
    required LocalStorageService storage,
  }) : _storage = storage {
    bleService.addListener(notifyListeners);
    _subscribeToUpdates();
  }

  // Load persisted data. Call once after construction, before runApp.
  Future<void> init() async {
    _checkIns.addAll(_storage.loadCheckIns());
    _medTakenAt.addAll(_storage.loadMedTaken());

    if (_storage.savedUserId != null) {
      _currentUserId   = _storage.savedUserId;
      _isClinicianMode = _storage.savedIsClinician;
    }
  }

  // --- Session -----------------------------------------------
  String? _currentUserId;
  bool    _isClinicianMode = false;
  bool    get isClinicianMode     => _isClinicianMode;
  String? get currentUserId       => _currentUserId;
  bool    get isOnboardingComplete => _storage.isOnboardingComplete;

  void login({required String userId, required bool asClinicianMode}) {
    _currentUserId   = userId;
    _isClinicianMode = asClinicianMode;
    unawaited(_storage.saveSession(userId, asClinicianMode));
    notifyListeners();
  }

  void logout() {
    _currentUserId = null;
    unawaited(_storage.clearSession());
    notifyListeners();
  }

  Future<void> saveOnboardingProfile({
    required String name,
    required String diagnosisYear,
    required String affectedSide,
  }) async {
    await _storage.saveOnboardingProfile(
      name: name,
      diagnosisYear: diagnosisYear,
      affectedSide: affectedSide,
    );
    notifyListeners();
  }

  // --- Pipeline subscriptions --------------------------------
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
    bleService.removeListener(notifyListeners);
    _tremorSub?.cancel();
    _gaitSub?.cancel();
    super.dispose();
  }

  // --- Device ------------------------------------------------
  DeviceStatus getDeviceStatus(String patientId) {
    return DeviceStatus(
      isConnected:    bleService.isActive,
      batteryPercent: bleService.batteryPercent,
      lastSyncTime:   _latestTremor?.timestamp ?? _latestGait?.timestamp,
      isWorn:         bleService.isActive,
    );
  }

  // --- Symptom snapshots -------------------------------------
  SymptomSnapshot? getLatestSnapshot(String patientId) {
    if (_latestTremor == null) return _mockSnapshot();
    return SymptomSnapshot(
      timestamp:         _latestTremor!.timestamp,
      tremorScore:       _latestTremor!.tremorSeverity.toDouble(),
      bradykinesiaScore: _bradykinesiaScore(),
      dyskinesiaScore:   _latestTremor!.dyskinesiaSeverity.toDouble(),
      rigidityScore:     0.0,
    );
  }

  double _bradykinesiaScore() {
    if (_latestGait != null) return _latestGait!.bradykinesiaSeverity.toDouble();
    return gaitPipeline.latestResult?.bradykinesiaSeverity.toDouble() ?? 0.0;
  }

  List<SymptomSnapshot> getWeeklySnapshots(String patientId) {
    if (_tremorHistory.isEmpty) return _mockWeeklySnapshots();
    final now    = DateTime.now();
    final result = <SymptomSnapshot>[];
    for (int daysAgo = 6; daysAgo >= 0; daysAgo--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
      final dayTremor = _tremorHistory.where((r) =>
          r.timestamp.year == day.year &&
          r.timestamp.month == day.month &&
          r.timestamp.day == day.day).toList();
      if (dayTremor.isNotEmpty) {
        final last = dayTremor.last;
        final g    = _closestGait(last.timestamp);
        result.add(SymptomSnapshot(
          timestamp:         last.timestamp,
          tremorScore:       last.tremorSeverity.toDouble(),
          bradykinesiaScore: g?.bradykinesiaSeverity.toDouble() ?? 0.0,
          dyskinesiaScore:   last.dyskinesiaSeverity.toDouble(),
          rigidityScore:     0.0,
        ));
      } else {
        result.add(SymptomSnapshot(
          timestamp:         day,
          tremorScore:       _latestTremor?.tremorSeverity.toDouble() ?? 0.0,
          bradykinesiaScore: _bradykinesiaScore(),
          dyskinesiaScore:   _latestTremor?.dyskinesiaSeverity.toDouble() ?? 0.0,
          rigidityScore:     0.0,
        ));
      }
    }
    return result;
  }

  GaitAnalysisResult? _closestGait(DateTime t) {
    if (_gaitHistory.isEmpty) return null;
    return _gaitHistory.reduce((a, b) =>
        a.timestamp.difference(t).abs() < b.timestamp.difference(t).abs() ? a : b);
  }

  GaitMetrics? getLatestGait(String patientId) {
    final r = _latestGait ?? gaitPipeline.latestResult;
    if (r == null) return null;
    final cad   = r.cadenceStepsPerMin ?? 0.0;
    final speed = r.walkingSpeedMs     ?? 0.0;
    return GaitMetrics(
      timestamp:     r.timestamp,
      strideLength:  cad > 0 ? speed * 60.0 / cad : 0.0,
      stepFrequency: cad,
      armSwingScore: r.bradykinesiaSeverity.toDouble(),
      gaitSymmetry:  (r.features['SYM_U'] ?? 0.80).clamp(0.0, 1.0),
      walkingSpeed:  speed,
      stepCount:     r.validation.stepCount,
    );
  }

  List<GaitMetrics> getWeeklyGait(String patientId) {
    if (_gaitHistory.isEmpty) return _mockWeeklyGait();
    final now    = DateTime.now();
    final result = <GaitMetrics>[];
    for (int daysAgo = 6; daysAgo >= 0; daysAgo--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysAgo));
      final dayGait = _gaitHistory.where((r) =>
          r.timestamp.year == day.year &&
          r.timestamp.month == day.month &&
          r.timestamp.day == day.day).toList();
      if (dayGait.isNotEmpty) {
        final last  = dayGait.last;
        final cad   = last.cadenceStepsPerMin ?? 0.0;
        final speed = last.walkingSpeedMs     ?? 0.0;
        result.add(GaitMetrics(
          timestamp:     last.timestamp,
          strideLength:  cad > 0 ? speed * 60.0 / cad : 0.0,
          stepFrequency: cad,
          armSwingScore: last.bradykinesiaSeverity.toDouble(),
          gaitSymmetry:  (last.features['SYM_U'] ?? 0.80).clamp(0.0, 1.0),
          walkingSpeed:  speed,
          stepCount:     last.validation.stepCount,
        ));
      } else {
        result.add(GaitMetrics(
          timestamp: day, strideLength: 0.58, stepFrequency: 98,
          armSwingScore: 1.0, gaitSymmetry: 0.80, walkingSpeed: 0.90, stepCount: 0,
        ));
      }
    }
    return result;
  }

  // --- Medication response -----------------------------------
  List<MedicationResponsePoint> getMedicationResponse(String patientId) {
    final meds = getMedications(patientId);
    if (meds.isEmpty || _tremorHistory.length < 5) return _mockMedicationResponse();
    final med    = meds.first;
    final points = <MedicationResponsePoint>[];
    for (final t in _tremorHistory.take(300)) {
      final mins = _minutesSinceLastDose(t.timestamp, med.scheduledTimes);
      if (mins == null) continue;
      final g = _closestGait(t.timestamp);
      points.add(MedicationResponsePoint(
        timestamp: t.timestamp, minutesSinceDose: mins,
        tremorScore: t.tremorSeverity.toDouble(),
        bradykinesiaScore: g?.bradykinesiaSeverity.toDouble() ?? 0.0,
        dyskinesiaScore: t.dyskinesiaSeverity.toDouble(),
        medicationName: med.name,
      ));
    }
    points.sort((a, b) => a.minutesSinceDose.compareTo(b.minutesSinceDose));
    return points.isEmpty ? _mockMedicationResponse() : points;
  }

  double? _minutesSinceLastDose(DateTime t, List<String> times) {
    DateTime? lastDose;
    for (final ts in times) {
      final parts = ts.split(':');
      if (parts.length < 2) continue;
      final dose = DateTime(t.year, t.month, t.day,
          int.parse(parts[0]), int.parse(parts[1]));
      if (dose.isBefore(t) && (lastDose == null || dose.isAfter(lastDose))) {
        lastDose = dose;
      }
    }
    return lastDose == null ? null : t.difference(lastDose).inMinutes.toDouble();
  }

  // --- Patient / clinician data ------------------------------
  List<Patient> getPatients(String clinicianId) => _buildPatients();
  Patient? getPatient(String patientId) =>
      _buildPatients().firstWhere((p) => p.id == patientId,
          orElse: () => _buildPatients().first);

  List<Patient> _buildPatients() => [
    Patient(
      id: 'p001',
      name: _storage.patientName.isNotEmpty ? _storage.patientName : 'Margaret Ellis',
      age: 68,
      diagnosisYear: _storage.diagnosisYear.isNotEmpty ? _storage.diagnosisYear : '2019',
      assignedClinicianId: 'c001',
      deviceStatus:       getDeviceStatus('p001'),
      medications:        getMedications('p001'),
      weeklySnapshots:    getWeeklySnapshots('p001'),
      weeklyGait:         getWeeklyGait('p001'),
      medicationResponse: getMedicationResponse('p001'),
      checkIns:           getCheckIns('p001'),
      appointments:       _staticAppointments,
      latestSnapshot:     getLatestSnapshot('p001'),
      baselineSnapshot:   getBaseline('p001'),
    ),
  ];

  SymptomSnapshot? getBaseline(String patientId) => SymptomSnapshot(
    timestamp: DateTime(2025, 10, 15),
    tremorScore: 0.8, bradykinesiaScore: 0.6,
    dyskinesiaScore: 0.1, rigidityScore: 0.5,
  );

  // --- Check-ins (persisted) ---------------------------------
  final List<WellbeingCheckIn> _checkIns = [];
  List<WellbeingCheckIn> getCheckIns(String patientId) => _checkIns;

  void logCheckIn({
    required String patientId, required int feelingScore,
    String? notes, List<String> symptoms = const [],
  }) {
    _checkIns.insert(0, WellbeingCheckIn(
      date: DateTime.now(), feelingScore: feelingScore,
      notes: notes, symptoms: symptoms,
    ));
    unawaited(_storage.saveCheckIns(_checkIns));
    notifyListeners();
  }

  // --- Medications (taken timestamps persisted) --------------
  final Map<String, List<DateTime>> _medTakenAt = {};

  List<MedicationEntry> getMedications(String patientId) {
    return _kBaseMedications.map((m) => MedicationEntry(
      id:             m.id,
      name:           m.name,
      dose:           m.dose,
      scheduledTimes: m.scheduledTimes,
      takenAt:        List.unmodifiable(_medTakenAt[m.id] ?? const []),
      color:          m.color,
    )).toList();
  }

  void logMedicationTaken(String patientId, String medicationId) {
    _medTakenAt.putIfAbsent(medicationId, () => []).add(DateTime.now());
    unawaited(_storage.saveMedTaken(_medTakenAt));
    notifyListeners();
  }

  List<Appointment> getAppointments(String patientId) => _staticAppointments;

  // --- Static seed data --------------------------------------
  static const _kBaseMedications = [
    _MedBase(id: 'm001', name: 'Levodopa / Carbidopa', dose: '100mg / 25mg',
        scheduledTimes: ['07:30', '12:30', '17:30'], color: '#1D9E75'),
    _MedBase(id: 'm002', name: 'Pramipexole', dose: '0.5mg',
        scheduledTimes: ['08:00', '20:00'], color: '#185FA5'),
  ];

  static final _staticAppointments = [
    Appointment(id: 'a001', dateTime: DateTime(2026, 6, 18, 10, 30),
        clinicianName: 'Dr. Sarah Okonkwo',
        location: 'Movement Disorders Clinic, Floor 3',
        type: 'routine', discussionPoints: [
          'Tremor slightly increased since last visit',
          'Review Levodopa timing based on wrist data',
          'Discuss recent sleep quality from check-ins',
        ]),
    Appointment(id: 'a002', dateTime: DateTime(2026, 8, 5, 14, 0),
        clinicianName: 'Dr. Sarah Okonkwo', location: 'Phone consultation',
        type: 'phone', discussionPoints: [
          '3-month progress review', 'Medication adjustment follow-up',
        ]),
  ];

  // --- Mock fallbacks (used when no sensor data yet) ---------
  SymptomSnapshot _mockSnapshot() => SymptomSnapshot(
    timestamp: DateTime.now(), tremorScore: 1.2,
    bradykinesiaScore: 0.8, dyskinesiaScore: 0.3, rigidityScore: 0.6,
  );

  List<SymptomSnapshot> _mockWeeklySnapshots() {
    final now = DateTime.now();
    return List.generate(7, (i) => SymptomSnapshot(
      timestamp: now.subtract(Duration(days: 6 - i)),
      tremorScore: 1.2, bradykinesiaScore: 0.8,
      dyskinesiaScore: 0.3, rigidityScore: 0.6,
    ));
  }

  List<GaitMetrics> _mockWeeklyGait() {
    final now = DateTime.now();
    return List.generate(7, (i) => GaitMetrics(
      timestamp: now.subtract(Duration(days: 6 - i)),
      strideLength: 0.58, stepFrequency: 98,
      armSwingScore: 1.0, gaitSymmetry: 0.80,
      walkingSpeed: 0.90, stepCount: 4200,
    ));
  }

  List<MedicationResponsePoint> _mockMedicationResponse() {
    final now = DateTime.now();
    return List.generate(25, (i) {
      final min = i * 15.0;
      return MedicationResponsePoint(
        timestamp: now.subtract(Duration(minutes: (360 - min).toInt())),
        minutesSinceDose: min,
        tremorScore: min < 30 ? 2.0 : min < 180 ? 1.0 : 1.5,
        bradykinesiaScore: min < 30 ? 1.8 : min < 180 ? 0.9 : 1.4,
        dyskinesiaScore: 0.3, medicationName: 'Levodopa',
      );
    });
  }
}

// Simple data holder for the medication seed list.
class _MedBase {
  final String id, name, dose, color;
  final List<String> scheduledTimes;
  const _MedBase({
    required this.id,
    required this.name,
    required this.dose,
    required this.scheduledTimes,
    required this.color,
  });
}
