import pandas as pd
import re

def norm(c):
    if not isinstance(c, str): return str(c)
    c = c.strip().upper()
    m = re.match(r'^V(\d+)$', c)
    return f'R{int(m.group(1)):02d}' if m else c

op = pd.read_csv('Gait_Data___Arm_swing__Opals__31May2026.csv')
up = pd.read_csv('MDS-UPDRS_Part_III_31May2026.csv', low_memory=False)
op['VISIT'] = op['VISNO'].apply(norm)
up['VISIT'] = up['EVENT_ID'].apply(norm)
m = op.merge(up[['PATNO','VISIT','INFODT','NP3GAIT']], on=['PATNO','VISIT'])
print(m[['PATNO','VISIT','INFODT_x','INFODT_y','SP_U','CAD_U','NP3GAIT']].head(20).to_string())
