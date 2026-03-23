# Empirical Analysis Prep

This note records the parts of the project documentation that should guide the empirical analysis.

## What to treat as authoritative

1. The realized datasets in `analysis/data/`.
2. The replication README in `analysis/README.md`.
3. The updated empirical-strategy and deviations sections in `writing/proposal.tex`.

The PAP in `IRB/PAP.md` is still useful for the broad theory and hypothesis families, but several parts of it describe earlier designs that do not match the realized data.

## Realized design to use

- Baseline analytic frame: 12,215 participants.
- Randomized sample: 6,365 participants.
- Endline sample: 5,215 participants.
- Follow-up sample: 2,115 participants.
- Randomization: 24 blocks built from gender, region, English proficiency, and baseline nationalism.
- Arms:
  - 1: Pro-China, low dose, 6 political slots.
  - 2: Pro-China, high dose, 12 political slots.
  - 3: Anti-China, low dose, 6 political slots.
  - 4: Anti-China, high dose, 12 political slots.
  - 5: Apolitical China, 12 apolitical China slots.
  - 6: Non-China control.

Each randomized participant has 24 scheduled slots across 12 weeks. Slot 1 carries the treatment or apolitical article. Slot 2 is a non-China neutral filler.

## Data structure

- `data/participant.dta`: 12,215 rows and 185 columns.
- `data/weekly_long.dta`: 152,760 rows and 27 columns.
- `participant.dta` includes the full baseline frame, treatment assignment, survey outcomes, and participant-level weekly aggregates.
- `weekly_long.dta` includes one row per randomized participant by content slot.

## Main outcome families

- Primary attitudes:
  - `t1_rs_index`, `t1_cen_index`, `t1_nat_index`, `t1_therm_gap`
  - follow-up mirrors at `t2_*`
- Media trust:
  - `t1_trust_*`, `t2_trust_*`
- Behavioral demand:
  - `t1_wtp_bid`, `t1_wtp_buy`, `t1_wtp_outlet`
  - `t2_digest_signup`
- Weekly process outcomes:
  - `wk_open`, `wk_comply`, `wk_read_min`, `wk_vid_min`, `wk_quiz_score`
  - `wk_rate_interest`, `wk_rate_cred`, `wk_rate_similar`

## Default analysis frame

- Primary ITT analyses should use randomized participants (`recruited == 1`).
- Endline models should usually condition on `complete_endline == 1` with attrition handled in sensitivity checks.
- Follow-up models should usually condition on `complete_followup == 1`.
- Baseline non-recruited cases are useful for describing recruitment and selection, not for treatment-effect estimation.

## Empirical strategy to start from

- Main specification: ANCOVA with block fixed effects and the baseline value of the outcome.
- Reference arm: arm 6, non-China control.
- Priority contrasts:
  - pooled anti-China versus control
  - pooled pro-China versus control
  - apolitical China versus control
  - high versus low dose within pro and within anti
- Heterogeneity:
  - baseline nationalism
  - baseline regime support
  - prior foreign exposure
- Compliance and dose:
  - use weekly opening and viewing measures to separate assignment from realized exposure
  - later 2SLS can instrument realized exposure with assigned arm or frame-dose cells

## Documentation drift to keep in mind

- `IRB/PAP.md` begins with an older two-arm VPN design with 1,000 participants. Do not use that for the empirical analysis.
- `IRB/PAP.md` also later describes an eight-arm design with mixed and grammar-only conditions. That does not match the realized data.
- `writing/proposal.tex` correctly says the realized study is a six-arm design and explicitly notes deviations from the PAP.
- `writing/proposal.tex` still has one stale treatment-table detail: the high-dose arms are described there as having 24 political pieces, but the datasets and README show 12 political pieces.

## Recommended first analysis steps

1. Reproduce the sample-flow and arm-assignment table from `participant.dta`.
2. Check baseline balance across arms, especially on the blocking variables and main pre-treatment outcomes.
3. Check differential attrition by arm for endline and follow-up.
4. Estimate endline ITT ANCOVA models for the main attitude outcomes.
5. Add heterogeneity by baseline nationalism and foreign-media exposure.
6. Move to weekly engagement, compliance, and dose-response analyses.

## Utility

Run `python 00_data_audit.py` from the `analysis/` directory for a quick data and design audit before modeling.
