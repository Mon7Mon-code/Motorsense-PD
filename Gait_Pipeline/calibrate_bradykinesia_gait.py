"""
calibrate_bradykinesia_gait.py

Builds reference thresholds for on-device Bradykinesia Gait Severity (0-4)
from the same PPMI merge used in train_gait.py.

Metrics (lower = worse bradykinesia / more severe):
  - walking_speed_cm_s   StepVelocitycmsec or SP_U * 100
  - stride_length_m      SP_U * 60 / CAD_U  (or Axivity CVSteplength if present)
  - arm_swing_amp_deg    mean(RA_AMP_U, LA_AMP_U)
  - arm_swing_vel_deg_s  RA_AMP_U proxy on PPMI (no wrist gyro in tables);
                         on-device use gyrZ RMS instead

Outputs: outputs/bradykinesia_gait_thresholds.json
"""

import json
import os
import sys
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from train_gait import build_dataset  # noqa: E402

METRICS = [
    "walking_speed_cm_s",
    "stride_length_m",
    "arm_swing_amp_deg",
    "arm_swing_vel_deg_s",
]


def _col(df, name):
    return pd.to_numeric(df[name], errors="coerce") if name in df.columns else pd.Series(np.nan, index=df.index)


def build_metric_frame(df: pd.DataFrame) -> pd.DataFrame:
    """Derive the four bradykinesia gait metrics per merged row."""
    sp = _col(df, "SP_U")
    cad = _col(df, "CAD_U")
    step_vel = _col(df, "StepVelocitycmsec")
    ra = _col(df, "RA_AMP_U")
    la = _col(df, "LA_AMP_U")

    speed = step_vel.where(step_vel.notna(), sp * 100.0)
    stride = sp * 60.0 / cad.replace(0, np.nan)

    # Axivity step-length CV is not stride length; prefer kinematic estimate above.
    if "CVSteplength" in df.columns:
        cv_len = _col(df, "CVSteplength")
        # only use where stride estimate missing
        stride = stride.where(stride.notna(), cv_len)

    amp = pd.concat([ra, la], axis=1).mean(axis=1)
    # PPMI tables lack arm angular velocity — amplitude proxy for calibration.
    vel_proxy = ra

    out = pd.DataFrame(
        {
            "walking_speed_cm_s": speed,
            "stride_length_m": stride,
            "arm_swing_amp_deg": amp,
            "arm_swing_vel_deg_s": vel_proxy,
        },
        index=df.index,
    )
    if "NP3BRADY" in df.columns:
        out["NP3BRADY"] = _col(df, "NP3BRADY")
    if "label" in df.columns:
        out["label"] = df["label"]
    return out


def percentile_thresholds(series: pd.Series, higher_is_better: bool) -> dict:
    """Return p20/p40/p60/p80 for banding into severity 1-4 (0 = best)."""
    s = series.dropna()
    if len(s) < 10:
        return {"p20": None, "p40": None, "p60": None, "p80": None}
    ps = {
        "p20": float(np.percentile(s, 20)),
        "p40": float(np.percentile(s, 40)),
        "p60": float(np.percentile(s, 60)),
        "p80": float(np.percentile(s, 80)),
    }
    return ps | {"higher_is_better": higher_is_better}


def main():
    base = os.path.dirname(__file__)
    opals = os.path.join(base, "Gait_Data___Arm_swing__Opals__31May2026.csv")
    axivity = os.path.join(base, "Gait_Data___Arm_swing__Axivity__31May2026.csv")
    updrs = os.path.join(base, "MDS-UPDRS_Part_III_01Jun2026.csv")

    print("Building PPMI merge...")
    df, _ = build_dataset(opals, axivity, updrs)
    m = build_metric_frame(df)

  # Reference: unimpaired rows (label==0) for "good" movement; impaired for validation
    normal = m[df["label"] == 0]
    impaired = m[df["label"] == 1]

    thresholds = {}
    for name in METRICS:
        thresholds[name] = percentile_thresholds(normal[name], higher_is_better=True)

    # Spearman vs NP3BRADY when available
    correlations = {}
    if "NP3BRADY" in m.columns:
        brady = m["NP3BRADY"].dropna()
        for name in METRICS:
            aligned = m[[name, "NP3BRADY"]].dropna()
            if len(aligned) > 20:
                r = aligned[name].corr(aligned["NP3BRADY"], method="spearman")
                correlations[name] = round(float(r), 3) if not np.isnan(r) else None

    out = {
        "version": 1,
        "description": (
            "Bradykinesia gait severity 0-4 from walking speed, stride length, "
            "arm swing amplitude and velocity. Bands use normal (label=0) PPMI "
            "percentiles; lower speed/shorter stride/smaller arm motion = worse."
        ),
        "metrics": METRICS,
        "thresholds": thresholds,
        "correlations_with_NP3BRADY": correlations,
        "reference_counts": {
            "normal_rows": int(len(normal)),
            "impaired_rows": int(len(impaired)),
            "total_rows": int(len(m)),
        },
        "notes": {
            "walking_speed_cm_s": "StepVelocitycmsec or SP_U*100",
            "stride_length_m": "SP_U*60/CAD_U (metres)",
            "arm_swing_amp_deg": "mean(RA_AMP_U, LA_AMP_U) degrees",
            "arm_swing_vel_deg_s": "PPMI: RA_AMP_U proxy; device: wrist gyrZ RMS deg/s",
        },
    }

    out_path = os.path.join(base, "outputs", "bradykinesia_gait_thresholds.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(out, f, indent=2)

    print(f"Saved -> {out_path}")
    print("NP3BRADY Spearman:", correlations)
    for name in METRICS:
        t = thresholds[name]
        print(f"  {name}: p20={t['p20']:.3f} p80={t['p80']:.3f}" if t["p20"] else f"  {name}: insufficient data")


if __name__ == "__main__":
    main()
