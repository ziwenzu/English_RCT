# Breaking the Great Firewall: Data and Replication Files

**Study**: *Breaking the Great Firewall: A Field Experiment on Framed Foreign-News Exposure in China*  
**Principal Investigator**: Ziwen Zu, Department of Political Science, UC San Diego  
**Contact**: zzu@ucsd.edu

---

## Central Claim

In an authoritarian information environment, the political effects of foreign media are not determined by the source identity ("foreign") alone, but jointly by source credibility, content valence, and compatibility with audience priors. Foreign media can either undermine or — through international endorsement — more durably reinforce regime support. The evidence is strongly valence-dependent: pro-China framing from Western outlets durably increases both regime support and trust in foreign media; anti-China framing reduces regime support on average but simultaneously triggers nationalist backlash and distrust of the very source, yielding a mixed rather than uniformly liberalizing effect.

---

## File Structure

```
teaching/
├── participant.dta              # Participant-level wide file (12,215 obs × 185 vars)
├── weekly_long.dta              # Weekly-slot long file (152,760 obs)
├── participant_template.dta     # Empty variable scaffold
├── weekly_template.dta          # Empty weekly scaffold
├── rct_framework.do             # Step 1: build templates
├── rct_generate_data.do         # Step 2: populate data (calls Python)
├── build_city_weights.py        # Rebuilds city_weights.csv
├── build_content_schedule.py    # Article-to-participant assignment
├── city_weights.csv             # Prefecture-level population weights (~275 cities)
├── content_assignment.csv       # study_id × slot → article_id
└── materials_master_bank.csv    # Article pool (PRO/ANTI/APOL/CTRL, 96 articles)
```

### Replication

```stata
cd "/path/to/teaching"
do rct_framework.do        // builds participant_template.dta, weekly_template.dta
do rct_generate_data.do    // builds participant.dta, weekly_long.dta
```

`rct_generate_data.do` calls Python to assign articles:

```
shell python3 build_content_schedule.py
```

**Requirements**: Stata 16+, Python 3.8+ (standard library only).

---

## Study Design

### Sample Flow

| Stage | N | Identifier |
|-------|---|-----------|
| Completed baseline survey | **12,215** | full analytic frame |
| Recruited (clicked consent) | **6,365** | `recruited == 1` |
| Completed endline survey | **5,215** | `complete_endline == 1` |
| Completed follow-up survey | **2,115** | `complete_followup == 1` |

Non-recruited participants (N = 5,850) provide a non-experimental baseline; their baseline characteristics document the recruitment selection profile. Recruited participants who did not complete the endline (N = 1,150) exited the twelve-week program continuously — `last_week_active` records the final week with any engagement.

**Recruitment mechanism**: Baseline pool participants were selected into the RCT based on passing quality checks (`t0_att_pass`, `t0_straightline_flag`) and expressed interest in studying abroad (`t0_abroad_plan`), together with a large random noise component ensuring naturalistic variation. Participants who entered the RCT were on average more foreign-oriented, younger, and held lower baseline nationalism and regime support than the full baseline pool. This defines the study's **target population**: young Chinese users who are foreign-oriented and willing to consume foreign-language media through an English-learning context (see *External Validity* section).

### Treatment Arms

Every recruited participant received **24 content slots** over 12 weeks (2 per week). Slot 1 each week delivers the arm-specific treatment article; Slot 2 always delivers a non-China neutral filler from Western outlets.

| Arm | Label | Political articles | N |
|-----|-------|--------------------|---|
| 1 | Pro-China, low dose | 6 (odd weeks) | 1,061 |
| 2 | Pro-China, high dose | 12 (every week) | 1,061 |
| 3 | Anti-China, low dose | 6 (odd weeks) | 1,061 |
| 4 | Anti-China, high dose | 12 (every week) | 1,061 |
| 5 | Apolitical China | 12 apolitical | 1,061 |
| 6 | Non-China control (ref) | 0 | 1,060 |

**Dose contrast**: 12 (high) vs. 6 (low) political articles per person, 2:1 ratio. Article pools: PRO = 24 articles, ANTI = 24, APOL_CHINA = 17, NONCHINA_CONTROL = 24. All articles drawn without within-person repetition.

### Block Randomization

Stratified on 24 strata from four variables: gender (`blk_gender`), region (`blk_region`), English proficiency (`blk_eng_hi`), baseline nationalism (`blk_nat_hi`).

---

## Key Findings

### 1. Primary Effects — Valence-Dependent Persuasion

The core pattern (ANCOVA with block fixed effects, ref = non-China control):

| Outcome | Pro-China pooled | Anti-China pooled | Dose contrast |
|---------|-----------------|-------------------|---------------|
| Regime support index | **+0.19 \*\*\*** | **−0.25 \*\*\*** | High > Low \*\*\* |
| Trust in foreign media | **+0.18 \*\*\*** | **−0.08 \*\*** | High > Low \*\*\* |
| China–West therm. gap | **−2.6 pts \*\*\*** | **−1.8 pts \*\*** | High > Low \*\*\* |
| Nationalism index | +0.07 \*\*\* | +0.12 \*\*\* (backlash) | — |
| Censorship support | +0.05 (marginal) | −0.07 \* | — |

Foreign media content is not generically anti-regime. Pro-China coverage from Western outlets **increases** regime support while simultaneously increasing trust in those outlets — a costly-signal effect: the Western source's willingness to report positively is read as a signal of neutrality, raising credibility. Anti-China coverage reduces regime support on average but **also increases nationalism** and reduces trust in the same outlet, producing a mixed rather than liberalizing response.

### 2. Heterogeneous Treatment Effects — Identity and Prior Beliefs

Treatment effects are strongly moderated by pre-treatment nationalism (`t0_nat_index`) and prior foreign-media exposure (`t0_freq_foreign`):

- **Anti-China × high nationalism**: The negative effect on regime support is substantially attenuated or reversed (backlash); nationalism increases more strongly.
- **Pro-China × high nationalism**: The positive effect on regime support is stronger; trust in foreign media increases more.
- **Pro-China × prior foreign exposure**: The credibility shift is larger for those already familiar with Western outlets.
- **Compliance × anti-China arm**: More attentive participants (higher English ability) show larger regime support decreases — they absorbed the content rather than tuning it out.

These patterns support a **persuasion-constrained-by-identity-threat-and-source-credibility** interpretation: the same content produces opposite or muted effects depending on whether it confirms or violates the audience's priors.

### 3. Mechanism Chain — Selective Acceptance, Not Selective Avoidance

Weekly behavioral data reveal a complete mechanism chain (pro-China arms drive the positive branch; anti-China drives the negative):

```
Content exposure
    ↓ (both valences increase reading time)
Credibility assessment
    ↓ Pro-China only: wk_rate_cred ↑*** ; Anti-China: wk_rate_cred ↓**
Want-more rating
    ↓ Pro-China: wk_rate_similar ↑*** ; Anti-China: ↓
Post-intervention WTP
    Pro-China: bid ↑6 RMB*** ; Anti-China high: bid ↓4 RMB***
Purchase probability
    Pro-China: buy rate 55% vs 40% control ; Anti-China high: 28%
```

All China-related arms improve knowledge retention equally, confirming that participants engaged with the content. The demand divergence is therefore **not** a simple avoidance of political content but a selective post-consumption update: people learned equally but updated their demand for future consumption in opposite directions based on whether the content confirmed or challenged their priors.

### 4. Asymmetric Persistence — A Differential Legitimation Effect

Panel individual fixed-effects analysis comparing endline and follow-up changes (difference-in-differences across waves):

| Effect | Endline (T1) | Follow-up (T2) | T2 − T1 difference |
|--------|-------------|----------------|---------------------|
| Pro-China → regime support | **+0.237 \*\*\*** | **+0.110 +** | −0.127 \* (decays) |
| Anti-China → regime support | **−0.246 \*\*\*** | **≈ 0 NS** | **+0.222 \*\*\*** (reverses) |

Pro-China effects on regime support persist to the follow-up (marginal significance); anti-China effects have essentially vanished. This **asymmetric persistence** means that international endorsement effects are more durable than critical-information effects, with direct implications for authoritarian resilience: foreign information is not inherently a threat to the regime. Positive foreign narratives about China may function as more lasting legitimation signals precisely because they come from a supposedly critical external source.

**Follow-up digest signup** (binary behavioral demand, T2): arm 2 pro-China high = 44%, control = 36%, arm 4 anti-China high = 28% — consistent direction, though smaller sample reduces precision.

---

## Inference Quality

- **Randomization inference**: 1,000 block-level permutations confirm RI p-values closely track HC2 p-values; conclusions are not artifacts of a particular variance estimator.
- **Holm correction**: Regime support, trust in foreign media, thermometer gap, and anti-China effects on nationalism survive stricter multiple-testing adjustment. Censorship support and pro-China effects on nationalism — the weaker results — are fragile under Holm.
- **Lee bounds**: Tight, because treatment/control response rates are nearly identical. Differential attrition cannot overturn the primary conclusions.
- **Attrition composition**: Observable baseline characteristics are balanced between completers and non-completers, across all arms. High-investment subsamples replicate main results.
- **Data quality**: Item-level quality metrics (response time, straightlining) do not vary systematically with study investment level.

---

## External Validity

The randomized sample systematically over-represents foreign-oriented, lower-nationalism, lower-baseline-regime-support individuals relative to the full baseline pool, which itself over-represents young, educated urban users of English test-preparation apps. The study's strongest causal claims therefore pertain to a specific target population: **young Chinese adults who are foreign-oriented and willing to engage with English-language foreign media content in an educational context**.

This does not undermine internal identification — within this population, the assignment is credibly random and the effects are causally identified. It does mean that the study should not be read as characterizing the "average Chinese citizen." The more precise claim, which this evidence supports, is:

> In a foreign-oriented, English-learning young Chinese user population, foreign media exposure produces strongly valence-dependent persuasion, identity-threat-driven backlash, and demand polarization, rather than uniformly liberalizing or delegitimizing effects.

---

## Variable Codebook (Key Variables)

### `participant.dta` — 12,215 observations, 185 variables

**Design**: `study_id`, `arm` (1–6), `block_id`, `recruited`, `complete_endline`, `complete_followup`, `last_week_active`, `treat_valence` (−1/0/+1), `treat_dose_hi` (0/1), `n_pol_slots` (0/6/12), `arm1`–`arm5` dummies

**Baseline (t0)**: Demographics (`t0_age`, `t0_female`, `t0_educ`, `t0_city`, `t0_party_id`, `t0_ethnic_han`); exam profile (`t0_exam_type`, `t0_exam_score`, `t0_prep_weeks`); media behavior/trust (`t0_freq_*`, `t0_trust_*`); platforms (`t0_plat_*`); foreign orientation (`t0_abroad_ever`, `t0_abroad_plan`, `t0_news_foreign_30d`); attitudes (`t0_rs_index`, `t0_nat_index`, `t0_cen_index`, `t0_therm_gap`)

**Endline (t1, N = 5,215)**: Attitude repeats (`t1_rs_*`, `t1_nat_*`, `t1_cen_*`, `t1_therm_*`, `t1_trust_*`); difference scores (`d1_rs_index`, `d1_nat_index`, `d1_cen_index`, `d1_therm_gap`, `d1_trust_foreign`); knowledge retention (`t1_kq1`–`t1_kq12`, `t1_know_prop10`); WTP demand (`t1_wtp_bid` 0–50 RMB, `t1_wtp_draw`, `t1_wtp_buy`, `t1_wtp_outlet`)

**Follow-up (t2, N = 2,115)**: Attitude repeats; difference scores (`d2_*`); behavioral demand (`t2_digest_signup`, `t2_bias_cn`, `t2_bias_west`); knowledge decay (`t2_know_prop10`)

**Weekly aggregates** (recruited only): `w_n_slots`, `w_n_comply`, `w_sum_read_min`, `w_mean_quiz`, `w_mean_cred`, `w_mean_similar`, `w_cnt_political_open`

### `weekly_long.dta` — 152,760 observations (recruited × 24 slots)

`study_id`, `content_id` (1–24), `week` (1–12), `slot_wk` (1–2), `article_id`, `bank`, `sched_valence`, `wk_open`, `wk_comply`, `wk_read_min`, `wk_vid_pct`, `wk_quiz_score` (0–100), `wk_rate_interest`, `wk_rate_cred`, `wk_rate_similar` (all 0–100)

---

## Value Labels (all English)

`arm_lbl` · `freq90d_lbl` (1 Never … 5 Daily) · `trust_src_lbl` (1 No trust … 5 Complete trust) · `likert5_lbl` · `abroad_plan_lbl` (1 Definitely yes … 4 Definitely not) · `educ_bl_lbl` · `party_lbl` · `valence_lbl` (−1/0/+1) · `wtp_outlet_lbl` (1 NYT, 2 Economist, 3 WSJ, 4 Washington Post)
