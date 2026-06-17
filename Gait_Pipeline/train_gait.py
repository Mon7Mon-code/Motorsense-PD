"""
Gait Impairment Classifier — Training Pipeline v7
Sensor fusion: Opals (wrist) + Axivity (trunk/hip, free-living)
UPDRS matching: closest-date per patient, 6-month window

Feature strategy (27 features):
  - Universal Opals (low missingness):  CAD_U, STR_CV_U, SP_U           [3]
  - Arm-swing Opals (real arm swing):   RA_AMP_U, LA_AMP_U, SYM_U, ASA_U
                                        + has_armswing flag              [5]
  - Sway Opals (standing balance):      SW_VEL_OP, SW_PATH_OP, SW_FREQ_OP
                                        + has_sway flag                  [4]
  - Axivity free-living activity:       MeanSVMDaymg, PercentWalking,
                                        ActivityLevel, CadencetimeDomain,
                                        NumberOfBouts, wdV, stepTime,
                                        strideTime                       [8]
  - Axivity gait quality:               CVStrideTime, SampEntropyV,
                                        stepAsymV, StepVelocitycmsec,
                                        rmsV                             [5]
  - Flags + protocol:                   has_axivity, GAIT_SUBGROUP       [2]
Total: 27 features

Changes from v6:
  - FIXED: SW_VEL_OP/PATH/FREQ were mislabelled as arm-swing; they are
    SWAY features from standing balance tests (Opals lower-back).
    Renamed group to OPALS_SWAY with its own has_sway flag.
  - ADDED: Real arm-swing features RA_AMP_U, LA_AMP_U, SYM_U, ASA_U
    (arm amplitude in degrees, symmetry, asymmetry) — much lower
    missingness (9%) vs old SW_ group (37%).
  - FIXED: band_severity() now uses CVStrideTime (primary) +
    RA_AMP_U (secondary) with correct directionality:
      CVStrideTime higher = worse
      RA_AMP_U lower = worse (reduced arm swing = more severe PD)
  - Feature count updated from 22 → 27.
"""

import os
import glob
import json
import argparse
import pickle
import numpy as np
import pandas as pd

import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader, WeightedRandomSampler
from sklearn.preprocessing import StandardScaler
from sklearn.impute import SimpleImputer
from sklearn.metrics import roc_auc_score, f1_score
from sklearn.model_selection import GroupKFold

SEED = 42
torch.manual_seed(SEED)
np.random.seed(SEED)

# ── Feature groups ────────────────────────────────────────────────────────────
OPALS_UNIVERSAL = ["CAD_U", "STR_CV_U", "SP_U"]

# Real arm-swing during walking (wrist/arm Opals sensor)
OPALS_ARMSWING  = ["RA_AMP_U", "LA_AMP_U", "SYM_U", "ASA_U"]

# Postural sway during standing balance test (lower-back Opals sensor)
# NOTE: SW_VEL_OP is sway VELOCITY (m/s), NOT arm-swing velocity.
#       Higher sway = worse balance = more severe PD.
OPALS_SWAY      = ["SW_VEL_OP", "SW_PATH_OP", "SW_FREQ_OP"]

AXIVITY_ACTIVITY = [
    "MeanSVMDaymg",
    "PercentWalking",
    "ActivityLevel",
    "CadencetimeDomain",
    "NumberOfBouts",
    "wdV",
    "stepTime",
    "strideTime",
]

AXIVITY_GAIT = [
    "CVStrideTime",
    "SampEntropyV",
    "stepAsymV",
    "StepVelocitycmsec",
    "rmsV",
]

ALL_AXIVITY = AXIVITY_ACTIVITY + AXIVITY_GAIT

UPDRS_GAIT_ITEMS     = ["NP3GAIT", "NP3FRZGT", "NP3PSTBL", "NP3POSTR", "NP3BRADY"]
PPMI_MISSING_CODE    = 101.0
IMPAIRMENT_THRESHOLD = 2
DATE_WINDOW_MONTHS   = 6
N_FOLDS              = 5

THRESHOLDS_PATH = os.path.join("outputs", "severity_thresholds.json")


# ── Severity thresholds ───────────────────────────────────────────────────────
def load_severity_thresholds():
    """
    Load calibrated thresholds from outputs/severity_thresholds.json.
    Falls back to heuristics if file not present.
    Run calibrate_severity.py once to generate the calibrated file.
    """
    if os.path.exists(THRESHOLDS_PATH):
        with open(THRESHOLDS_PATH, "r") as f:
            t = json.load(f)
        print(f"  Loaded calibrated severity thresholds from {THRESHOLDS_PATH}")
        return t
    else:
        print(f"  [warn] {THRESHOLDS_PATH} not found — using heuristic thresholds.")
        print("  Run calibrate_severity.py to generate data-driven thresholds.")
        return {
            "CVStrideTime": {"p33": 5.0,  "p66": 10.0, "p90": 20.0},
            "RA_AMP_U":     {"p10": 5.0,  "p33": 15.0, "p66": 25.0},
        }


def band_severity(stride_cv, arm_amp, thresholds):
    """
    Severity banding applied AFTER the binary classifier predicts impaired.

    Inputs must be RAW (unscaled) feature values:
      stride_cv = CVStrideTime   — higher is worse (more stride variability)
      arm_amp   = RA_AMP_U       — lower is worse (reduced arm swing amplitude)
                  Pass NaN / use imputed median if not available.

    Returns:
      0 = normal (caller should not invoke for normal predictions)
      1 = mild
      2 = moderate
      3 = severe
      4 = very severe

    Logic:
      Primary driver: CVStrideTime percentile bands (p33/p66/p90)
      Secondary modifier: RA_AMP_U can upgrade severity by 1 step
        if arm swing is markedly reduced (below p10 threshold).
    """
    cv = thresholds["CVStrideTime"]
    ra = thresholds["RA_AMP_U"]

    # Primary banding on stride variability
    if   stride_cv < cv["p33"]: base = 1
    elif stride_cv < cv["p66"]: base = 2
    elif stride_cv < cv["p90"]: base = 3
    else:                       base = 4

    # Secondary modifier: markedly reduced arm swing → upgrade severity by 1
    if not np.isnan(arm_amp) and arm_amp < ra["p10"]:
        base = min(base + 1, 4)

    return base


# ── Loaders ───────────────────────────────────────────────────────────────────
def load_csv(path, label, **kwargs):
    if os.path.isdir(path):
        files = glob.glob(os.path.join(path, "*.csv"))
        df = pd.concat([pd.read_csv(f, **kwargs) for f in files], ignore_index=True)
    else:
        df = pd.read_csv(path, **kwargs)
    print(f"  {label}: {len(df)} rows, {df.shape[1]} cols")
    return df


# ── Dataset builder ───────────────────────────────────────────────────────────
def build_dataset(opals_path, axivity_path, updrs_path):
    print("\n── Loading data ──")
    opals   = load_csv(opals_path,   "Opals  (wrist)")
    axivity = load_csv(axivity_path, "Axivity (trunk)").copy()   # .copy() prevents PerformanceWarning
    updrs   = load_csv(updrs_path,   "UPDRS-III", low_memory=False)

    # ── UPDRS: clean, filter ON-state, drop corrupt dates ────────────────────
    avail_items = [c for c in UPDRS_GAIT_ITEMS if c in updrs.columns]
    pdstate_col = "PDSTATE" if "PDSTATE" in updrs.columns else None

    updrs_c = updrs[["PATNO", "INFODT"] + avail_items +
                    ([pdstate_col] if pdstate_col else [])].copy()
    for col in avail_items:
        updrs_c[col] = pd.to_numeric(updrs_c[col], errors="coerce").replace(PPMI_MISSING_CODE, np.nan)

    if pdstate_col:
        before = len(updrs_c)
        updrs_c = updrs_c[updrs_c[pdstate_col].isin(["OFF"]) | updrs_c[pdstate_col].isna()]
        print(f"  Filtered ON-state: {before} → {len(updrs_c)} UPDRS rows kept")
        updrs_c = updrs_c.drop(columns=[pdstate_col])

    updrs_c = updrs_c.dropna(subset=avail_items, how="all")
    updrs_c["DATE_UP"] = pd.to_datetime(updrs_c["INFODT"], format="%m/%Y", errors="coerce")
    updrs_c = updrs_c[updrs_c["DATE_UP"].notna() & (updrs_c["DATE_UP"].dt.year >= 2000)]
    print(f"  UPDRS rows after sanity filter: {len(updrs_c)}")

    # ── Opals: parse dates, pull all feature groups ───────────────────────────
    opals["DATE_OP"] = pd.to_datetime(opals["INFODT"], format="%m/%Y", errors="coerce")
    opals_sub = opals[opals["DATE_OP"].notna()].copy()

    actual_univ = [c for c in OPALS_UNIVERSAL if c in opals.columns]
    actual_sw   = [c for c in OPALS_ARMSWING  if c in opals.columns]
    actual_sway = [c for c in OPALS_SWAY      if c in opals.columns]
    has_subgrp  = "GAIT_SUBGROUP" in opals.columns

    # ── Closest-date UPDRS match ──────────────────────────────────────────────
    print(f"  Matching {len(opals_sub)} Opals rows → closest UPDRS "
          f"(±{DATE_WINDOW_MONTHS} months) ...")
    updrs_by_pat = {p: g.reset_index(drop=True) for p, g in updrs_c.groupby("PATNO")}

    records = []
    for _, op in opals_sub.iterrows():
        pat_u = updrs_by_pat.get(op["PATNO"])
        if pat_u is None:
            continue
        diffs = (pat_u["DATE_UP"] - op["DATE_OP"]).abs().dt.days
        idx   = diffs.idxmin()
        if diffs[idx] / 30.0 > DATE_WINDOW_MONTHS:
            continue
        row = {"PATNO": op["PATNO"], "DATE_OP": op["DATE_OP"]}

        # Universal gait features
        for c in actual_univ:
            row[c] = op[c]

        # Real arm-swing features (RA_AMP_U etc.)
        for c in actual_sw:
            row[c] = op.get(c, np.nan)
        row["has_armswing"] = (
            0.0 if (not actual_sw or pd.isna(op.get(actual_sw[0], np.nan))) else 1.0
        )

        # Sway features (SW_VEL_OP etc.) — standing balance, NOT arm swing
        for c in actual_sway:
            row[c] = op.get(c, np.nan)
        row["has_sway"] = (
            0.0 if (not actual_sway or pd.isna(op.get(actual_sway[0], np.nan))) else 1.0
        )

        row["GAIT_SUBGROUP"] = (
            float(op["GAIT_SUBGROUP"])
            if has_subgrp and pd.notna(op["GAIT_SUBGROUP"]) else 0.0
        )
        for c in avail_items:
            row[c] = pat_u.loc[idx, c]
        records.append(row)

    merged = pd.DataFrame(records)
    print(f"  After closest-date match: {len(merged)} rows "
          f"(all within {DATE_WINDOW_MONTHS} mo)")

    # ── Left-join Axivity (closest date, 18-month window) ────────────────────
    actual_axiv = [c for c in ALL_AXIVITY if c in axivity.columns]
    axivity["DATE_AX"] = pd.to_datetime(axivity["StartTime"], format="%m/%Y", errors="coerce")
    axiv_by_pat = {p: g.reset_index(drop=True) for p, g in axivity.groupby("PATNO")}

    axiv_rows = []
    for _, row in merged.iterrows():
        pat_ax = axiv_by_pat.get(row["PATNO"])
        if pat_ax is None:
            axiv_rows.append({c: np.nan for c in actual_axiv} | {"has_axivity": 0.0})
            continue
        valid = pat_ax.dropna(subset=["DATE_AX"])
        if valid.empty:
            axiv_rows.append({c: np.nan for c in actual_axiv} | {"has_axivity": 0.0})
            continue
        diffs = (valid["DATE_AX"] - row["DATE_OP"]).abs().dt.days
        idx   = diffs.idxmin()
        if diffs[idx] / 30.0 > 18:
            axiv_rows.append({c: np.nan for c in actual_axiv} | {"has_axivity": 0.0})
        else:
            axiv_rows.append({c: valid.loc[idx, c] for c in actual_axiv} | {"has_axivity": 1.0})

    axiv_df = pd.DataFrame(axiv_rows, index=merged.index)
    merged  = pd.concat([merged, axiv_df], axis=1)

    n_ax = int(merged["has_axivity"].sum())
    print(f"  Axivity coverage: {n_ax}/{len(merged)} rows have trunk data")

    # ── Labels ────────────────────────────────────────────────────────────────
    for col in avail_items:
        merged[col] = pd.to_numeric(merged[col], errors="coerce")
    merged["gait_score_sum"] = merged[avail_items].fillna(0).sum(axis=1)
    merged["label"]          = (merged["gait_score_sum"] >= IMPAIRMENT_THRESHOLD).astype(int)
    merged = merged.dropna(subset=actual_univ, how="all")

    pos = merged["label"].sum()
    neg = len(merged) - pos
    print(f"\n  Final dataset: {len(merged)} rows | "
          f"impaired: {pos} ({100*pos/len(merged):.1f}%)  "
          f"normal: {neg} ({100*neg/len(merged):.1f}%)")

    # 27-feature list in canonical order
    all_feats = (
        actual_univ
        + actual_sw   + ["has_armswing"]
        + actual_sway + ["has_sway"]
        + actual_axiv + ["has_axivity"]
        + ["GAIT_SUBGROUP"]
    )

    print(f"\n  Features ({len(all_feats)}): {all_feats}")
    print("  Missingness:")
    for col in all_feats:
        if col not in merged.columns:
            print(f"    {col:25s}: MISSING FROM DATA")
            continue
        n = merged[col].isna().sum()
        if n > 0:
            bar = "█" * int(20 * n / len(merged))
            print(f"    {col:25s}: {n:3d} ({100*n/len(merged):4.1f}%) {bar}")

    return merged, all_feats


# ── PyTorch dataset + model ───────────────────────────────────────────────────
class GaitDataset(Dataset):
    def __init__(self, X, y):
        self.X = torch.tensor(X, dtype=torch.float32)
        self.y = torch.tensor(y, dtype=torch.float32)
    def __len__(self): return len(self.y)
    def __getitem__(self, i): return self.X[i], self.y[i]


class GaitMLP(nn.Module):
    def __init__(self, input_dim, hidden_dim=64, dropout=0.3):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.BatchNorm1d(hidden_dim), nn.ReLU(), nn.Dropout(dropout),
            nn.Linear(hidden_dim, hidden_dim),
            nn.BatchNorm1d(hidden_dim), nn.ReLU(), nn.Dropout(dropout),
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.ReLU(),
            nn.Linear(hidden_dim // 2, 1),
        )
    def forward(self, x): return self.net(x).squeeze(-1)


# ── Training helpers ──────────────────────────────────────────────────────────
def train_epoch(model, loader, criterion, optimizer, device):
    model.train()
    total_loss = correct = total = 0
    for X, y in loader:
        X, y = X.to(device), y.to(device)
        optimizer.zero_grad()
        logits = model(X)
        loss   = criterion(logits, y)
        loss.backward()
        optimizer.step()
        total_loss += loss.item() * len(y)
        correct    += ((torch.sigmoid(logits) >= 0.5).float() == y).sum().item()
        total      += len(y)
    return total_loss / total, correct / total


@torch.no_grad()
def eval_epoch(model, loader, criterion, device):
    model.eval()
    total_loss = correct = total = 0
    all_probs, all_labels = [], []
    for X, y in loader:
        X, y = X.to(device), y.to(device)
        logits = model(X)
        loss   = criterion(logits, y)
        total_loss += loss.item() * len(y)
        probs = torch.sigmoid(logits)
        correct += ((probs >= 0.5).float() == y).sum().item()
        total   += len(y)
        all_probs.extend(probs.cpu().numpy())
        all_labels.extend(y.cpu().numpy())
    return total_loss / total, correct / total, np.array(all_probs), np.array(all_labels)


def train_model(X_tr, y_tr, X_va, y_va, input_dim, args, device, pw_val):
    train_ds = GaitDataset(X_tr, y_tr)
    val_ds   = GaitDataset(X_va, y_va)
    weights  = 1.0 / np.bincount(y_tr.astype(int))[y_tr.astype(int)]
    sampler  = WeightedRandomSampler(weights, len(weights), replacement=True)

    train_loader = DataLoader(train_ds, batch_size=args.batch_size, sampler=sampler)
    val_loader   = DataLoader(val_ds,   batch_size=args.batch_size, shuffle=False)

    model     = GaitMLP(input_dim, hidden_dim=64, dropout=0.3).to(device)
    criterion = nn.BCEWithLogitsLoss(
        pos_weight=torch.tensor([pw_val], dtype=torch.float32).to(device)
    )
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode="min", patience=10, factor=0.5
    )

    best_loss, best_state, patience_ctr = float("inf"), None, 0
    for epoch in range(1, args.epochs + 1):
        train_epoch(model, train_loader, criterion, optimizer, device)
        va_loss, *_ = eval_epoch(model, val_loader, criterion, device)
        scheduler.step(va_loss)
        if va_loss < best_loss - 1e-4:
            best_loss    = va_loss
            best_state   = {k: v.clone() for k, v in model.state_dict().items()}
            patience_ctr = 0
        else:
            patience_ctr += 1
            if patience_ctr >= args.patience:
                break

    model.load_state_dict(best_state)
    return model, criterion


# ── Mobile export ─────────────────────────────────────────────────────────────
def export_to_mobile(model, input_dim, output_path):
    model.eval().cpu()
    example = torch.rand(1, input_dim)
    traced  = torch.jit.trace(model, example)
    try:
        from torch.utils.mobile_optimizer import optimize_for_mobile
        optimize_for_mobile(traced)._save_for_lite_interpreter(output_path)
    except Exception as e:
        ts_path = output_path.replace(".ptl", ".pt")
        traced.save(ts_path)
        print(f"  [warn] Lite interpreter failed ({e}), saved as {ts_path}")
        return
    print(f"  Exported PyTorch Mobile → {output_path}")


# ── Main ──────────────────────────────────────────────────────────────────────
def main(args):
    os.makedirs(args.output_dir, exist_ok=True)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"\nDevice: {device}")

    severity_thresholds = load_severity_thresholds()

    df, all_feats = build_dataset(args.opals, args.axivity, args.updrs)

    # Indices for raw-feature severity banding (pre-scaling)
    cv_idx = all_feats.index("CVStrideTime") if "CVStrideTime" in all_feats else None
    ra_idx = all_feats.index("RA_AMP_U")     if "RA_AMP_U"     in all_feats else None

    X      = df[all_feats].values.astype(np.float32)
    y      = df["label"].values.astype(np.float32)
    groups = df["PATNO"].values

    gkf          = GroupKFold(n_splits=N_FOLDS)
    fold_results = []

    print(f"\n── {N_FOLDS}-Fold Cross-Validation ──")
    for fold, (tr_idx, va_idx) in enumerate(gkf.split(X, y, groups)):
        X_tr_raw, y_tr = X[tr_idx], y[tr_idx]
        X_va_raw, y_va = X[va_idx], y[va_idx]

        imputer = SimpleImputer(strategy="median")
        X_tr    = imputer.fit_transform(X_tr_raw)
        X_va    = imputer.transform(X_va_raw)

        scaler = StandardScaler()
        X_tr   = scaler.fit_transform(X_tr)
        X_va   = scaler.transform(X_va)

        cc = np.bincount(y_tr.astype(int))
        pw = cc[0] / max(cc[1], 1)

        model, criterion = train_model(
            X_tr, y_tr, X_va, y_va,
            input_dim=len(all_feats), args=args, device=device, pw_val=pw
        )
        _, _, y_prob, y_true = eval_epoch(
            model,
            DataLoader(GaitDataset(X_va, y_va), batch_size=args.batch_size),
            criterion, device
        )
        y_pred = (y_prob >= 0.5).astype(int)

        # ── Apply band_severity() to impaired predictions ─────────────────────
        # Uses RAW (pre-impute, pre-scale) val feature values
        severities = []
        for i, (pred, raw_row) in enumerate(zip(y_pred, X_va_raw)):
            if pred == 1:
                cv_val = (
                    float(raw_row[cv_idx])
                    if cv_idx is not None and not np.isnan(raw_row[cv_idx])
                    else float(imputer.statistics_[cv_idx])
                )
                ra_val = (
                    float(raw_row[ra_idx])
                    if ra_idx is not None and not np.isnan(raw_row[ra_idx])
                    else np.nan
                )
                sev = band_severity(cv_val, ra_val, severity_thresholds)
            else:
                sev = 0
            severities.append(sev)

        severities = np.array(severities)
        sev_dist   = {s: int((severities == s).sum()) for s in range(5)}

        try:    auc = roc_auc_score(y_true, y_prob)
        except: auc = float("nan")
        f1 = f1_score(y_true, y_pred, pos_label=1, zero_division=0)
        fold_results.append({"auc": auc, "f1": f1})

        n_ax = int(X[va_idx][:, all_feats.index("has_axivity")].sum())
        n_sw = int(X[va_idx][:, all_feats.index("has_armswing")].sum())
        print(f"  Fold {fold+1}/{N_FOLDS} | n_train={len(y_tr)} n_val={len(y_va)} "
              f"(axivity:{n_ax} armswing:{n_sw}) | "
              f"ROC-AUC={auc:.3f}  F1={f1:.3f} | "
              f"severity dist={sev_dist}")

    mean_auc = np.nanmean([r["auc"] for r in fold_results])
    mean_f1  = np.nanmean([r["f1"]  for r in fold_results])
    print(f"\n  Mean ROC-AUC: {mean_auc:.3f}   Mean F1: {mean_f1:.3f}")
    print(f"  AUC per fold: {[round(r['auc'],3) for r in fold_results]}")

    # ── Final model on all data ───────────────────────────────────────────────
    print("\n── Training final model on all data ──")
    imputer_f = SimpleImputer(strategy="median")
    X_all     = imputer_f.fit_transform(X)
    scaler_f  = StandardScaler()
    X_all     = scaler_f.fit_transform(X_all)

    cc_all = np.bincount(y.astype(int))
    pw_all = cc_all[0] / max(cc_all[1], 1)

    from sklearn.model_selection import train_test_split
    X_ft, X_fv, y_ft, y_fv = train_test_split(
        X_all, y, test_size=0.15, random_state=SEED, stratify=y
    )
    final_model, _ = train_model(
        X_ft, y_ft, X_fv, y_fv,
        input_dim=len(all_feats), args=args, device=device, pw_val=pw_all
    )

    scaler_path = os.path.join(args.output_dir, "scaler.pkl")
    with open(scaler_path, "wb") as f:
        pickle.dump({"imputer": imputer_f, "scaler": scaler_f,
                     "feature_cols": all_feats}, f)
    print(f"  Saved scaler+imputer → {scaler_path}")
    print(f"  Feature count for Flutter inference: {len(all_feats)}")

    ptl_path = os.path.join(args.output_dir, "gait_classifier.ptl")
    export_to_mobile(final_model, len(all_feats), ptl_path)
    print("\n✓ Done.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--opals",      required=True)
    parser.add_argument("--axivity",    required=True)
    parser.add_argument("--updrs",      required=True)
    parser.add_argument("--output_dir", default="outputs")
    parser.add_argument("--epochs",     type=int,   default=300)
    parser.add_argument("--batch_size", type=int,   default=16)
    parser.add_argument("--lr",         type=float, default=1e-3)
    parser.add_argument("--patience",   type=int,   default=30)
    args = parser.parse_args()
    main(args)
