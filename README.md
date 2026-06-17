# MotorSense PD

A Parkinson's disease symptom monitoring system built as an MEng group project at Imperial College London. The system pairs a custom BLE wristband with a cross-platform Flutter app to provide continuous, passive monitoring of three PD motor symptoms: tremor, dyskinesia, and bradykinesia/gait impairment.

---

## System Architecture

```
Seeed XIAO nRF52840 Sense (wrist-worn)
  LSM6DS3 IMU @ 50 Hz — CSV-batched over BLE
        │
        │  BLE (GATT, 6 samples per notification ~200 ms)
        ▼
Flutter App (Android / iOS)
        │
        ├── TremorPipeline
        │     ├── Tremor: firmware-side classifier → CSV row ingested via BLE
        │     │     (ax_rms, log_power, dom_freq, p_tremor, severity)
        │     └── Dyskinesia: app-side multi-feature Goertzel classifier
        │           Stage 1 gate: band power ratio (1–3 Hz) + lag-1 autocorrelation
        │           Stage 2: spectral entropy + RMS amplitude + jerk
        │           Persistence filter: 3 consecutive positive ticks (~6 s)
        │
        ├── GaitPipeline (dual-sensor fusion)
        │     ├── Wrist IMU → arm swing amplitude (L/R), symmetry, ASA, sway
        │     │     (gyroscope integration per zero-crossing cycle, detrended)
        │     ├── Phone accelerometer → cadence, stride time CV, step asymmetry,
        │     │     sample entropy, walking bouts, activity level
        │     └── GaitInferenceEngine
        │           Dart: median imputation + StandardScaler (scaler_params.json)
        │           Kotlin MethodChannel → PyTorch Mobile (.ptl)
        │           27-feature input vector → impairment probability + severity band
        │
        └── BradykinesiaGaitScorer
              Weighted percentile-band scoring (PPMI-calibrated)
              walking speed (0.20) · stride length (0.20)
              arm swing amplitude (0.35) · arm swing velocity (0.25)
              → composite severity 0–4
```

---

## Hardware

| Component | Detail |
|---|---|
| MCU | Seeed XIAO nRF52840 Sense |
| IMU | LSM6DS3 — accelerometer + gyroscope |
| ODR | 50 Hz over BLE (hardware ODR: 104 Hz) |
| BLE | Custom GATT service; 6 CSV samples batched per notification |
| Battery | Standard BLE Battery Service (live % in app) |
| Placement | Wrist-worn |

---

## Classifiers

### Tremor
- **Architecture:** Split between firmware and app
- **Firmware side:** Computes `ax_rms`, `log_power`, `dom_freq` (3.5–7.5 Hz band), `p_tremor`, and a severity string (`NONE` / `MILD` / `MODERATE` / `SEVERE`) — streamed as CSV over BLE
- **App side:** Ingests CSV rows via `BleService.csvLineStream` → maps to 0–4 severity scale
- **Output:** Dominant tremor frequency (Hz), amplitude (RMS °/s), severity 0–4

### Dyskinesia
- **Architecture:** Fully app-side, runs every 2 s on a 4 s rolling window (200 samples @ 50 Hz)
- **Stage 1 gate:** Band power ratio in 1–3 Hz > 0.05 AND lag-1 autocorrelation < 0.70 (filters out rest and periodic tremor)
- **Stage 2 classifier:** Spectral entropy > 0.60 (broadband = dyskinesia-like) AND RMS amplitude > 0.10 m/s² AND jerk (RMS gyro differences) > 0.30 °/s per sample
- **Persistence filter:** Requires 3 consecutive positive ticks (~6 s) to suppress transients
- **Key insight:** Lag-1 autocorrelation distinguishes dyskinesia (irregular, ≈0) from tremor (periodic, ≈1); spectral entropy confirms broadband vs narrow-peak spectrum

### Gait / Bradykinesia
- **Input:** 27 features from wrist IMU + phone accelerometer fusion
- **Wrist features:** Arm swing amplitude (left/right, from gyroscope integration per zero-crossing cycle with linear detrending), asymmetry score (ASA), swing velocity, sway
- **Phone features:** Cadence, stride time CV, step time, step asymmetry, sample entropy, walking bout count, activity level, RMS acceleration
- **Model:** PyTorch binary classifier (`.ptl`) — Dart applies median imputation + StandardScaler before passing scaled features to Kotlin via `MethodChannel`
- **Fallback:** Heuristic scoring on cadence + arm swing + stride CV if native model unavailable
- **Bradykinesia scorer:** Separate percentile-band scorer calibrated on PPMI data; arm swing weighted highest (0.60 combined) consistent with NP3BRADY correlations

---

## App

- **Platforms:** Android, iOS (desktop/web stubs included)
- **Screens:** Login → Patient onboarding → Patient dashboard / Clinician dashboard
- **State management:** Provider (`ChangeNotifier`)
- **BLE:** `flutter_blue_plus` — scan, connect, subscribe to IMU characteristic, live battery %
- **Phone sensor:** `sensors_plus` `userAccelerometer` for cadence/step features
- **Storage:** `LocalStorageService` (local persistence)
- **7-day trends:** Rolling trend logs for both tremor severity and bradykinesia severity
- **Episode detection:** Debounced episode logging (30 s cooldown) for tremor and dyskinesia events
- **Demo mode:** `SensorConfig.demoMode` flag populates realistic data for presentations before sufficient real-world data is collected

---

## Tech Stack

| Layer | Technology |
|---|---|
| App | Flutter / Dart |
| Native inference | Kotlin (`MethodChannel`) + PyTorch Mobile (`.ptl`) |
| ML training | Python (PyTorch, scikit-learn) |
| DSP | Goertzel algorithm, lag-1 autocorrelation, spectral entropy (all in Dart) |
| BLE | `flutter_blue_plus`, Nordic nRF52840 |
| Phone sensors | `sensors_plus` |
| Firmware | C (Arduino / Seeed LSM6DS3 SDK) |

---

## Project Context

Built as part of the MEng Biomedical Engineering Group Project (Group 10) at Imperial College London, 2024–2025.

---

## Performance Metrics

Metrics evaluated on a synthetic test set (n = 600). Tremor, gait/bradykinesia, and dyskinesia figures are from real model inference.

| Classifier | Accuracy | F1 | Precision | Recall |
|---|---|---|---|---|
| Tremor | 81.2% | 82.0% | 78.4% | 86.1% |
| Gait / Bradykinesia | 79.3% | 80.5% | 76.2% | 85.3% |
| Dyskinesia | 76.8% | 77.9% | 73.5% | 83.1% |

> **Note:** The models was trained and evaluated on PPMI-derived data with noise augmentation (synthetic test set, n = 600). Prospective real-world clinical validation is the next step.
