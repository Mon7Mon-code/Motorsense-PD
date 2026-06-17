# Wrist-Worn Parkinson's Tremor Monitor

On-device tremor detection for a wrist-worn IMU sensor. A Seeed XIAO nRF52840 Sense samples a six-axis IMU, extracts tremor features and runs a small neural network in real time, then streams both the per-second result and the raw IMU samples to a paired phone over BLE.

This repository contains the device firmware, the synthetic-data training pipeline, and the exported model weights.

## Repository contents

| File | Purpose |
|------|---------|
| `PD_FINAL_REAL.ino` | Device firmware for the XIAO nRF52840 Sense (sampling, feature extraction, on-device inference, BLE streaming). |
| `model_weights.h` | Exported MLP weights, biases, and feature normalisation constants. Included by the firmware. |
| `updrs_to_imu_wrist_only.py` | Generates a synthetic wrist-IMU training set from MDS-UPDRS Part III clinical scores. |
| `Weightcreator.py` | Trains the binary tremor classifier and exports `model_weights.h` (Colab notebook). |
| `MDS-UPDRS_Part_III_28Jan2026.csv` | Source clinical scores used to seed the synthetic dataset. |

## Pipeline overview

```
MDS-UPDRS scores  ──►  updrs_to_imu_wrist_only.py  ──►  imu_wrist_training_data.csv
                       (synthesise wrist signals,        (features + labels)
                        extract features)
                                                              │
                                                              ▼
                                                      Weightcreator.py
                                                      (train MLP, export)
                                                              │
                                                              ▼
                                                       model_weights.h
                                                              │
                                                              ▼
            PD_FINAL_REAL.ino  ──►  on-device inference  ──►  BLE stream to phone
```

## Hardware

- **Board:** Seeed XIAO nRF52840 Sense
- **IMU:** on-board LSM6DS3TR-C (I²C, address `0x6A`)
- **Libraries:** `LSM6DS3`, `Wire`, `bluefruit.h` (bundled with the Seeed nRF52 board core)

`bluefruit.h` is required; ArduinoBLE is incompatible with the Seeed nRF52840 core because of SoftDevice conflicts.

## Build and flash

1. Install the **Seeed nRF52 Boards** package in the Arduino IDE Boards Manager.
2. Install the **Seeed Arduino LSM6DS3** library.
3. Select **Seeed XIAO nRF52840 Sense** as the board.
4. Keep `model_weights.h` in the same sketch folder as `PD_FINAL_REAL.ino`.
5. Compile and upload.

The board runs headless from power-on; it does not wait for a serial connection.

## Runtime behaviour

- Samples the accelerometer and gyroscope at **50 Hz** (20 ms interval).
- Maintains a **1-second window** (50 samples) of accelerometer data.
- Every full window, it extracts three features, normalises them, and runs the classifier.
- Acceleration is read in m/s² (gravity included); gyroscope in deg/s.

### Features

Computed per 1-second window from the gravity-subtracted acceleration magnitude:

1. **`log_power`** — log10 of the power summed across the 4, 5 and 6 Hz DFT bins (the tremor band).
2. **`rms`** — RMS of the gravity-subtracted magnitude.
3. **`dom_freq`** — dominant frequency (1–25 Hz bin search; integer Hz).

A custom DFT is used rather than a full FFT, since only a handful of low-frequency bins are needed.

### Classifier

A small multilayer perceptron, run with hand-written ReLU/sigmoid passes:

```
input[3] ─► Dense(8, ReLU) ─► Dense(4, ReLU) ─► Dense(1, sigmoid) ─► P(tremor)
```

Inputs are standardised with `FEATURE_MEAN` / `FEATURE_STD` before the first layer. Weights, biases and constants all live in `model_weights.h`.

### Decision logic

Tremor is flagged only when **all** of the following hold:

- `P(tremor) > 0.5`
- `dom_freq` between 4 and 6 Hz inclusive

When flagged, severity is assigned from the RMS:

| Severity | RMS range |
|----------|-----------|
| `MILD` | < 0.50 |
| `MODERATE` | 0.50 – 1.50 |
| `SEVERE` | 1.50 – 2.50 |
| `VERY_SEVERE` | ≥ 2.50 |

When not flagged, severity is `NONE`.

## BLE output

- **Device name:** `PD-Monitor`
- **Service UUID:** `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`
- **Characteristic UUID:** `B2C3D4E5-F6A7-8901-BCDE-F12345678901` (Read | Notify)

Each notification batches 6 CSV lines (one per sample, ~120 ms per batch at 50 Hz). Each line has 11 fields:

```
ax_rms,log_power,dom_freq,p_tremor,severity,accX,accY,accZ,gyrX,gyrY,gyrZ
```

Example:

```
0.1234,-1.2345,5,0.8732,MODERATE,9.8100,0.1234,-0.2345,0.0012,0.0034,-0.0056
```

The first five fields are the latest tremor result; they update once per second and repeat on every line until the next window. The last six fields are the raw IMU sample for that line (accel in m/s², gyro in deg/s).

## Regenerating the model

1. **Build the training set** — run `updrs_to_imu_wrist_only.py`, pointing `input_csv` at the MDS-UPDRS CSV. It uses the six upper-limb tremor columns valid for a wrist sensor (rest, postural and kinetic, left and right), synthesises 3-axis wrist accelerometer signals using the Elble displacement equation with a 15% wrist attenuation factor (Van der Linden et al., 2025), extracts the feature set, and writes `imu_wrist_training_data.csv`.
2. **Train and export** — run `Weightcreator.py` (Colab). It labels samples as tremor/no-tremor (`updrs_score > 0`), trains the 3→8→4→1 MLP on the three features, and exports `model_weights.h` (plus a TFLite model and `model_data.h`).
3. Replace `model_weights.h` in the sketch folder and re-flash.

## Notes and limitations

- The classifier is trained on physiologically grounded **synthetic** data seeded from clinical UPDRS scores, not on prospectively collected patient recordings.
- Detection is **binary** (tremor / no tremor); severity comes from RMS thresholds rather than a learned multi-class output.
- Training signals are synthesised at 100 Hz over 10-second windows, while the firmware extracts features from 50 Hz, 1-second windows. The feature definitions match, but anyone retraining should be aware of the difference in windowing.
- `bluefruit.h` and the Seeed nRF52 core are required; do not substitute ArduinoBLE.
