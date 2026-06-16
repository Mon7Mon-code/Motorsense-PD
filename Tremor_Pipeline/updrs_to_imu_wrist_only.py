"""
UPDRS to IMU Converter - WRIST-MOUNTED SENSOR VERSION
Only uses upper limb tremor data valid for wrist placement
"""

import pandas as pd
import numpy as np
import json

# ============================================================================
# WRIST-SPECIFIC CONVERSION (with attenuation factor)
# ============================================================================

def updrs_to_displacement(updrs_score, alpha=0.5, beta=-2.0):
    """Elble equation: log10(T) = α·R + β"""
    displacement_cm = 10 ** (alpha * updrs_score + beta)
    return displacement_cm / 100  # Convert to meters


def updrs_to_acceleration_wrist(updrs_score, frequency_hz=5.0, tremor_type='rest'):
    """
    Convert UPDRS to acceleration for WRIST-MOUNTED sensor.
    
    Includes 15% attenuation factor based on Van der Linden et al. (2025)
    "Assessing Parkinson's Rest Tremor from the Wrist"
    - Wrist correlation: r = 0.72-0.85
    - Finger correlation: r = 0.89-0.98
    - Attenuation: ~15% lower amplitude at wrist vs finger
    """
    alpha_values = {
        'rest': 0.465,
        'postural': 0.422,
        'kinetic': 0.306
    }
    
    alpha = alpha_values.get(tremor_type, 0.5)
    
    # Standard conversion
    displacement = updrs_to_displacement(updrs_score, alpha=alpha)
    omega = 2 * np.pi * frequency_hz
    acceleration = displacement * (omega ** 2)
    
    # Apply wrist attenuation (15% reduction)
    WRIST_ATTENUATION = 0.85
    acceleration_wrist = acceleration * WRIST_ATTENUATION
    
    return acceleration_wrist


def generate_tremor_signal_wrist(updrs_score, tremor_type='rest', duration=10.0, 
                                  sample_rate=100, seed=None):
    """
    Generate realistic 3-axis wrist accelerometer data from UPDRS score.
    """
    if seed is not None:
        np.random.seed(seed)
    
    n_samples = int(duration * sample_rate)
    t = np.linspace(0, duration, n_samples)
    
    tremor_freq = np.random.uniform(4.0, 6.0)
    acc_amplitude = updrs_to_acceleration_wrist(updrs_score, tremor_freq, tremor_type)
    
    if updrs_score == 0:
        # No tremor - only background noise
        acc_x = np.random.normal(0, 0.05, n_samples)
        acc_y = np.random.normal(0, 0.05, n_samples)
        acc_z = np.random.normal(0, 0.05, n_samples)
        tremor_freq = 0.0
    else:
        # Tremor signal on primary axis (X - radial-ulnar deviation)
        tremor_x = acc_amplitude * np.sin(2 * np.pi * tremor_freq * t)
        
        # Secondary tremor on Y (flexion-extension)
        tremor_y = (acc_amplitude * 0.35) * np.sin(2 * np.pi * tremor_freq * t + np.pi/4)
        
        # Minimal Z (pronation-supination)
        tremor_z = (acc_amplitude * 0.15) * np.sin(2 * np.pi * tremor_freq * t - np.pi/3)
        
        # Biological noise
        noise_level = max(0.05, acc_amplitude * 0.15)
        acc_x = tremor_x + np.random.normal(0, noise_level, n_samples)
        acc_y = tremor_y + np.random.normal(0, noise_level, n_samples)
        acc_z = tremor_z + np.random.normal(0, noise_level, n_samples)
    
    # Add gravity component based on wrist position
    if tremor_type == 'postural':
        acc_z += 9.81 * np.cos(np.radians(30))  # Arms extended
    elif tremor_type == 'rest':
        acc_z += 9.81 * np.cos(np.radians(60))  # Hands in lap
    
    return {
        'time': t,
        'acc_x': acc_x,
        'acc_y': acc_y,
        'acc_z': acc_z,
        'updrs_score': updrs_score,
        'tremor_type': tremor_type,
        'tremor_frequency': tremor_freq,
        'sample_rate': sample_rate,
        'duration': duration
    }


def extract_features(acc_x, acc_y, acc_z, sample_rate=100):
    """Extract ML features from accelerometer data."""
    acc_mag = np.sqrt(acc_x**2 + acc_y**2 + acc_z**2)
    
    # Remove DC
    acc_x_ac = acc_x - np.mean(acc_x)
    acc_y_ac = acc_y - np.mean(acc_y)
    acc_z_ac = acc_z - np.mean(acc_z)
    acc_mag_ac = np.sqrt(acc_x_ac**2 + acc_y_ac**2 + acc_z_ac**2)
    
    # FFT
    n = len(acc_mag_ac)
    fft_mag = np.fft.fft(acc_mag_ac)
    freqs = np.fft.fftfreq(n, 1/sample_rate)
    psd = np.abs(fft_mag[:n//2])**2 / n
    freqs_positive = freqs[:n//2]
    
    # Power in 4-6 Hz
    tremor_band_mask = (freqs_positive >= 4) & (freqs_positive <= 6)
    power_4_6hz = np.sum(psd[tremor_band_mask])
    
    # Dominant frequency
    if np.sum(tremor_band_mask) > 0:
        dominant_freq_idx = np.argmax(psd[tremor_band_mask])
        dominant_freq = freqs_positive[tremor_band_mask][dominant_freq_idx]
    else:
        dominant_freq = 0.0
    
    # Time domain
    rms_x = np.sqrt(np.mean(acc_x_ac**2))
    rms_y = np.sqrt(np.mean(acc_y_ac**2))
    rms_z = np.sqrt(np.mean(acc_z_ac**2))
    rms_mag = np.sqrt(np.mean(acc_mag_ac**2))
    
    mean_abs_x = np.mean(np.abs(acc_x_ac))
    mean_abs_y = np.mean(np.abs(acc_y_ac))
    mean_abs_z = np.mean(np.abs(acc_z_ac))
    
    zero_crossings = np.sum(np.diff(np.sign(acc_mag_ac)) != 0) / len(acc_mag_ac)
    
    return {
        'power_4_6hz': power_4_6hz,
        'log_power_4_6hz': np.log10(power_4_6hz + 1e-10),
        'dominant_frequency': dominant_freq,
        'rms_x': rms_x,
        'rms_y': rms_y,
        'rms_z': rms_z,
        'rms_magnitude': rms_mag,
        'mean_abs_x': mean_abs_x,
        'mean_abs_y': mean_abs_y,
        'mean_abs_z': mean_abs_z,
        'zero_crossing_rate': zero_crossings
    }


# ============================================================================
# WRIST-ONLY DATASET PROCESSING
# ============================================================================

def process_updrs_wrist_only(csv_path, output_path, samples_per_score=100):
    """
    Convert UPDRS CSV to wrist-mounted IMU training dataset.
    ONLY uses upper limb tremor columns valid for wrist placement.
    """
    print("="*70)
    print("WRIST-MOUNTED SENSOR - UPPER LIMB DATA ONLY")
    print("="*70)
    print("\nLoading UPDRS dataset...")
    df = pd.read_csv(csv_path, low_memory=False)
    
    print(f"Original dataset shape: {df.shape}")
    
    # ONLY upper limb tremor columns (wrist-valid)
    tremor_cols = {
        'NP3PTRMR': 'postural',  # ✓ Postural tremor - RIGHT hand
        'NP3PTRML': 'postural',  # ✓ Postural tremor - LEFT hand
        'NP3KTRMR': 'kinetic',   # ✓ Kinetic tremor - RIGHT hand
        'NP3KTRML': 'kinetic',   # ✓ Kinetic tremor - LEFT hand
        'NP3RTARU': 'rest',      # ✓ Rest tremor - RIGHT upper limb
        'NP3RTALU': 'rest',      # ✓ Rest tremor - LEFT upper limb
    }
    
    print(f"\n✓ Using {len(tremor_cols)} WRIST-VALID upper limb columns:")
    for col, ttype in tremor_cols.items():
        print(f"  - {col}: {ttype} tremor")
    
    print("\n✗ EXCLUDED (not detectable at wrist):")
    print("  - NP3RTARL: Lower limb (leg)")
    print("  - NP3RTALL: Lower limb (leg)")
    print("  - NP3RTALJ: Lip/Jaw")
    print("  - NP3RTCON: Constancy measure")
    
    # Collect scores
    all_scores = []
    for col, tremor_type in tremor_cols.items():
        scores = df[col].dropna()
        scores = scores[(scores >= 0) & (scores <= 4)]  # Valid range only
        all_scores.extend([(score, tremor_type, col) for score in scores])
    
    print(f"\nTotal valid upper limb tremor scores: {len(all_scores)}")
    
    # Count by score and type
    score_type_counts = {}
    for score, ttype, _ in all_scores:
        key = (int(score), ttype)
        score_type_counts[key] = score_type_counts.get(key, 0) + 1
    
    print("\nDistribution of scores:")
    for ttype in ['rest', 'postural', 'kinetic']:
        print(f"\n{ttype.capitalize()} tremor:")
        for score in range(5):
            count = score_type_counts.get((score, ttype), 0)
            print(f"  UPDRS {score}: {count} samples")
    
    # Generate synthetic dataset
    print(f"\n{'='*70}")
    print(f"Generating {samples_per_score} synthetic samples per UPDRS level...")
    print(f"{'='*70}")
    
    dataset = []
    generated_counts = {}
    
    for tremor_type in ['rest', 'postural', 'kinetic']:
        for updrs_score in range(5):
            print(f"\nGenerating {tremor_type} tremor, UPDRS {updrs_score}...", end='')
            
            for i in range(samples_per_score):
                signal_data = generate_tremor_signal_wrist(
                    updrs_score=updrs_score,
                    tremor_type=tremor_type,
                    duration=10.0,
                    sample_rate=100,
                    seed=None
                )
                
                features = extract_features(
                    signal_data['acc_x'],
                    signal_data['acc_y'],
                    signal_data['acc_z'],
                    sample_rate=100
                )
                
                record = {
                    **features,
                    'updrs_score': int(updrs_score),
                    'tremor_type': tremor_type,
                    'tremor_frequency': signal_data['tremor_frequency']
                }
                
                dataset.append(record)
                
                key = (tremor_type, updrs_score)
                generated_counts[key] = generated_counts.get(key, 0) + 1
            
            print(f" ✓ {samples_per_score} samples generated")
    
    # Convert to DataFrame
    df_dataset = pd.DataFrame(dataset)
    
    # Save
    df_dataset.to_csv(output_path, index=False)
    
    print(f"\n{'='*70}")
    print(f"✓ SAVED {len(df_dataset)} samples to:")
    print(f"  {output_path}")
    print(f"{'='*70}")
    
    # Statistics
    print("\nDataset breakdown:")
    print(df_dataset.groupby(['tremor_type', 'updrs_score']).size().unstack(fill_value=0))
    
    print("\nFeature statistics:")
    print(df_dataset[['power_4_6hz', 'rms_magnitude', 'dominant_frequency', 'updrs_score']].describe())
    
    return df_dataset


def print_wrist_conversion_table():
    """Print UPDRS to acceleration conversion table for WRIST sensor."""
    print("\n" + "="*70)
    print("WRIST-MOUNTED SENSOR: UPDRS TO ACCELERATION CONVERSION")
    print("Includes 15% attenuation factor (Van der Linden et al., 2025)")
    print("="*70)
    
    for ttype, alpha in [('Rest', 0.465), ('Postural', 0.422), ('Kinetic', 0.306)]:
        print(f"\n{ttype} Tremor (f=5Hz, α={alpha}):")
        print("-" * 70)
        print(f"{'UPDRS':<8} {'Displacement':<15} {'Finger Sensor':<18} {'Wrist Sensor':<18}")
        print("-" * 70)
        
        for updrs in range(5):
            disp = 10 ** (alpha * updrs - 2.0) / 100  # meters
            acc_finger = disp * (2 * np.pi * 5) ** 2
            acc_wrist = acc_finger * 0.85  # 15% attenuation
            
            print(f"{updrs:<8} {disp*100:.4f} cm      "
                  f"{acc_finger:>8.3f} m/s²      "
                  f"{acc_wrist:>8.3f} m/s² (-15%)")
    
    print("\n" + "="*70)


if __name__ == "__main__":
    # Print conversion table
    print_wrist_conversion_table()
    
    # Process dataset
    input_csv = '/mnt/user-data/uploads/MDS-UPDRS_Part_III_28Jan2026.csv'
    output_csv = '/home/claude/imu_wrist_training_data.csv'
    
    df = process_updrs_wrist_only(input_csv, output_csv, samples_per_score=100)
