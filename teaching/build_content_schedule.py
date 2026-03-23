#!/usr/bin/env python3
"""
build_content_schedule.py

Reads:
  ../materials_master_bank.csv   — article pool (PRO/ANTI/APOL/CTRL)
  sim_arm_export.csv             — Stata export: study_id, arm (recruited only)

Generates:
  content_assignment.csv         — one row per person × slot (24 rows × 6365 people)

Columns:
  study_id, content_id, week, slot_wk,
  article_id, article_title, topic, bank,
  sched_valence, sched_political

Schedule design (from proposal Table 2):
  Arm 1  Pro-China  low   :  6 PRO  (slots 1,5,9,13,17,21) + 18 CTRL
  Arm 2  Pro-China  high  : 24 PRO
  Arm 3  Anti-China low   :  6 ANTI (same slots as arm 1)  + 18 CTRL
  Arm 4  Anti-China high  : 24 ANTI
  Arm 5  Apolitical China : 12 APOL (slot_wk==1 every week) + 12 CTRL
  Arm 6  Non-China ctrl   : 24 CTRL

Pool sizes: PRO=24, ANTI=24, APOL=17, CTRL=24
All within-person assignments are non-repeating (pool >= slots needed).
"""

import csv
import random
import os

SEED = 20250406

HERE = os.path.dirname(os.path.abspath(__file__))
BANK_PATH   = os.path.join(HERE, '..', 'materials_master_bank.csv')
ARM_EXPORT  = os.path.join(HERE, 'sim_arm_export.csv')
OUT_PATH    = os.path.join(HERE, 'content_assignment.csv')

# ── 1. Load article bank ────────────────────────────────────────────────────
with open(BANK_PATH, newline='', encoding='utf-8') as f:
    bank = list(csv.DictReader(f))

def get_pool(bank_code):
    return [r for r in bank if r['bank'] == bank_code]

PRO_POOL  = get_pool('PRO')             # 24
ANTI_POOL = get_pool('ANTI')            # 24
APOL_POOL = get_pool('APOL_CHINA')      # 17
CTRL_POOL = get_pool('NONCHINA_CONTROL')# 24

print(f"Pool sizes  PRO={len(PRO_POOL)}  ANTI={len(ANTI_POOL)}  "
      f"APOL={len(APOL_POOL)}  CTRL={len(CTRL_POOL)}")

POOL_MAP = {
    'PRO':  PRO_POOL,
    'ANTI': ANTI_POOL,
    'APOL': APOL_POOL,
    'CTRL': CTRL_POOL,
}

# ── 2. Slot schedule ────────────────────────────────────────────────────────
# content_id 1..24:  week = ceil(cid/2),  slot_wk = 1 if odd else 2
#
# Design: EVERY week = 1 treatment (slot_wk 1) + 1 CTRL filler (slot_wk 2)
#   Arm 1/3 low  : treatment in 6 of 12 weeks (odd weeks: cids 1,5,9,13,17,21)
#                  the other 6 weeks: slot_wk 1 = CTRL as well
#   Arm 2/4 high : treatment in ALL 12 weeks (slot_wk 1 = PRO/ANTI every week)
#   Arm 5        : slot_wk 1 = APOL every week,  slot_wk 2 = CTRL
#   Arm 6        : all slots CTRL
#
# Resulting treatment counts per person:
#   Arm 1 → 6 PRO  + 18 CTRL   (6 weeks: 1 PRO+1CTRL  |  6 weeks: 2 CTRL)
#   Arm 2 → 12 PRO + 12 CTRL   (12 weeks: 1 PRO+1CTRL)
#   Arm 3 → 6 ANTI + 18 CTRL
#   Arm 4 → 12 ANTI + 12 CTRL
#   Arm 5 → 12 APOL + 12 CTRL
#   Arm 6 → 24 CTRL

LOW_POL_CIDS  = frozenset([1, 5, 9, 13, 17, 21])   # 6 political slots (low dose)
HIGH_POL_CIDS = frozenset(range(1, 24, 2))           # 12 slots: all slot_wk==1

def slot_type(arm: int, cid: int):
    """Return (pool_key, sched_valence) for this arm and content_id."""
    slot_wk = 1 if cid % 2 == 1 else 2
    if arm == 1:
        return ('PRO',  1) if cid in LOW_POL_CIDS else ('CTRL', 0)
    elif arm == 2:
        return ('PRO',  1) if cid in HIGH_POL_CIDS else ('CTRL', 0)
    elif arm == 3:
        return ('ANTI', -1) if cid in LOW_POL_CIDS else ('CTRL', 0)
    elif arm == 4:
        return ('ANTI', -1) if cid in HIGH_POL_CIDS else ('CTRL', 0)
    elif arm == 5:
        return ('APOL', 0) if slot_wk == 1 else ('CTRL', 0)
    else:   # arm 6
        return ('CTRL', 0)

# ── 3. Read participant arm assignments ─────────────────────────────────────
participants = []
with open(ARM_EXPORT, newline='', encoding='utf-8') as f:
    for row in csv.DictReader(f):
        participants.append({
            'study_id': int(float(row['study_id'])),
            'arm':      int(row['arm']),
        })

print(f"Participants loaded: {len(participants):,}")

# ── 4. Assign articles ───────────────────────────────────────────────────────
rng = random.Random(SEED)
rows_out = []

for p in participants:
    sid = p['study_id']
    arm = p['arm']

    # Group content_ids by pool type for this arm
    groups: dict[str, list[int]] = {}
    for cid in range(1, 25):
        key, _ = slot_type(arm, cid)
        groups.setdefault(key, []).append(cid)

    # Sample articles for each pool type (no within-person repeats)
    article_for_cid: dict[int, dict] = {}
    for key, cids in groups.items():
        pool_list = POOL_MAP[key].copy()
        rng.shuffle(pool_list)
        sampled = pool_list[: len(cids)]            # pool always >= needed
        for cid, art in zip(sorted(cids), sampled):
            article_for_cid[cid] = art

    # Build output rows
    for cid in range(1, 25):
        week    = (cid - 1) // 2 + 1
        slot_wk = 1 if cid % 2 == 1 else 2
        key, sched_valence = slot_type(arm, cid)
        art = article_for_cid[cid]
        rows_out.append({
            'study_id':       sid,
            'content_id':     cid,
            'week':           week,
            'slot_wk':        slot_wk,
            'article_id':     art['id'],
            'article_title':  art['title'],
            'topic':          art['topic'],
            'bank':           art['bank'],
            'sched_valence':  sched_valence,
            'sched_political': 1 if sched_valence != 0 else 0,
        })

# ── 5. Write output ──────────────────────────────────────────────────────────
fieldnames = list(rows_out[0].keys())
with open(OUT_PATH, 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows_out)

total = len(rows_out)
print(f"Written {total:,} rows → {OUT_PATH}")
print(f"  = {len(participants):,} participants × 24 slots")

# ── 6. Quick sanity checks ───────────────────────────────────────────────────
from collections import Counter

# Counts of article_ids per arm to verify schedule
arm_article_counts: dict[int, Counter] = {}
for p in participants:
    arm_article_counts.setdefault(p['arm'], Counter())
arm_valence: dict[int, Counter] = {}
for p in participants:
    arm_valence.setdefault(p['arm'], Counter())

for row in rows_out:
    sid = row['study_id']
    # find arm for this sid
arm_map = {p['study_id']: p['arm'] for p in participants}
sched_by_arm: dict[int, Counter] = {a: Counter() for a in range(1, 7)}
for row in rows_out:
    arm = arm_map[row['study_id']]
    sched_by_arm[arm][row['sched_valence']] += 1

arm_n = Counter(p['arm'] for p in participants)
print("\nSched_valence totals per arm (total slots):")
for a in range(1, 7):
    n = arm_n[a]
    cts = sched_by_arm[a]
    print(f"  Arm {a}  n={n:4d}  "
          f"pol+1={cts[1]//n if n else 0:2d}  "
          f"pol-1={cts[-1]//n if n else 0:2d}  "
          f"neutral={cts[0]//n if n else 0:2d}  "
          f"(per person)")
