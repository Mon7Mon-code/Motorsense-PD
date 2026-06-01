// ============================================================
// DATA MODELS — Parkinson's Tracker App
// These models define the contract between the UI and the
// processing team. Field names and types must remain stable.
// ============================================================

// --- Device status (from BLE layer) -------------------------
class DeviceStatus {
  final bool isConnected;
  final int batteryPercent; // 0–100
  final DateTime? lastSyncTime;
  final bool isWorn; // detected from accelerometer variance

  const DeviceStatus({
    required this.isConnected,
    required this.batteryPercent,
    this.lastSyncTime,
    required this.isWorn,
  });
}

// --- Core symptom metrics (from processing team) ------------
// All scores are 0.0–4.0 following MDS-UPDRS convention
class SymptomSnapshot {
  final DateTime timestamp;
  final double tremorScore;      // 0.0–4.0
  final double bradykinesiaScore; // 0.0–4.0
  final double dyskinesiaScore;  // 0.0–4.0
  final double rigidityScore;    // 0.0–4.0 (if available)

  const SymptomSnapshot({
    required this.timestamp,
    required this.tremorScore,
    required this.bradykinesiaScore,
    required this.dyskinesiaScore,
    required this.rigidityScore,
  });

  // Human-readable label for patients (no raw numbers shown)
  String get tremorLabel => _scoreToLabel(tremorScore);
  String get bradykinesiaLabel => _scoreToLabel(bradykinesiaScore);
  String get dyskinesiaLabel => _scoreToLabel(dyskinesiaScore);

  static String _scoreToLabel(double score) {
    if (score < 0.5) return 'None';
    if (score < 1.5) return 'Mild';
    if (score < 2.5) return 'Moderate';
    if (score < 3.5) return 'Notable';
    return 'Severe';
  }

  // Overall wellness (inverted, 0=worst 1=best) for patient UI
  double get overallWellness =>
      1.0 - ((tremorScore + bradykinesiaScore + dyskinesiaScore) / 12.0);
}

// --- Gait metrics (from processing team) --------------------
class GaitMetrics {
  final DateTime timestamp;
  final double strideLength;     // metres
  final double stepFrequency;    // steps/min
  final double armSwingScore;    // 0.0–4.0
  final double gaitSymmetry;     // 0.0–1.0 (1 = perfect symmetry)
  final double walkingSpeed;     // m/s
  final int stepCount;

  const GaitMetrics({
    required this.timestamp,
    required this.strideLength,
    required this.stepFrequency,
    required this.armSwingScore,
    required this.gaitSymmetry,
    required this.walkingSpeed,
    required this.stepCount,
  });
}

// --- Medication entry ---------------------------------------
class MedicationEntry {
  final String id;
  final String name;         // e.g. "Levodopa"
  final String dose;         // e.g. "100mg"
  final List<String> scheduledTimes; // e.g. ["08:00", "13:00", "18:00"]
  final List<DateTime> takenAt;      // actual intake timestamps logged by patient
  final String color;        // hex for UI pill colour

  const MedicationEntry({
    required this.id,
    required this.name,
    required this.dose,
    required this.scheduledTimes,
    required this.takenAt,
    required this.color,
  });

  bool get nextDoseMissed {
    // Placeholder — real logic will compare scheduledTimes vs takenAt
    return false;
  }
}

// --- Medication response (processing team output) -----------
// Correlates symptom scores with time-since-last-dose
class MedicationResponsePoint {
  final DateTime timestamp;
  final double minutesSinceDose;
  final double tremorScore;
  final double bradykinesiaScore;
  final double dyskinesiaScore;
  final String medicationName;

  const MedicationResponsePoint({
    required this.timestamp,
    required this.minutesSinceDose,
    required this.tremorScore,
    required this.bradykinesiaScore,
    required this.dyskinesiaScore,
    required this.medicationName,
  });
}

// --- Daily wellbeing check-in (patient self-report) ---------
class WellbeingCheckIn {
  final DateTime date;
  final int feelingScore; // 1=poor, 2=okay, 3=good
  final String? notes;
  final List<String> symptoms; // self-reported ["stiffness", "fatigue", ...]

  const WellbeingCheckIn({
    required this.date,
    required this.feelingScore,
    this.notes,
    required this.symptoms,
  });

  String get feelingLabel {
    switch (feelingScore) {
      case 1: return 'Not great';
      case 2: return 'Okay';
      case 3: return 'Good';
      default: return 'Unknown';
    }
  }
}

// --- Appointment -------------------------------------------
class Appointment {
  final String id;
  final DateTime dateTime;
  final String clinicianName;
  final String location;
  final String type; // "routine", "urgent", "phone"
  final List<String> discussionPoints; // auto-generated from data

  const Appointment({
    required this.id,
    required this.dateTime,
    required this.clinicianName,
    required this.location,
    required this.type,
    required this.discussionPoints,
  });
}

// --- Patient profile ----------------------------------------
class Patient {
  final String id;
  final String name;
  final int age;
  final String diagnosisYear;
  final String assignedClinicianId;
  final SymptomSnapshot? latestSnapshot;
  final GaitMetrics? latestGait;
  final DeviceStatus deviceStatus;
  final List<MedicationEntry> medications;
  final List<SymptomSnapshot> weeklySnapshots; // 7-day history
  final List<GaitMetrics> weeklyGait;
  final List<MedicationResponsePoint> medicationResponse;
  final List<WellbeingCheckIn> checkIns;
  final List<Appointment> appointments;
  final SymptomSnapshot? baselineSnapshot; // set at onboarding

  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.diagnosisYear,
    required this.assignedClinicianId,
    this.latestSnapshot,
    this.latestGait,
    required this.deviceStatus,
    required this.medications,
    required this.weeklySnapshots,
    required this.weeklyGait,
    required this.medicationResponse,
    required this.checkIns,
    required this.appointments,
    this.baselineSnapshot,
  });

  // Deviation from baseline (0 = at baseline, positive = worse)
  double? get tremorDeviation {
    if (latestSnapshot == null || baselineSnapshot == null) return null;
    return latestSnapshot!.tremorScore - baselineSnapshot!.tremorScore;
  }

  String get statusFlag {
    final t = latestSnapshot?.tremorScore ?? 0;
    final b = latestSnapshot?.bradykinesiaScore ?? 0;
    final d = latestSnapshot?.dyskinesiaScore ?? 0;
    final avg = (t + b + d) / 3;
    if (avg >= 2.5) return 'needs-attention';
    if (avg >= 1.5) return 'monitor';
    return 'stable';
  }
}

// --- Clinician profile --------------------------------------
class Clinician {
  final String id;
  final String name;
  final String title;
  final List<String> patientIds;

  const Clinician({
    required this.id,
    required this.name,
    required this.title,
    required this.patientIds,
  });
}
