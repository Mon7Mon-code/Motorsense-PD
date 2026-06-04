import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient_data.dart';

class LocalStorageService {
  static const _keyUserId       = 'session_user_id';
  static const _keyIsClinician  = 'session_is_clinician';
  static const _keyOnboarded    = 'onboarding_complete';
  static const _keyPatientName  = 'patient_name';
  static const _keyDiagYear     = 'patient_diagnosis_year';
  static const _keyAffectedSide = 'patient_affected_side';
  static const _keyOnboardingTimestamp    = 'onboarding_timestamp';
  static const _keyBaselineElapsedSeconds = 'baseline_elapsed_seconds';
  static const _keyCheckIns     = 'check_ins_p001';
  static const _keyMedTaken     = 'med_taken_p001';

  final SharedPreferences _prefs;
  LocalStorageService._(this._prefs);

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService._(prefs);
  }

  // --- Session ------------------------------------------------
  String? get savedUserId => _prefs.getString(_keyUserId);
  bool get savedIsClinician => _prefs.getBool(_keyIsClinician) ?? false;

  Future<void> saveSession(String userId, bool isClinician) async {
    await _prefs.setString(_keyUserId, userId);
    await _prefs.setBool(_keyIsClinician, isClinician);
  }

  Future<void> clearSession() async {
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyIsClinician);
  }

  // --- Onboarding --------------------------------------------
  bool get isOnboardingComplete => _prefs.getBool(_keyOnboarded) ?? false;
  String get patientName   => _prefs.getString(_keyPatientName)  ?? '';
  String get diagnosisYear => _prefs.getString(_keyDiagYear)     ?? '';
  String get affectedSide  => _prefs.getString(_keyAffectedSide) ?? 'Left';
  DateTime? get onboardingTimestamp {
    final s = _prefs.getString(_keyOnboardingTimestamp);
    return s == null ? null : DateTime.tryParse(s);
  }

  int get baselineElapsedSeconds =>
      _prefs.getInt(_keyBaselineElapsedSeconds) ?? 0;

  Future<void> saveBaselineElapsed(int seconds) async {
    await _prefs.setInt(_keyBaselineElapsedSeconds, seconds);
  }

  Future<void> saveOnboardingProfile({
    required String name,
    required String diagnosisYear,
    required String affectedSide,
  }) async {
    await _prefs.setString(_keyPatientName,  name);
    await _prefs.setString(_keyDiagYear,     diagnosisYear);
    await _prefs.setString(_keyAffectedSide, affectedSide);
    await _prefs.setBool(_keyOnboarded, true);
    await _prefs.setString(
        _keyOnboardingTimestamp, DateTime.now().toIso8601String());
  }

  // --- Check-ins ---------------------------------------------
  List<WellbeingCheckIn> loadCheckIns() {
    final raw = _prefs.getString(_keyCheckIns);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => _checkInFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCheckIns(List<WellbeingCheckIn> checkIns) async {
    await _prefs.setString(
      _keyCheckIns,
      jsonEncode(checkIns.map(_checkInToJson).toList()),
    );
  }

  // --- Medication taken timestamps ---------------------------
  Map<String, List<DateTime>> loadMedTaken() {
    final raw = _prefs.getString(_keyMedTaken);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
        k,
        (v as List).map((s) => DateTime.parse(s as String)).toList(),
      ));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveMedTaken(Map<String, List<DateTime>> taken) async {
    await _prefs.setString(
      _keyMedTaken,
      jsonEncode(taken.map((k, v) =>
        MapEntry(k, v.map((d) => d.toIso8601String()).toList()),
      )),
    );
  }

  // --- Serialization helpers ---------------------------------
  static Map<String, dynamic> _checkInToJson(WellbeingCheckIn c) => {
    'date':         c.date.toIso8601String(),
    'feelingScore': c.feelingScore,
    'notes':        c.notes,
    'symptoms':     c.symptoms,
  };

  static WellbeingCheckIn _checkInFromJson(Map<String, dynamic> m) =>
    WellbeingCheckIn(
      date:         DateTime.parse(m['date'] as String),
      feelingScore: m['feelingScore'] as int,
      notes:        m['notes'] as String?,
      symptoms:     (m['symptoms'] as List).cast<String>(),
    );
}
