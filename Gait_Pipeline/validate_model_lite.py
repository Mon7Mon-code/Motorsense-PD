"""Lightweight validation when UPDRS CSV is not on disk."""

import json
import os
import pickle

import numpy as np
import torch

PTL = os.path.join("outputs", "gait_classifier.ptl")
PKL = os.path.join("outputs", "scaler.pkl")
JSON_PATH = os.path.join("outputs", "scaler_params.json")

FLUTTER_COLS = [
    "CAD_U", "STR_CV_U", "SP_U",
    "RA_AMP_U", "LA_AMP_U", "SYM_U", "ASA_U", "has_armswing",
    "SW_VEL_OP", "SW_PATH_OP", "SW_FREQ_OP", "has_sway",
    "MeanSVMDaymg", "PercentWalking", "ActivityLevel", "CadencetimeDomain",
    "NumberOfBouts", "wdV", "stepTime", "strideTime",
    "CVStrideTime", "SampEntropyV", "stepAsymV", "StepVelocitycmsec", "rmsV",
    "has_axivity", "GAIT_SUBGROUP",
]


def flutter_scale(raw, medians, means, stds):
    out = []
    for i, v in enumerate(raw):
        x = medians[i] if np.isnan(v) else float(v)
        s = stds[i]
        out.append((x - means[i]) / s if s > 0 else 0.0)
    return np.array(out, dtype=np.float32)


def main():
    with open(PKL, "rb") as f:
        b = pickle.load(f)
    imputer, scaler, cols = b["imputer"], b["scaler"], b["feature_cols"]
    assert cols == FLUTTER_COLS

    with open(JSON_PATH) as f:
        j = json.load(f)
    assert j["feature_cols"] == cols

    model = torch.jit.load(PTL, map_location="cpu")
    model.eval()

    # Median imputed row → should be near decision boundary region
    raw_median = imputer.statistics_.astype(np.float32)
    sk = scaler.transform(imputer.transform(raw_median.reshape(1, -1)))[0]
    fl = flutter_scale(raw_median, imputer.statistics_, scaler.mean_, scaler.scale_)

    assert np.allclose(sk, fl, atol=1e-5), f"preprocess mismatch max={np.max(np.abs(sk-fl))}"
    print("OK  Flutter-style preprocess matches sklearn")

    for name, row in [("median", raw_median), ("zeros", np.zeros_like(raw_median))]:
        sk_row = scaler.transform(imputer.transform(row.reshape(1, -1)))[0]
        logit = model(torch.tensor(sk_row.reshape(1, -1))).item()
        prob = 1 / (1 + np.exp(-logit))
        print(f"  {name:8s} -> prob={prob:.4f}  logit={logit:.4f}")

    # Output shape / no NaN on batch
    batch = torch.tensor(np.stack([sk, fl]))
    out = model(batch)
    assert out.shape == (2,), out.shape
    assert not torch.isnan(out).any()
    print("OK  Model forward pass stable")

    print(f"\nOK  {PTL} valid for {len(cols)}-feature input")
    print("Copy outputs/* to Flutter assets/ (already synced if sizes match).")


if __name__ == "__main__":
    os.chdir(os.path.dirname(__file__))
    main()
