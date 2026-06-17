"""
calibrate_severity.py
Run this ONCE before train_gait.py to compute data-driven severity thresholds.

Uses:
  CVStrideTime — primary severity driver (higher = worse)
  RA_AMP_U     — secondary modifier (lower = worse; reduced arm swing = more severe PD)

Outputs:
  outputs/severity_thresholds.json  — loaded automatically by train_gait.py
"""

import os
import sys
import json
import argparse
import importlib.util
import numpy as np
import pandas as pd


def load_train_module():
    spec = importlib.util.spec_from_file_location("train_gait", "train_gait.py")
    mod  = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main(args):
    print("── Loading train_gait.py module ──")
    try:
        tg = load_train_module()
    except Exception as e:
        print(f"ERROR: Could not load train_gait.py: {e}")
        sys.exit(1)

    print("── Building dataset (same as train_gait.py) ──")
    df, all_feats = tg.build_dataset(args.opals, args.axivity, args.updrs)

    if "CVStrideTime" not in df.columns:
        print("ERROR: CVStrideTime not found in merged dataset.")
        sys.exit(1)
    if "RA_AMP_U" not in df.columns:
        print("ERROR: RA_AMP_U not found in merged dataset. "
              "Check that your Opals CSV contains this column.")
        sys.exit(1)

    impaired = df[df["label"] == 1].copy()
    print(f"\n── Calibrating on {len(impaired)} impaired rows ──")

    # ── CVStrideTime percentiles ──────────────────────────────────────────────
    cv = impaired["CVStrideTime"].dropna()
    print(f"\nCVStrideTime (impaired rows):")
    print(f"  count={len(cv)}, min={cv.min():.3f}, median={cv.median():.3f}, "
          f"max={cv.max():.3f}")
    print(f"  p10={np.percentile(cv,10):.3f}  p33={np.percentile(cv,33):.3f}  "
          f"p66={np.percentile(cv,66):.3f}  p90={np.percentile(cv,90):.3f}")

    cv_p33 = float(np.percentile(cv, 33))
    cv_p66 = float(np.percentile(cv, 66))
    cv_p90 = float(np.percentile(cv, 90))

    # ── RA_AMP_U percentiles ──────────────────────────────────────────────────
    # Lower arm amplitude = worse. p10 = markedly reduced → upgrade severity.
    ra = impaired["RA_AMP_U"].dropna()
    print(f"\nRA_AMP_U — right arm amplitude in degrees (impaired rows):")
    print(f"  count={len(ra)}, min={ra.min():.3f}, median={ra.median():.3f}, "
          f"max={ra.max():.3f}")
    print(f"  p10={np.percentile(ra,10):.3f}  p33={np.percentile(ra,33):.3f}  "
          f"p66={np.percentile(ra,66):.3f}  p90={np.percentile(ra,90):.3f}")

    ra_p10 = float(np.percentile(ra, 10))
    ra_p33 = float(np.percentile(ra, 33))
    ra_p66 = float(np.percentile(ra, 66))

    thresholds = {
        "CVStrideTime": {"p33": cv_p33, "p66": cv_p66, "p90": cv_p90},
        "RA_AMP_U":     {"p10": ra_p10, "p33": ra_p33, "p66": ra_p66},
    }

    # ── Simulate severity distribution ───────────────────────────────────────
    print("\n── Simulated severity distribution (impaired rows only) ──")
    tg_thresholds = thresholds

    counts = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
    for _, row in impaired.iterrows():
        cv_val = row["CVStrideTime"] if pd.notna(row["CVStrideTime"]) else cv.median()
        ra_val = row["RA_AMP_U"]     if pd.notna(row["RA_AMP_U"])     else np.nan
        sev    = tg.band_severity(cv_val, ra_val, tg_thresholds)
        counts[sev] += 1

    total = sum(counts.values())
    for s, n in counts.items():
        label = ["normal", "mild", "moderate", "severe", "very severe"][s]
        bar   = "█" * int(30 * n / max(total, 1))
        print(f"  {s} ({label:11s}): {n:3d} ({100*n/max(total,1):4.1f}%) {bar}")

    # ── Save ──────────────────────────────────────────────────────────────────
    os.makedirs("outputs", exist_ok=True)
    out_path = os.path.join("outputs", "severity_thresholds.json")
    with open(out_path, "w") as f:
        json.dump(thresholds, f, indent=2)
    print(f"\n✓ Saved → {out_path}")
    print(f"\nThresholds written:")
    print(json.dumps(thresholds, indent=2))
    print("\nNext step: python train_gait.py --opals ... --axivity ... --updrs ...")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--opals",   required=True)
    parser.add_argument("--axivity", required=True)
    parser.add_argument("--updrs",   required=True)
    args = parser.parse_args()
    main(args)
