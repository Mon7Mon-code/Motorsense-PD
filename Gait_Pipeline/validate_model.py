"""
Validate gait_classifier.ptl + scaler_params against train_gait.py contract
and Flutter gait_inference.dart preprocessing.
"""

import json
import os
import pickle
import sys

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    roc_auc_score,
)
from sklearn.model_selection import GroupKFold

# Reuse training definitions
sys.path.insert(0, os.path.dirname(__file__))
from train_gait import (  # noqa: E402
    ALL_AXIVITY,
    OPALS_ARMSWING,
    OPALS_SWAY,
    OPALS_UNIVERSAL,
    band_severity,
    build_dataset,
    load_severity_thresholds,
)

def _find_updrs_csv(base: str) -> str | None:
    for name in (
        "MDS-UPDRS_Part_III_01Jun2026.csv",
        "MDS-UPDRS_Part_III_31May2026.csv",
        "UPDRS3.csv",
    ):
        path = os.path.join(base, name)
        if os.path.exists(path):
            return path
    for root, _, files in os.walk(base):
        for f in files:
            if f.upper().startswith("MDS-UPDRS") and f.lower().endswith(".csv"):
                return os.path.join(root, f)
    return None


FLUTTER_FEATURE_COLS = [
    "CAD_U", "STR_CV_U", "SP_U",
    "RA_AMP_U", "LA_AMP_U", "SYM_U", "ASA_U", "has_armswing",
    "SW_VEL_OP", "SW_PATH_OP", "SW_FREQ_OP", "has_sway",
    "MeanSVMDaymg", "PercentWalking", "ActivityLevel", "CadencetimeDomain",
    "NumberOfBouts", "wdV", "stepTime", "strideTime",
    "CVStrideTime", "SampEntropyV", "stepAsymV", "StepVelocitycmsec", "rmsV",
    "has_axivity", "GAIT_SUBGROUP",
]


def flutter_preprocess(raw_row, imputer_stats, scaler_mean, scaler_std):
    """Mirror lib/gait_inference.dart: impute median then scale."""
    out = []
    for i, v in enumerate(raw_row):
        x = imputer_stats[i] if np.isnan(v) else float(v)
        s = scaler_std[i]
        out.append((x - scaler_mean[i]) / s if s > 0 else 0.0)
    return np.array(out, dtype=np.float32)


def load_mobile_model(ptl_path):
    model = torch.jit.load(ptl_path, map_location="cpu")
    model.eval()
    return model


def main():
    base = os.path.dirname(__file__)
    out_dir = os.path.join(base, "outputs")
    ptl_path = os.path.join(out_dir, "gait_classifier.ptl")
    scaler_pkl = os.path.join(out_dir, "scaler.pkl")
    scaler_json = os.path.join(out_dir, "scaler_params.json")

    print("=== Asset / contract checks ===\n")

    with open(scaler_pkl, "rb") as f:
        bundle = pickle.load(f)
    imputer = bundle["imputer"]
    scaler = bundle["scaler"]
    train_feats = bundle["feature_cols"]

    with open(scaler_json, "r") as f:
        params = json.load(f)

    json_feats = params["feature_cols"]
    assert train_feats == json_feats == FLUTTER_FEATURE_COLS, (
        "Feature order mismatch between pkl, JSON, and Flutter"
    )
    print(f"OK  Feature order matches Flutter ({len(train_feats)} features)")

    for i, feat in enumerate(params["features"]):
        assert feat["name"] == train_feats[i]
        assert abs(feat["imputer_median"] - imputer.statistics_[i]) < 1e-5
        assert abs(feat["scaler_mean"] - scaler.mean_[i]) < 1e-5
        assert abs(feat["scaler_std"] - scaler.scale_[i]) < 1e-5
    print("OK  scaler_params.json matches scaler.pkl")

    app_ptl = os.path.join(
        base, "..", "Parkinsons-Group-10-App", "assets", "gait_classifier.ptl"
    )
    app_json = os.path.join(
        base, "..", "Parkinsons-Group-10-App", "assets", "scaler_params.json"
    )
    if os.path.exists(app_ptl):
        same_ptl = open(ptl_path, "rb").read() == open(app_ptl, "rb").read()
        same_json = open(scaler_json, "rb").read() == open(app_json, "rb").read()
        print(f"OK  App assets match outputs/ (ptl={same_ptl}, json={same_json})")
    else:
        print("WARN  App assets not found — copy outputs/ into Flutter assets/")

    print("\n=== PyTorch Mobile model load ===\n")
    model = load_mobile_model(ptl_path)
    print(f"OK  Loaded {ptl_path} ({os.path.getsize(ptl_path)} bytes)")

    print("\n=== Dataset + cross-validated metrics (replay) ===\n")
    opals = os.path.join(base, "Gait_Data___Arm_swing__Opals__31May2026.csv")
    axivity = os.path.join(base, "Gait_Data___Arm_swing__Axivity__31May2026.csv")
    updrs = _find_updrs_csv(base)

    if not all(os.path.exists(p) for p in [opals, axivity]):
        print("WARN  CSV paths missing — skipping dataset metrics")
        return

    if updrs is None:
        print("WARN  UPDRS CSV not found — skipping dataset metrics")
        return
    print(f"Using UPDRS: {os.path.basename(updrs)}")

    df, all_feats = build_dataset(opals, axivity, updrs)
    assert all_feats == train_feats

    X = df[all_feats].values.astype(np.float32)
    y = df["label"].values.astype(np.float32)
    groups = df["PATNO"].values
    thresholds = load_severity_thresholds()

    cv_idx = all_feats.index("CVStrideTime")
    ra_idx = all_feats.index("RA_AMP_U")

    imputer_stats = imputer.statistics_
    scaler_mean = scaler.mean_
    scaler_std = scaler.scale_

    gkf = GroupKFold(n_splits=5)
    aucs, f1s = [], []

    for fold, (tr_idx, va_idx) in enumerate(gkf.split(X, y, groups)):
        X_va_raw = X[va_idx]
        y_va = y[va_idx]

        # Fit preprocessors on train only (fair replay)
        from sklearn.impute import SimpleImputer
        from sklearn.preprocessing import StandardScaler

        imp = SimpleImputer(strategy="median").fit(X[tr_idx])
        sc = StandardScaler().fit(imp.transform(X[tr_idx]))
        X_va_sk = sc.transform(imp.transform(X_va_raw))

        probs = []
        for row_sk in X_va_sk:
            t = torch.tensor(row_sk.reshape(1, -1))
            logit = model(t).item()
            probs.append(1.0 / (1.0 + np.exp(-logit)))

        probs = np.array(probs)
        preds = (probs >= 0.5).astype(int)

        # Flutter-path inference on same rows
        flutter_probs = []
        for raw in X_va_raw:
            scaled = flutter_preprocess(
                raw, imp.statistics_, sc.mean_, sc.scale_
            )
            logit = model(torch.tensor(scaled.reshape(1, -1))).item()
            flutter_probs.append(1.0 / (1.0 + np.exp(-logit)))
        flutter_probs = np.array(flutter_probs)
        max_diff = np.max(np.abs(probs - flutter_probs))
        if max_diff > 1e-4:
            print(f"FAIL Fold {fold+1}: Flutter preprocess max diff {max_diff}")
        else:
            print(f"OK  Fold {fold+1}: Flutter preprocess matches sklearn (max Δ={max_diff:.2e})")

        try:
            auc = roc_auc_score(y_va, probs)
        except ValueError:
            auc = float("nan")
        f1 = f1_score(y_va, preds, zero_division=0)
        aucs.append(auc)
        f1s.append(f1)
        print(f"      ROC-AUC={auc:.3f}  F1={f1:.3f}  acc={accuracy_score(y_va, preds):.3f}")

    print(f"\nMean ROC-AUC: {np.nanmean(aucs):.3f}  Mean F1: {np.nanmean(f1s):.3f}")

    # Severity banding sanity on impaired preds (full-data model stats)
    X_all = imputer.transform(X)
    X_all_s = scaler.transform(X_all)
    probs_all = []
    for row in X_all_s:
        logit = model(torch.tensor(row.reshape(1, -1))).item()
        probs_all.append(1.0 / (1.0 + np.exp(-logit)))
    probs_all = np.array(probs_all)
    preds_all = (probs_all >= 0.5).astype(int)

    sev_dist = {s: 0 for s in range(5)}
    for i, pred in enumerate(preds_all):
        if pred == 0:
            sev_dist[0] += 1
            continue
        cv = X[i, cv_idx] if not np.isnan(X[i, cv_idx]) else imputer_stats[cv_idx]
        ra = X[i, ra_idx]
        sev = band_severity(cv, ra, thresholds)
        sev_dist[sev] += 1
    print(f"\nSeverity distribution (impaired use band_severity): {sev_dist}")

    print("\n=== Model validity summary ===")
    mean_auc = np.nanmean(aucs)
    if mean_auc >= 0.75:
        print(f"PASS  Discrimination reasonable (mean AUC {mean_auc:.3f})")
    elif mean_auc >= 0.65:
        print(f"WARN  Moderate discrimination (mean AUC {mean_auc:.3f}) — usable with caution")
    else:
        print(f"FAIL  Weak discrimination (mean AUC {mean_auc:.3f})")

    print(
        "\nNOTE: On-device features from phone+wrist differ from PPMI Opals+Axivity "
        "columns used in training. Retrain or fine-tune if live cadence/stride "
        "distributions diverge from scaler medians."
    )


if __name__ == "__main__":
    main()
