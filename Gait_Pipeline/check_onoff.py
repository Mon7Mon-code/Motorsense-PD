import pandas as pd

up = pd.read_csv('MDS-UPDRS_Part_III_31May2026.csv', low_memory=False)

# Show the medication state columns for the rows that match our gait patients
print("Relevant columns for ON/OFF state:")
state_cols = ['PATNO', 'EVENT_ID', 'PDTRTMNT', 'PDSTATE', 'OFFEXAM', 'ONEXAM',
              'PDMEDYN', 'NP3GAIT', 'INFODT']
available = [c for c in state_cols if c in up.columns]
print(available)

# Show a sample of rows for a patient we know has duplicates
sample = up[up['PATNO'] == 40553][available].head(10)
print("\nPatient 40553 UPDRS rows:")
print(sample.to_string())

print("\nPDSTATE value counts:")
if 'PDSTATE' in up.columns:
    print(up['PDSTATE'].value_counts(dropna=False))

print("\nOFFEXAM value counts:")
if 'OFFEXAM' in up.columns:
    print(up['OFFEXAM'].value_counts(dropna=False))
