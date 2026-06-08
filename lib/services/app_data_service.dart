import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/patient_data.dart';
import '../tremor_pipeline.dart';
import '../gait_pipeline.dart';
import '../ble_service.dart';
import 'local_storage_service.dart';
import '../sensor_config.dart';

/// Which data-quality state a sensor-derived card should display.
/// Ordered from "best" to "worst" — callers may compare with >=.
enum SensorDataState {
  live,               // real data < 5 min old, device connected
  stale,              // real data 5–30 min old
  disconnected,       // real data 30 min–2 h old, device not connected
  collectingBaseline, // device connected + streaming during the baseline window
  baselinePaused,     // baseline window open but device not connected / not streaming
  connecting,         // BLE scan / connect in progress
  insufficientData,   // real data > 2 h old, or baseline window passed with no data
  noDevice,           // onboarding never completed / device never set up
}

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
    final savedMeds = _storage.loadMedications();
    if (savedMeds.isNotEmpty) {
      _medications
        ..clear()
        ..addAll(savedMeds.map(_medFromJson));
    }
    _accumulatedBaselineSeconds = _storage.baselineElapsedSeconds;

    if (_storage.savedUserId != null) {
      _currentUserId   = _storage.savedUserId;
      _isClinicianMode = _storage.savedIsClinician;
    }
  }

  // --- Session -----------------------------------------------
  String? _currentUserId;
  bool    _isClinicianMode = false;
  bool    get isClinicianMode      => _isClinicianMode;
  String? get currentUserId        => _currentUserId;
  bool    get isOnboardingComplete => _storage.isOnboardingComplete || SensorConfig.demoMode;
  bool    get hasRealSensorData    => _latestTremor != null;

  /// Patient display name — used by patient home screen header.
  String get patientName =>
      _storage.patientName.isNotEmpty ? _storage.patientName : 'Margaret';

  /// How long ago the last real sensor reading arrived. Null if never.
  Duration? get lastSyncAge => _latestTremor == null
      ? null
      : DateTime.now().difference(_latestTremor!.timestamp);

  SensorDataState get sensorDataState {
    if (SensorConfig.demoMode) return SensorDataState.live;
    final ble = bleService.status;
    if (ble == BleStatus.scanning || ble == BleStatus.connecting) {
      return SensorDataState.connecting;
    }
    if (_storage.onboardingTimestamp == null) {
      return SensorDataState.noDevice;
    }
    if (!isBaselineComplete) {
      // Only "collecting" when device is actually connected and data is flowing.
      return (bleService.isActive && _latestTremor != null)
          ? SensorDataState.collectingBaseline
          : SensorDataState.baselinePaused;
    }
    if (_latestTremor == null) {
      return SensorDataState.insufficientData;
    }
    final age = DateTime.now().difference(_latestTremor!.timestamp);
    if (age.inMinutes < 5)   return SensorDataState.live;
    if (age.inMinutes < 30)  return SensorDataState.stale;
    if (age.inMinutes < 120) return SensorDataState.disconnected;
    return SensorDataState.insufficientData;
  }

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

  // --- Baseline wear-time accumulator -----------------------
  // Persisted via LocalStorageService. Only incremented while the wearable
  // is actively connected AND delivering sensor data.
  int _accumulatedBaselineSeconds = 0;

  // --- Pipeline subscriptions --------------------------------
  TremorResult?       _latestTremor;
  GaitAnalysisResult? _latestGait;
  final List<TremorResult>       _tremorHistory = [];
  final List<GaitAnalysisResult> _gaitHistory   = [];
  StreamSubscription? _tremorSub;
  StreamSubscription? _gaitSub;
  Timer?              _stalenessTimer;

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
    // Every minute: age stale banners + accumulate baseline wear-time.
    _stalenessTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _accumulateBaselineTime();
      if (_latestTremor != null) notifyListeners();
    });
  }

  @override
  void dispose() {
    bleService.removeListener(notifyListeners);
    _tremorSub?.cancel();
    _gaitSub?.cancel();
    _stalenessTimer?.cancel();
    super.dispose();
  }

  // --- Device ------------------------------------------------
  DeviceStatus getDeviceStatus(String patientId) {
    if (SensorConfig.demoMode) {
      return DeviceStatus(
        isConnected:    true,
        batteryPercent: 78,
        lastSyncTime:   DateTime.now().subtract(const Duration(minutes: 3)),
        isWorn:         true,
      );
    }
    return DeviceStatus(
      isConnected:    bleService.isActive,
      batteryPercent: bleService.batteryPercent,
      lastSyncTime:   _latestTremor?.timestamp ?? _latestGait?.timestamp,
      isWorn:         bleService.isActive,
    );
  }

  // --- Symptom snapshots -------------------------------------
  SymptomSnapshot? getLatestSnapshot(String patientId) {
    if (SensorConfig.demoMode) return _demoSnapshot;
    if (_latestTremor == null) return null;
    return SymptomSnapshot(
      timestamp:         _latestTremor!.timestamp,
      tremorScore:       _latestTremor!.tremorSeverity.toDouble(),
      bradykinesiaScore: _bradykinesiaScore(),
      dyskinesiaScore:   _latestTremor!.dyskinesiaSeverity.toDouble(),
    );
  }

  double _bradykinesiaScore() {
    if (_latestGait != null) return _latestGait!.bradykinesiaSeverity.toDouble();
    return gaitPipeline.latestResult?.bradykinesiaSeverity.toDouble() ?? 0.0;
  }

  List<SymptomSnapshot> getWeeklySnapshots(String patientId) {
    if (SensorConfig.demoMode) return _demoWeeklySnapshots;
    if (_tremorHistory.isEmpty) return [];
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
    if (SensorConfig.demoMode) return _demoGait;
    final r = _latestGait ?? gaitPipeline.latestResult;
    if (r == null) return null;
    final cad   = r.cadenceStepsPerMin ?? 0.0;
    final speed = r.walkingSpeedMs     ?? 0.0;
    return GaitMetrics(
      timestamp:     r.timestamp,
      strideLength:  cad > 0 ? speed * 60.0 / cad : 0.0,
      stepFrequency: cad,
      armSwingScore: r.bradykinesiaSeverity.toDouble(),
      gaitSymmetry:  (r.features['SYM_U'] ?? 0.0).clamp(0.0, 1.0),
      walkingSpeed:  speed,
      stepCount:     r.validation.stepCount,
    );
  }

  List<GaitMetrics> getWeeklyGait(String patientId) {
    if (SensorConfig.demoMode) return _demoWeeklyGait;
    if (_gaitHistory.isEmpty) return [];
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
      }
    }
    return result;
  }

  // --- Medication response -----------------------------------
  List<MedicationResponsePoint> getMedicationResponse(String patientId) {
    if (SensorConfig.demoMode) return _demoMedicationResponse;
    final meds = getMedications(patientId);
    if (meds.isEmpty || _tremorHistory.length < 5) return [];
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
    return points;
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
      name: _storage.patientName.isNotEmpty ? _storage.patientName : 'Patient',
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

  static const _baselineDuration = Duration(hours: 24);

  DateTime? get _onboardingTimestamp => _storage.onboardingTimestamp;

  /// Progress is based on accumulated seconds the wearable was actively
  /// connected and streaming — not wall-clock time.
  double get baselineProgress {
    if (_onboardingTimestamp == null) return 0.0;
    return (_accumulatedBaselineSeconds / _baselineDuration.inSeconds)
        .clamp(0.0, 1.0);
  }

  bool get isBaselineComplete =>
      SensorConfig.demoMode ||
      _accumulatedBaselineSeconds >= _baselineDuration.inSeconds;

  Duration get baselineTimeRemaining {
    if (_onboardingTimestamp == null) return _baselineDuration;
    final remainingSeconds =
        _baselineDuration.inSeconds - _accumulatedBaselineSeconds;
    return remainingSeconds <= 0
        ? Duration.zero
        : Duration(seconds: remainingSeconds);
  }

  void _accumulateBaselineTime() {
    if (_onboardingTimestamp == null) return;
    if (isBaselineComplete) return;
    if (!bleService.isActive || _latestTremor == null) return;
    _accumulatedBaselineSeconds =
        (_accumulatedBaselineSeconds + 60).clamp(0, _baselineDuration.inSeconds);
    unawaited(_storage.saveBaselineElapsed(_accumulatedBaselineSeconds));
  }

  /// Returns null until the baseline window is complete.
  /// Computed as the median of the earliest 20% of collected readings.
  SymptomSnapshot? getBaseline(String patientId) {
    if (SensorConfig.demoMode) return _demoBaseline;
    if (!isBaselineComplete) return null;
    if (_tremorHistory.isEmpty) return null;

    final sampleSize = (_tremorHistory.length * 0.2).ceil().clamp(1, _tremorHistory.length);
    final early = _tremorHistory.sublist(0, sampleSize);

    final tremorScores = early.map((r) => r.tremorSeverity.toDouble()).toList()..sort();
    final dyskinesiaScores = early.map((r) => r.dyskinesiaSeverity.toDouble()).toList()..sort();
    final mid = sampleSize ~/ 2;

    double bradyBaseline = 0.0;
    if (_gaitHistory.isNotEmpty) {
      final earlyGait = _gaitHistory.sublist(0, (_gaitHistory.length * 0.2).ceil().clamp(1, _gaitHistory.length));
      final bradyScores = earlyGait.map((r) => r.bradykinesiaSeverity.toDouble()).toList()..sort();
      bradyBaseline = bradyScores[bradyScores.length ~/ 2];
    }

    return SymptomSnapshot(
      timestamp: _storage.onboardingTimestamp ?? DateTime.now(),
      tremorScore: tremorScores[mid],
      bradykinesiaScore: bradyBaseline,
      dyskinesiaScore: dyskinesiaScores[mid],
    );
  }

  // --- Check-ins (persisted) ---------------------------------
  final List<WellbeingCheckIn> _checkIns = [];
  List<WellbeingCheckIn> getCheckIns(String patientId) {
    if (SensorConfig.demoMode) return _demoCheckIns;
    return _checkIns;
  }

  void logCheckIn({
    required String patientId, required int feelingScore,
    String? notes, List<String> symptoms = const [],
  }) {
    final now = DateTime.now();
    final todayIndex = _checkIns.indexWhere((c) =>
        c.date.year == now.year &&
        c.date.month == now.month &&
        c.date.day == now.day);
    final entry = WellbeingCheckIn(
      date: now, feelingScore: feelingScore,
      notes: notes, symptoms: symptoms,
    );
    if (todayIndex >= 0) {
      _checkIns[todayIndex] = entry;
    } else {
      _checkIns.insert(0, entry);
    }
    unawaited(_storage.saveCheckIns(_checkIns));
    notifyListeners();
  }

  // --- Medications (list + taken timestamps persisted) -------
  final Map<String, List<DateTime>> _medTakenAt = {};
  final List<_MedBase> _medications = [
    const _MedBase(id: 'm001', name: 'Levodopa / Carbidopa', dose: '100mg / 25mg',
        scheduledTimes: ['07:30', '12:30', '17:30'], color: '#1D9E75'),
    const _MedBase(id: 'm002', name: 'Pramipexole', dose: '0.5mg',
        scheduledTimes: ['08:00', '20:00'], color: '#185FA5'),
  ];

  static const _kMedColors = [
    '#1D9E75', '#185FA5', '#9E4C1D', '#7B1D9E', '#CF8C2A', '#2A8DCF',
  ];

  List<MedicationEntry> getMedications(String patientId) {
    return _medications.map((m) => MedicationEntry(
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

  void addMedication({
    required String name,
    required String dose,
    required List<String> scheduledTimes,
    String? color,
  }) {
    final id = 'm_${DateTime.now().millisecondsSinceEpoch}';
    final c = color ?? _kMedColors[_medications.length % _kMedColors.length];
    _medications.add(_MedBase(id: id, name: name, dose: dose,
        scheduledTimes: List.unmodifiable(scheduledTimes), color: c));
    unawaited(_storage.saveMedications(_medications.map(_medToJson).toList()));
    notifyListeners();
  }

  void removeMedication(String medicationId) {
    _medications.removeWhere((m) => m.id == medicationId);
    _medTakenAt.remove(medicationId);
    unawaited(_storage.saveMedications(_medications.map(_medToJson).toList()));
    unawaited(_storage.saveMedTaken(_medTakenAt));
    notifyListeners();
  }

  void updateMedication(String medicationId, {
    String? name, String? dose, List<String>? scheduledTimes,
  }) {
    final idx = _medications.indexWhere((m) => m.id == medicationId);
    if (idx < 0) return;
    final e = _medications[idx];
    _medications[idx] = _MedBase(
      id: e.id,
      name: name ?? e.name,
      dose: dose ?? e.dose,
      scheduledTimes: scheduledTimes != null
          ? List.unmodifiable(scheduledTimes)
          : e.scheduledTimes,
      color: e.color,
    );
    unawaited(_storage.saveMedications(_medications.map(_medToJson).toList()));
    notifyListeners();
  }

  static Map<String, dynamic> _medToJson(_MedBase m) => {
    'id': m.id, 'name': m.name, 'dose': m.dose,
    'scheduledTimes': m.scheduledTimes, 'color': m.color,
  };

  static _MedBase _medFromJson(Map<String, dynamic> j) => _MedBase(
    id: j['id'] as String,
    name: j['name'] as String,
    dose: j['dose'] as String,
    scheduledTimes: List.unmodifiable((j['scheduledTimes'] as List).cast<String>()),
    color: j['color'] as String,
  );

  List<Appointment> getAppointments(String patientId) => _staticAppointments;

  // --- Static seed data --------------------------------------

  // ── DEMO DATA ────────────────────────────────────────────────────────────────
  // All values below are used when SensorConfig.demoMode == true.
  // They represent a realistic patient profile after ~3 months of monitoring.

  static final _demoSnapshot = SymptomSnapshot(
    timestamp:         DateTime(2026, 6, 8, 14, 18),
    tremorScore:       1.2,   // mild
    bradykinesiaScore: 1.8,   // mild-moderate
    dyskinesiaScore:   0.6,   // minimal
    rigidityScore:     1.4,   // mild (not hardware-measured; demo only)
  );

  static final _demoBaseline = SymptomSnapshot(
    timestamp:         DateTime(2026, 3, 10, 9, 0),
    tremorScore:       1.0,
    bradykinesiaScore: 1.5,
    dyskinesiaScore:   0.4,
    rigidityScore:     1.2,
  );

  static List<SymptomSnapshot> get _demoWeeklySnapshots {
    final base = DateTime(2026, 6, 8);
    return [
      SymptomSnapshot(timestamp: base.subtract(const Duration(days: 6)), tremorScore: 1.5, bradykinesiaScore: 2.0, dyskinesiaScore: 0.8, rigidityScore: 1.6),
      SymptomSnapshot(timestamp: base.subtract(const Duration(days: 5)), tremorScore: 1.3, bradykinesiaScore: 1.9, dyskinesiaScore: 0.6, rigidityScore: 1.4),
      SymptomSnapshot(timestamp: base.subtract(const Duration(days: 4)), tremorScore: 1.6, bradykinesiaScore: 2.1, dyskinesiaScore: 0.9, rigidityScore: 1.7),
      SymptomSnapshot(timestamp: base.subtract(const Duration(days: 3)), tremorScore: 1.1, bradykinesiaScore: 1.7, dyskinesiaScore: 0.5, rigidityScore: 1.3),
      SymptomSnapshot(timestamp: base.subtract(const Duration(days: 2)), tremorScore: 1.4, bradykinesiaScore: 1.8, dyskinesiaScore: 0.7, rigidityScore: 1.5),
      SymptomSnapshot(timestamp: base.subtract(const Duration(days: 1)), tremorScore: 1.2, bradykinesiaScore: 1.6, dyskinesiaScore: 0.5, rigidityScore: 1.3),
      SymptomSnapshot(timestamp: base,                                    tremorScore: 1.2, bradykinesiaScore: 1.8, dyskinesiaScore: 0.6, rigidityScore: 1.4),
    ];
  }

  static final _demoGait = GaitMetrics(
    timestamp:     DateTime(2026, 6, 8, 14, 15),
    strideLength:  1.18,
    stepFrequency: 97.0,
    armSwingScore: 1.8,
    gaitSymmetry:  0.82,
    walkingSpeed:  1.14,
    stepCount:     4231,
  );

  static List<GaitMetrics> get _demoWeeklyGait {
    final base = DateTime(2026, 6, 8);
    return [
      GaitMetrics(timestamp: base.subtract(const Duration(days: 6)), strideLength: 1.12, stepFrequency: 94.0, armSwingScore: 2.0, gaitSymmetry: 0.78, walkingSpeed: 1.08, stepCount: 3800),
      GaitMetrics(timestamp: base.subtract(const Duration(days: 5)), strideLength: 1.15, stepFrequency: 96.0, armSwingScore: 1.9, gaitSymmetry: 0.80, walkingSpeed: 1.10, stepCount: 4100),
      GaitMetrics(timestamp: base.subtract(const Duration(days: 4)), strideLength: 1.10, stepFrequency: 93.0, armSwingScore: 2.1, gaitSymmetry: 0.76, walkingSpeed: 1.05, stepCount: 3600),
      GaitMetrics(timestamp: base.subtract(const Duration(days: 3)), strideLength: 1.20, stepFrequency: 98.0, armSwingScore: 1.7, gaitSymmetry: 0.84, walkingSpeed: 1.16, stepCount: 4500),
      GaitMetrics(timestamp: base.subtract(const Duration(days: 2)), strideLength: 1.17, stepFrequency: 97.0, armSwingScore: 1.8, gaitSymmetry: 0.82, walkingSpeed: 1.13, stepCount: 4200),
      GaitMetrics(timestamp: base.subtract(const Duration(days: 1)), strideLength: 1.19, stepFrequency: 97.0, armSwingScore: 1.7, gaitSymmetry: 0.83, walkingSpeed: 1.15, stepCount: 4350),
      GaitMetrics(timestamp: base,                                    strideLength: 1.18, stepFrequency: 97.0, armSwingScore: 1.8, gaitSymmetry: 0.82, walkingSpeed: 1.14, stepCount: 4231),
    ];
  }

  static List<MedicationResponsePoint> get _demoMedicationResponse {
    final base = DateTime(2026, 6, 8, 7, 30);
    return List.generate(24, (i) {
      final mins = i * 15.0;
      // Medication effect: tremor dips at ~45–90 min post-dose, rises after 3 h
      final phase = mins / 180.0;
      final tremorCurve = 1.8 - 0.8 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.0, 1.0);
      final bradyCurve  = 2.0 - 0.7 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.0, 1.0);
      return MedicationResponsePoint(
        timestamp:         base.add(Duration(minutes: i * 15)),
        minutesSinceDose:  mins,
        tremorScore:       tremorCurve.clamp(0.5, 3.5),
        bradykinesiaScore: bradyCurve.clamp(0.8, 3.5),
        dyskinesiaScore:   (0.4 + 0.4 * (phase < 0.3 ? phase / 0.3 : 0.0)).clamp(0.0, 1.5),
        medicationName:    'Levodopa / Carbidopa',
      );
    });
  }

  static List<WellbeingCheckIn> get _demoCheckIns {
    final base = DateTime(2026, 6, 8);
    return [
      WellbeingCheckIn(date: base,                                    feelingScore: 3, symptoms: [],                   notes: 'Feeling good today'),
      WellbeingCheckIn(date: base.subtract(const Duration(days: 1)), feelingScore: 2, symptoms: ['Stiffness'],         notes: null),
      WellbeingCheckIn(date: base.subtract(const Duration(days: 2)), feelingScore: 3, symptoms: [],                   notes: null),
      WellbeingCheckIn(date: base.subtract(const Duration(days: 3)), feelingScore: 2, symptoms: ['Tremor', 'Fatigue'], notes: 'Harder afternoon'),
      WellbeingCheckIn(date: base.subtract(const Duration(days: 4)), feelingScore: 3, symptoms: [],                   notes: null),
      WellbeingCheckIn(date: base.subtract(const Duration(days: 5)), feelingScore: 3, symptoms: [],                   notes: 'Good walk in the morning'),
      WellbeingCheckIn(date: base.subtract(const Duration(days: 6)), feelingScore: 1, symptoms: ['Tremor', 'Pain'],   notes: 'Rough day'),
    ];
  }

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
