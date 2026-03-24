# English-News RCT — Data and Replication Files

**Study**: *Breaking the Great Firewall: A Field Experiment on Framed Foreign-News Exposure in China*  
**Principal Investigator**: Ziwen Zu, Department of Political Science, UC San Diego  
**Data vintage**: March 2026

---

## Overview

This folder contains the participant-level and weekly-level datasets for a six-arm randomized field experiment embedded in a Chinese English test-preparation app. Over twelve weeks (June–October 2025), recruited participants received two English-language readings per week drawn from major Western outlets (*The New York Times*, *The Economist*, *The Washington Post*, *The Wall Street Journal*). The key experimental manipulations are article **valence** (pro-China vs. anti-China vs. neutral) and **political dose** (low vs. high). All data collection and randomization occurred inside the partner app's backend.

---

## File Structure

```
├── participant.dta          # Participant-level wide file (one row per person)
├── weekly_long.dta          # Weekly-slot-level long file (one row per person × slot)
```

---

## Sample Flow

| Stage | N | Variable |
|-------|---|----------|
| Completed baseline survey | **12,215** | full analytic frame |
| Recruited (clicked consent) | **6,365** | `recruited == 1` |
| Completed endline survey | **5,215** | `complete_endline == 1` |
| Completed follow-up survey | **2,115** | `complete_followup == 1` |

**Recruitment mechanism**: Participants were selected from the baseline pool on the basis of (a) passing quality checks (`t0_att_pass`, `t0_straightline_flag`) and (b) stated interest in studying abroad (`t0_abroad_plan`), with large random noise ensuring natural variation. The 5,850 non-recruited participants serve as a non-experimental baseline comparison group.

**Attrition**: Recruited participants who did not complete the endline survey (`complete_endline == 0`, N = 1,150) exited the weekly program continuously — their `last_week_active` records the final week with engagement (1–11).

---

## Treatment Arms

Every participant received **24 content slots** over 12 weeks (2 per week). Slot 1 each week delivers the arm-specific treatment article; Slot 2 always delivers a non-China neutral filler.

| Arm | Label | Political articles | Neutral fillers | N |
|-----|-------|--------------------|-----------------|---|
| 1 | Pro-China, low dose | 6 (participant-specific randomized slot-1 weeks) | 18 | 1,061 |
| 2 | Pro-China, high dose | 12 (every week, slot 1) | 12 | 1,061 |
| 3 | Anti-China, low dose | 6 (participant-specific randomized slot-1 weeks) | 18 | 1,061 |
| 4 | Anti-China, high dose | 12 (every week, slot 1) | 12 | 1,061 |
| 5 | Apolitical China | 12 apolitical (every week, slot 1) | 12 | 1,061 |
| 6 | Non-China control (ref) | 0 | 24 | 1,060 |

**Article pools**: PRO = 24 articles, ANTI = 24, APOL_CHINA = 17, NONCHINA_CONTROL = 24. All drawn from the master bank (`../materials_master_bank.csv`). Articles are assigned without within-person repetition via `build_content_schedule.py`.

**Dose contrast**: high (12) vs. low (6) political articles = 2:1 ratio.

---

## Block Randomization

Randomization was stratified on four baseline variables yielding **24 strata** (`block_id`):

| Blocking variable | Variable | Values |
|-------------------|----------|--------|
| Gender | `blk_gender` | 1 Male, 2 Female |
| Region | `blk_region` | 1 East, 2 Central, 3 West |
| English proficiency | `blk_eng_hi` | 1 Lower, 2 Higher |
| Baseline nationalism | `blk_nat_hi` | 1 Lower, 2 Higher |

---

## Key Variables — `participant.dta` (12,215 obs, 185 variables)

### Design and sample flow

| Variable | Type | Description |
|----------|------|-------------|
| `study_id` | int | Anonymous participant ID |
| `arm` | byte | Assigned arm (1–6; 6 = reference) |
| `block_id` | byte | Randomization block (1–24) |
| `recruited` | byte | 1 = clicked consent; entered RCT |
| `complete_endline` | byte | 1 = completed endline survey |
| `complete_followup` | byte | 1 = completed follow-up survey |
| `last_week_active` | byte | Last week with engagement (1–12) |
| `treat_valence` | byte | −1 Anti-China, 0 Neutral, +1 Pro-China |
| `treat_dose_hi` | byte | 1 = high dose (arm 2/4), 0 = low dose (arm 1/3) |
| `n_pol_slots` | byte | Scheduled political article slots (0/6/12) |
| `arm1`–`arm5` | byte | Treatment arm dummies (ref = arm 6) |

### Baseline covariates (t0)

**Demographics**: `t0_age`, `t0_age_cat`, `t0_female`, `t0_ethnic_han`, `t0_educ`, `t0_city`, `t0_party_id`

**Exam profile**: `t0_exam_type`, `t0_exam_score` (0–100, ~78% non-missing), `t0_prep_weeks`, `t0_join_motivation`

**Media behavior** (90-day frequency, 1–5): `t0_freq_state`, `t0_freq_comm`, `t0_freq_soc`, `t0_freq_foreign`, `t0_freq_chat`

**Media trust** (1–5): `t0_trust_state`, `t0_trust_comm`, `t0_trust_soc`, `t0_trust_foreign`, `t0_trust_chat`

**Platform use** (0/1): `t0_plat_tiktok`, `t0_plat_fb`, `t0_plat_tw`, `t0_plat_yt`, `t0_plat_ig`

**Foreign orientation**: `t0_abroad_ever`, `t0_abroad_plan` (1 Definitely yes – 4 Definitely not), `t0_news_foreign_30d`

**Attitude batteries** (1–5 Likert, standardized indices):  
- Regime support: `t0_rs_econ/stab/eq/tech/gov`, `t0_rs_index`  
- Censorship attitudes: `t0_cen_stab/right/prot`, `t0_cen_index`  
- Nationalism: `t0_nat_bias/resist/proud/unfair`, `t0_nat_index`  
- Thermometers (0–100): `t0_therm_cn`, `t0_therm_west`, `t0_therm_gap`

**QC**: `t0_att_pass`, `t0_straightline_flag`, `t0_ts_submit` (%tc)

### Endline outcomes (t1, N = 5,215)

**Primary attitude outcomes** (repeat of t0 batteries):  
`t1_rs_*`, `t1_rs_index`, `t1_cen_*`, `t1_cen_index`, `t1_nat_*`, `t1_nat_index`, `t1_therm_*`

**Media trust** (t1): `t1_trust_state/comm/soc/foreign/chat`

**Difference scores**: `d1_rs_index`, `d1_cen_index`, `d1_nat_index`, `d1_therm_gap`, `d1_trust_foreign`

**Knowledge retention** (0/1, 12 items): `t1_kq1`–`t1_kq12`; `t1_know_prop_all`, `t1_know_prop10` (content items only)

**WTP / behavioral demand** (BDM mechanism):  
`t1_wtp_bid` (0–50 RMB stated maximum), `t1_wtp_draw` (random price), `t1_wtp_buy` (1 if draw ≤ bid), `t1_wtp_outlet` (chosen outlet 1–4)

**Policy attitudes**: `t1_pol_econ`, `t1_pol_dev`, `t1_pol_cult`, `t1_pol_sci` (1–5)

**QC**: `t1_att_pass`, `t1_straightline_flag`, `t1_ts_submit`

### Follow-up outcomes (t2, N = 2,115)

Mirrors t1 batteries: `t2_rs_*`, `t2_cen_*`, `t2_nat_*`, `t2_therm_*`, `t2_trust_*`, `t2_kq1`–`t2_kq12`

**Difference scores (t2 − t0)**: `d2_rs_index`, `d2_cen_index`, `d2_nat_index`, `d2_therm_gap`, `d2_trust_foreign`

**Behavioral demand**: `t2_digest_signup` (0/1 opted into foreign-news digest), `t2_bias_cn`, `t2_bias_west` (0–10 perceived media bias)

### Weekly aggregates (recruited only, w\_\*)

| Variable | Description |
|----------|-------------|
| `w_n_slots` | Active content slots (max 24) |
| `w_n_comply` | Compliant slots (watch ≥ 80% + quiz attempted) |
| `w_sum_read_min` | Total reading time (minutes) |
| `w_sum_vid_min` | Total audio/video time (minutes) |
| `w_mean_quiz` | Mean aggregate quiz score (0–100) |
| `w_mean_interest` | Mean article interest rating (0–100) |
| `w_mean_cred` | Mean article credibility rating (0–100) |
| `w_mean_similar` | Mean "want more similar" rating (0–100) |
| `w_cnt_political_open` | Count of political article slots opened |

---

## Key Variables — `weekly_long.dta` (152,760 obs; recruited × 24 slots)

| Variable | Description |
|----------|-------------|
| `study_id` | Links to `participant.dta` |
| `content_id` | Slot index (1–24) |
| `week` | Week number (1–12) |
| `slot_wk` | Slot within week (1 = treatment/apol slot, 2 = filler) |
| `article_id` | Assigned article ID (e.g., `PRO_003`) |
| `article_title` | Article headline |
| `bank` | Article pool: PRO / ANTI / APOL_CHINA / NONCHINA_CONTROL |
| `sched_valence` | Scheduled valence: −1 anti, 0 neutral, +1 pro |
| `sched_political` | 1 if slot has political content |
| `wk_open` | 1 if slot is in active weeks (missing after dropout) |
| `wk_comply` | 1 if video ≥ 80% watched |
| `wk_read_min` | Reading time (minutes) |
| `wk_vid_pct` | Proportion of audio listened (0–1) |
| `wk_quiz_comprehension/grammar/vocab/listen/sentence` | Quiz sub-scores (0–20) |
| `wk_quiz_score` | Aggregate quiz score (0–100) |
| `wk_rate_interest` | Article interest rating (0–100) |
| `wk_rate_cred` | Article credibility rating (0–100) |
| `wk_rate_similar` | Want more similar content (0–100) |

---

## Hypotheses and Key Results

| Hypothesis | Description | T1 Result |
|------------|-------------|-----------|
| H1 | Anti-China content reduces regime support | arm4 −0.30 SD \*\*\* |
| H2 | Pro-China content increases trust in foreign media (costly signal) | arm2 +0.21 pts \*\*\* |
| H3 | Apolitical China content ≠ non-China control | arm5 +0.08 SD \*\* |
| H4 | High dose amplifies effects (2:1 ratio) | arm2 > arm1 \*\*\*, arm4 > arm3 \*\*\* |
| H5 | Dissonant high-dose exposure suppresses demand | arm4 WTP −3.8 RMB \*\*\* |
| HTE-1 | Anti-China × nationalism → backlash | arm4 × nat +0.14 \*\*\* |
| HTE-2 | Ideology moderates trust shift | arm2 × nat −0.15 \*\*\* |
| HTE-3 | Prior exposure amplifies credibility shift | arm2 × ff_z +0.09 \*\*\* |
| HTE-4 | Attention amplifies persuasion | arm4 × exam_z −0.16 \*\*\* |

**T2 persistence**: Regime support effects decay to non-significance; arm2 (pro-China high) shows marginal persistence on `t2_rs_index` (t = 2.03, p = 0.043).

---

## Value Labels

Key value label names (all English):

| Label name | Variable(s) | Values |
|------------|-------------|--------|
| `arm_lbl` | `arm` | 1–6 arm descriptions |
| `freq90d_lbl` | `t0_freq_*` | 1 Never … 5 Daily |
| `trust_src_lbl` | `t0_trust_*`, `t1_trust_*`, `t2_trust_*` | 1 No trust … 5 Complete trust |
| `likert5_lbl` | attitude items | 1 Low/disagree … 5 High/agree |
| `abroad_plan_lbl` | `t0_abroad_plan` | 1 Definitely yes … 4 Definitely not |
| `educ_bl_lbl` | `t0_educ` | 1 Undergraduate … 4 Doctorate |
| `party_lbl` | `t0_party_id` | 1 Youth League, 2 CPC, 3 Non-member |
| `valence_lbl` | `treat_valence`, `sched_valence` | −1 Anti-China, 0 Neutral, +1 Pro-China |
| `wtp_outlet_lbl` | `t1_wtp_outlet` | 1 NYT, 2 Economist, 3 WSJ, 4 Washington Post |

---

## Codebook Notes

- **`t0_city`**: Chinese city names (string); ~275 prefecture-level units, population-weighted.
- **`t0_exam_score`**: Standardized to 0–100 across exam types (TOEFL reading, IELTS band, GRE/GMAT verbal proxy). Missing (~22%) for participants who had not yet sat a recent exam.
- **Missing values**: `t1_*` and `t2_*` variables are missing for participants who did not reach the relevant survey wave (by design). `wk_*` variables in `weekly_long.dta` are missing for weeks after a participant's dropout point.
- **Indices**: `t0_rs_index`, `t0_nat_index`, `t0_cen_index` are mean-standardized (SD ≈ 1) from their respective Likert item batteries.
- **`t1_wtp_draw`**: Random draw from U[0, 50] implementing a Becker-DeGroot-Marschak mechanism. Independent of all covariates by design; useful as an instrument or for revealing the WTP distribution shape.

---

## Contact

Ziwen Zu — zzu@ucsd.edu — Department of Political Science, UC San Diego
