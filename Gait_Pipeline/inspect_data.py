"""
inspect_data.py — Run this BEFORE training to verify your CSV files
are structured correctly and the merge will succeed.

Usage:
    python inspect_data.py --opals path/to/opals.csv --updrs path/to/updrs3.csv
"""

import argparse
import pandas as pd
import numpy as np

FEATURE_COLS  = ["SW_VEL_OP", "SW_PATH_OP", "SW_FREQ_OP", "CAD_U", "STR_CV_U", "SP_U"]
UPDRS_ITEMS   = ["NP3GAIT", "NP3FRZGT", "NP3PSTBL", "NP3POSTR", "NP3BRADY"]


def inspect(opals_path, updrs_path):
    print("=" * 60)
    print("OPALS FILE")
    print("=" * 60)
    opals = pd.read_csv(opals_path)
    print(f"Shape: {opals.shape}")
    print(f"Columns ({len(opals.columns)}): {list(opals.columns)}\n")

    print("── Feature columns availability ──")
    for col in FEATURE_COLS:
        present = col in opals.columns
        if present:
            n_missing = opals[col].isna().sum()
            print(f"  {'✓' if n_missing == 0 else '!'} {col:15s}  "
                  f"missing: {n_missing}/{len(opals)}  "
                  f"range: [{opals[col].min():.3f}, {opals[col].max():.3f}]")
        else:
            print(f"  ✗ {col:15s}  NOT FOUND")

    print(f"\nVisit column: ", end="")
    if "VISNO" in opals.columns:
        print(f"VISNO — unique values: {sorted(opals['VISNO'].dropna().unique())}")
    elif "EVENT_ID" in opals.columns:
        print(f"EVENT_ID — unique values: {sorted(opals['EVENT_ID'].dropna().unique())}")
    else:
        print("NOT FOUND (expected VISNO or EVENT_ID)")

    print(f"Unique patients (PATNO): {opals['PATNO'].nunique()}")

    print("\n" + "=" * 60)
    print("UPDRS-III FILE")
    print("=" * 60)
    updrs = pd.read_csv(updrs_path)
    print(f"Shape: {updrs.shape}")
    print(f"Columns ({len(updrs.columns)}): {list(updrs.columns)}\n")

    print("── Gait sub-score columns availability ──")
    for col in UPDRS_ITEMS:
        present = col in updrs.columns
        if present:
            n_missing = updrs[col].isna().sum()
            vc = updrs[col].value_counts().sort_index().to_dict()
            print(f"  {'✓' if n_missing == 0 else '!'} {col:12s}  "
                  f"missing: {n_missing}/{len(updrs)}  distribution: {vc}")
        else:
            print(f"  ✗ {col:12s}  NOT FOUND")

    print(f"\nVisit column: ", end="")
    if "EVENT_ID" in updrs.columns:
        print(f"EVENT_ID — unique values: {sorted(updrs['EVENT_ID'].dropna().unique())[:10]}")
    elif "VISNO" in updrs.columns:
        print(f"VISNO — unique values: {sorted(updrs['VISNO'].dropna().unique())[:10]}")
    else:
        print("NOT FOUND")

    print(f"Unique patients (PATNO): {updrs['PATNO'].nunique()}")

    print("\n" + "=" * 60)
    print("MERGE PREVIEW")
    print("=" * 60)
    opals_v = opals.rename(columns={"VISNO": "VISIT"})
    updrs_v = updrs.rename(columns={"EVENT_ID": "VISIT"})

    opals_visits = set(zip(opals_v["PATNO"], opals_v["VISIT"]))
    updrs_visits  = set(zip(updrs_v["PATNO"],  updrs_v["VISIT"]))
    overlap = opals_visits & updrs_visits

    print(f"Opals patient-visits:  {len(opals_visits)}")
    print(f"UPDRS patient-visits:  {len(updrs_visits)}")
    print(f"Overlapping (mergeable): {len(overlap)}")

    if len(overlap) == 0:
        print("\n  ✗ WARNING: No overlapping patient-visits found!")
        print("  Check that PATNO values match and visit codes use the same format.")
        print("  Opals visit samples:  ", list(opals_v["VISIT"].dropna().unique())[:5])
        print("  UPDRS visit samples:  ", list(updrs_v["VISIT"].dropna().unique())[:5])
    else:
        print(f"\n  ✓ Merge will produce ~{len(overlap)} rows — ready to train.")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--opals", required=True)
    parser.add_argument("--updrs", required=True)
    args = parser.parse_args()
    inspect(args.opals, args.updrs)
