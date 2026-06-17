"""
extract_scaler.py
Dumps outputs/scaler.pkl to outputs/scaler_params.json for Flutter.

Flutter uses this JSON to replicate the imputer + scaler transform in Dart/C++
without needing Python or scikit-learn at runtime.

Run AFTER train_gait.py has produced outputs/scaler.pkl.
"""

import os
import json
import pickle
import numpy as np


SCALER_PATH     = os.path.join("outputs", "scaler.pkl")
THRESHOLDS_PATH = os.path.join("outputs", "severity_thresholds.json")
OUTPUT_PATH     = os.path.join("outputs", "scaler_params.json")


def main():
    # ── Load scaler.pkl ───────────────────────────────────────────────────────
    if not os.path.exists(SCALER_PATH):
        print(f"ERROR: {SCALER_PATH} not found. Run train_gait.py first.")
        return

    with open(SCALER_PATH, "rb") as f:
        bundle = pickle.load(f)

    imputer      = bundle["imputer"]
    scaler       = bundle["scaler"]
    feature_cols = bundle["feature_cols"]

    print(f"Loaded scaler.pkl")
    print(f"  Features ({len(feature_cols)}): {feature_cols}")

    # ── Validate dimensions ───────────────────────────────────────────────────
    assert len(imputer.statistics_) == len(feature_cols), \
        f"Imputer dim mismatch: {len(imputer.statistics_)} vs {len(feature_cols)}"
    assert len(scaler.mean_) == len(feature_cols), \
        f"Scaler dim mismatch: {len(scaler.mean_)} vs {len(feature_cols)}"

    # ── Load severity thresholds ──────────────────────────────────────────────
    if os.path.exists(THRESHOLDS_PATH):
        with open(THRESHOLDS_PATH, "r") as f:
            severity_thresholds = json.load(f)
        print(f"Loaded severity thresholds from {THRESHOLDS_PATH}")
    else:
        print(f"[warn] {THRESHOLDS_PATH} not found — severity_thresholds will be omitted.")
        print("  Run calibrate_severity.py first for complete output.")
        severity_thresholds = None

    # ── Build per-feature parameter list ─────────────────────────────────────
    features = []
    for i, name in enumerate(feature_cols):
        features.append({
            "name":           name,
            "index":          i,
            "imputer_median": float(imputer.statistics_[i]),
            "scaler_mean":    float(scaler.mean_[i]),
            "scaler_std":     float(scaler.scale_[i]),
        })

    # ── Annotate feature groups for Flutter reference ─────────────────────────
    OPALS_UNIVERSAL = {"CAD_U", "STR_CV_U", "SP_U"}
    OPALS_ARMSWING  = {"RA_AMP_U", "LA_AMP_U", "SYM_U", "ASA_U"}
    OPALS_SWAY      = {"SW_VEL_OP", "SW_PATH_OP", "SW_FREQ_OP"}
    AXIVITY_COLS    = {
        "MeanSVMDaymg", "PercentWalking", "ActivityLevel",
        "CadencetimeDomain", "NumberOfBouts", "wdV", "stepTime", "strideTime",
        "CVStrideTime", "SampEntropyV", "stepAsymV", "StepVelocitycmsec", "rmsV",
    }
    FLAGS           = {"has_armswing", "has_sway", "has_axivity", "GAIT_SUBGROUP"}

    GROUP_MAP = {}
    for n in OPALS_UNIVERSAL: GROUP_MAP[n] = "opals_universal"
    for n in OPALS_ARMSWING:  GROUP_MAP[n] = "opals_armswing"
    for n in OPALS_SWAY:      GROUP_MAP[n] = "opals_sway"
    for n in AXIVITY_COLS:    GROUP_MAP[n] = "axivity"
    for n in FLAGS:            GROUP_MAP[n] = "flag"

    for feat in features:
        feat["group"] = GROUP_MAP.get(feat["name"], "unknown")

    # ── Assemble output ───────────────────────────────────────────────────────
    out = {
        "feature_count":        len(feature_cols),
        "feature_cols":         feature_cols,
        "features":             features,
        "preprocessing_notes": {
            "step1_impute":  "Replace NaN with imputer_median for each feature",
            "step2_scale":   "(value - scaler_mean) / scaler_std",
            "missing_flags": "has_armswing=0 if RA_AMP_U missing; has_sway=0 if SW_VEL_OP missing; has_axivity=0 if no Axivity data",
            "arm_swing_note": "RA_AMP_U/LA_AMP_U/SYM_U/ASA_U are arm amplitude in degrees from wrist Opals sensor during walking.",
            "sway_note":     "SW_VEL_OP/PATH/FREQ are sway velocity/path/frequency from lower-back Opals during standing balance test.",
        },
    }

    if severity_thresholds:
        out["severity_thresholds"] = severity_thresholds
        out["severity_notes"] = {
            "applies_to":    "impaired predictions only (binary classifier output = 1)",
            "CVStrideTime":  "Primary driver. Raw (unscaled) value. Higher = worse.",
            "RA_AMP_U":      "Secondary modifier. Raw (unscaled) value in degrees. Lower = worse. If below p10, upgrade severity by 1.",
            "band_logic":    "stride_cv < p33 → base 1; < p66 → base 2; < p90 → base 3; else → base 4. If ra_amp < ra_p10 → min(base+1, 4).",
        }

    # ── Save ──────────────────────────────────────────────────────────────────
    os.makedirs("outputs", exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        json.dump(out, f, indent=2)

    print(f"\n✓ Saved → {OUTPUT_PATH}")
    print(f"\nQuick verification:")
    print(f"  feature_count : {out['feature_count']}")
    for feat in features[:5]:
        print(f"  [{feat['index']:2d}] {feat['name']:20s}  "
              f"median={feat['imputer_median']:8.4f}  "
              f"mean={feat['scaler_mean']:8.4f}  "
              f"std={feat['scaler_std']:8.4f}  "
              f"group={feat['group']}")
    print(f"  ... ({len(features)-5} more features)")
    print(f"\nCopy outputs/scaler_params.json and outputs/gait_classifier.ptl "
          f"into your Flutter assets/ folder.")


if __name__ == "__main__":
    main()
