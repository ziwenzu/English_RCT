/*==============================================================================
  rct_generate_data.do

  Simulated teaching data:
    N = 12,215  completed baseline survey (June 2025)
    recruited = 1 for 6,365 who clicked consent; entered RCT
      complete_endline = 1 for 5,215 (subset of recruited)
      complete_followup = 1 for 2,115 (subset of endline)

  Requires: participant_template.dta from rct_framework.do
  Output:   participant.dta  |  weekly_long.dta
==============================================================================*/

version 16.0
clear all
set more off

capture cd "/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/teaching"

* --- Exact sample counts ---
local n_recruited  6365   // clicked consent
local n_endline    5215   // completed endline (subset of recruited)
local n_followup   2115   // completed follow-up (subset of endline)
local n_no_endline = `n_recruited' - `n_endline'   // 1150: recruited, no endline
local n_endline_no_fu = `n_endline' - `n_followup' // 3100: endline, no follow-up
assert `n_recruited' + (12215 - `n_recruited') == 12215

local seed 20250322

* --- Baseline education (min. undergraduate; exact N, sum = 12,215) ---
* Ed4 (doctorate) kept small (100-200); tweak n_ed4 if needed; n_ed3 adjusts remainder.
local n_ed1 4900
local n_ed2 4300
local n_ed4 150
local n_ed3 = 12215 - `n_ed1' - `n_ed2' - `n_ed4'
assert `n_ed1' + `n_ed2' + `n_ed3' + `n_ed4' == 12215
assert `n_ed4' >= 100 & `n_ed4' <= 200

* --- Gender: ~45% male, ~55% female (exact counts) ---
local n_male 5497
local n_female 6718
assert `n_male' + `n_female' == 12215

* --- Ethnicity: 92% Han ---
local n_han 11238
local n_min 977
assert `n_han' + `n_min' == 12215

* --- Party / political ID: 57% Youth League, 5% CPC member, 38% non-member ---
local n_p_youth 6963
local n_p_cpc 611
local n_p_mass 4641
assert `n_p_youth' + `n_p_cpc' + `n_p_mass' == 12215

* --- Join motivation (coded via string t0_join_motivation): 60% / 25% / 15% ---
local n_mot1 7329
local n_mot2 3054
local n_mot3 1832
assert `n_mot1' + `n_mot2' + `n_mot3' == 12215

* --- Exam type: TOEFL 40%, IELTS 45%, GRE 10%, GMAT 3%, Other 2% ---
local n_toefl 4886
local n_ielts 5497
local n_gre 1222
local n_gmat 366
local n_exo 244
assert `n_toefl' + `n_ielts' + `n_gre' + `n_gmat' + `n_exo' == 12215

use participant_template.dta, clear
set obs 12215

replace study_id = _n
format study_id %20.0g

label define educ_bl_lbl ///
  1 "Undergraduate (enrolled)" ///
  2 "Bachelor completed" ///
  3 "Master" ///
  4 "Doctorate"

label define age_cat3_lbl ///
  1 "18–21" ///
  2 "22–27" ///
  3 "28–32"

label define party_lbl ///
  1 "Communist Youth League" ///
  2 "CPC member" ///
  3 "Non-member"

set seed `seed'

* --- Baseline demographics (age 18–32; gender; education) — independent of flow_cat ---
* Phase 1 DGP: focus on t0; age slightly dispersed (beta + light tail), not maximal variance
gen int t0_age = .
replace t0_age = floor(18 + 15 * rbeta(1.75, 2.05))
replace t0_age = max(18, min(32, t0_age + round(1.5 * rnormal()))) if runiform() < 0.08
replace t0_age = max(18, min(32, t0_age))
assert t0_age >= 18 & t0_age <= 32

replace t0_age_cat = 1 if t0_age <= 21
replace t0_age_cat = 2 if t0_age >= 22 & t0_age <= 27
replace t0_age_cat = 3 if t0_age >= 28
label values t0_age_cat age_cat3_lbl

gen double _su_g = runiform()
sort _su_g
replace t0_female = 0 in 1/`n_male'
replace t0_female = 1 in `= `n_male' + 1'/L
drop _su_g
sort study_id
label var t0_age "Age in years (baseline)"

gen double _su_ed = runiform()
sort _su_ed
local lo 1
local hi = `lo' + `n_ed1' - 1
replace t0_educ = 1 in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_ed2' - 1
replace t0_educ = 2 in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_ed3' - 1
replace t0_educ = 3 in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_ed4' - 1
replace t0_educ = 4 in `lo'/`hi'
drop _su_ed
sort study_id
label values t0_educ educ_bl_lbl
label var t0_educ "Highest education completed (baseline)"

* Blocking gender aligned with self-reported sex (1=Male 2=Female per block scheme)
replace blk_gender = cond(t0_female == 1, 2, 1)

* --- Ethnicity (92% Han) ---
set seed 20250321
gen double _su_h = runiform()
sort _su_h
replace t0_ethnic_han = 1 in 1/`n_han'
replace t0_ethnic_han = 0 in `= `n_han' + 1'/L
drop _su_h
sort study_id

* --- Party / political identity ---
set seed 202503211
gen double _su_p = runiform()
sort _su_p
local lo 1
local hi = `lo' + `n_p_youth' - 1
replace t0_party_id = 1 in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_p_cpc' - 1
replace t0_party_id = 2 in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_p_mass' - 1
replace t0_party_id = 3 in `lo'/`hi'
drop _su_p
sort study_id
label values t0_party_id party_lbl

* --- Prep length: lognormal-ish (many short, long right tail) clipped 4–78w ---
set seed 202503212
gen double _lw = rnormal(2.88, 0.55)
replace t0_prep_weeks = max(4, min(78, exp(_lw)))
drop _lw
replace t0_prep_weeks = max(4, min(78, t0_prep_weeks + 6*rnormal())) if runiform() < 0.05
label var t0_prep_weeks "Weeks preparing for exam (4–78 weeks)"

* --- Motivation (exact N) ---
set seed 202503213
gen double _su_m = runiform()
sort _su_m
local lo 1
local hi = `lo' + `n_mot1' - 1
replace t0_join_motivation = "Improve English scores" in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_mot2' - 1
replace t0_join_motivation = "Interested in foreign media" in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_mot3' - 1
replace t0_join_motivation = "Other reasons" in `lo'/`hi'
drop _su_m
sort study_id

* --- City of residence: population-weighted draw (see city_weights.csv) ---
* Pool: ~275 prefecture-level units. See city_weights.csv; maintained by build_city_weights.py.
*   Excluded: Xinjiang/Tibet and 5 ethnic autonomous prefectures; weights normalised to TARGET=52624.
* drop placeholder so merge takes city from using (else master empty str wins)
drop t0_city
preserve
import delimited using "city_weights.csv", encoding(utf-8) clear
quietly summarize pop_wan
local sump = r(sum)
gen long n_i = floor(12215 * pop_wan / `sump')
gen double frac = (12215 * pop_wan / `sump') - n_i
egen long totn = total(n_i)
local rem = 12215 - totn[1]
gsort -frac
gen byte add1 = (_n <= `rem')
replace n_i = n_i + add1
drop if n_i < 1
keep city_name n_i
expand n_i
rename city_name t0_city
gen double sortu = runiform()
sort sortu
gen double study_id = _n
keep study_id t0_city
tempfile citytmp
save `citytmp'
restore
merge 1:1 study_id using `citytmp', nogenerate assert(3)
recast strL t0_city
label var t0_city "City/prefecture of residence (population-weighted)"
preserve
contract t0_city, freq(n_city)
gsort -n_city
quietly export delimited using "city_counts.csv", replace
list t0_city n_city, clean noobs abbreviate(20)
restore

* --- Exam type (exact N) ---
set seed 202503214
gen double _su_x = runiform()
sort _su_x
local lo 1
local hi = `lo' + `n_toefl' - 1
replace t0_exam_type = 1 in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_ielts' - 1
replace t0_exam_type = 2 in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_gre' - 1
replace t0_exam_type = 3 in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_gmat' - 1
replace t0_exam_type = 4 in `lo'/`hi'
local lo = `hi' + 1
local hi = `lo' + `n_exo' - 1
replace t0_exam_type = 5 in `lo'/`hi'
drop _su_x
sort study_id

* --- Reading performance: % of max possible for that section; long tail (rbeta) ---
* TOEFL reading 0–30: raw mostly 15–27, right-skewed via rbeta(4,2); score = 100*raw/30
* IELTS reading band ~5–8.5; GRE verbal proxy 130–170; GMAT verbal proxy; Other: generic %
* P(missing score): smooth in prep weeks — no hard cutoff; ~1–2 mo window higher (bump + decay)
set seed 202503215
replace t0_exam_score = .
* Reading proxies: moderate dispersion + modest idiosyncratic noise (tune here first)
replace t0_exam_score = 100 * (15 + 12 * rbeta(2.2, 2.2)) / 30 if t0_exam_type == 1
replace t0_exam_score = 100 * (5 + 3.5 * rbeta(2.0, 2.4)) / 9 if t0_exam_type == 2
replace t0_exam_score = 100 * ( (130 + 40 * rbeta(2.0, 2.2)) - 130) / 40 if t0_exam_type == 3
replace t0_exam_score = 100 * ( (6 + 45 * rbeta(2.0, 2.2)) - 6) / 45 if t0_exam_type == 4
replace t0_exam_score = 100 * rbeta(2.0, 2.8) if t0_exam_type == 5
replace t0_exam_score = max(0, min(100, t0_exam_score + 10*rnormal())) if !mi(t0_exam_score)
replace t0_exam_score = max(0, min(100, t0_exam_score + 16*rnormal())) if !mi(t0_exam_score) & runiform() < 0.04
* indiv. stochastic miss: p(w) = decay + soft bump around ~6w; everyone draws U(0,1)
gen double _pms = 0.38 * exp(-t0_prep_weeks / 26) + 0.12 * exp(-((t0_prep_weeks - 6)^2) / 32)
replace _pms = min(0.62, max(0.02, _pms + 0.06 * (runiform() - 0.5)))
replace t0_exam_score = . if runiform() < _pms
drop _pms
label var t0_exam_score "Most recent exam score, standardized (0–100; missing if not yet taken)"

* ===========================================================================
* B. Media frequency (t0) — latent factor structure
* ---------------------------------------------------------------------------
* Two shared person-level latent factors:
*   _eta_gen: general news consumption propensity (+loads all channels)
*   _eta_pol: ideological orientation (+ = pro-regime, - = liberal)
*             pro-regime -> high freq_state; liberal -> high freq_foreign
*
* Factor loadings (gen, pol) and residual SD per channel:
*   freq_state  : gen=0.30 pol=+0.55 eps_sd=0.780
*   freq_comm   : gen=0.40 pol=+0.10 eps_sd=0.911
*   freq_soc    : gen=0.55 pol=+0.05 eps_sd=0.834
*   freq_foreign: gen=0.30 pol=-0.55 eps_sd=0.780
*   freq_chat   : gen=0.50 pol=+0.15 eps_sd=0.853
*
* Implied cross-channel correlations (theory):
*   state×foreign ≈ -0.21 (ideological substitution — key pattern)
*   soc×chat      ≈ +0.28 (both platform/passive)
*   all others    ≈ +0.07 to +0.23 (general news consumption)
*
* Marginal distributions preserved via invnormal() thresholds:
*   state  : 1~10% 2~10% 3~55% 4~20% 5~5%  mean≈3.00
*   comm   : 1~5%  2~8%  3~45% 4~30% 5~12% mean≈3.36
*   soc    : 1~2%  2~4%  3~20% 4~40% 5~34% mean≈4.00
*   foreign: 1~25% 2~35% 3~25% 4~12% 5~3%  mean≈2.33
*   chat   : 1~8%  2~14% 3~38% 4~28% 5~12% mean≈3.22
* ===========================================================================

set seed 20250327
gen double _eta_gen = rnormal()
gen double _eta_pol = rnormal()

* --- freq_state ---
gen double _z = 0.30*_eta_gen + 0.55*_eta_pol + 0.780*rnormal()
replace t0_freq_state = 1 if _z < invnormal(0.10)
replace t0_freq_state = 2 if _z >= invnormal(0.10) & _z < invnormal(0.20)
replace t0_freq_state = 3 if _z >= invnormal(0.20) & _z < invnormal(0.75)
replace t0_freq_state = 4 if _z >= invnormal(0.75) & _z < invnormal(0.95)
replace t0_freq_state = 5 if _z >= invnormal(0.95)
drop _z

* --- freq_comm ---
gen double _z = 0.40*_eta_gen + 0.10*_eta_pol + 0.911*rnormal()
replace t0_freq_comm = 1 if _z < invnormal(0.05)
replace t0_freq_comm = 2 if _z >= invnormal(0.05) & _z < invnormal(0.13)
replace t0_freq_comm = 3 if _z >= invnormal(0.13) & _z < invnormal(0.58)
replace t0_freq_comm = 4 if _z >= invnormal(0.58) & _z < invnormal(0.88)
replace t0_freq_comm = 5 if _z >= invnormal(0.88)
drop _z

* --- freq_soc ---
gen double _z = 0.55*_eta_gen + 0.05*_eta_pol + 0.834*rnormal()
replace t0_freq_soc = 1 if _z < invnormal(0.02)
replace t0_freq_soc = 2 if _z >= invnormal(0.02) & _z < invnormal(0.06)
replace t0_freq_soc = 3 if _z >= invnormal(0.06) & _z < invnormal(0.26)
replace t0_freq_soc = 4 if _z >= invnormal(0.26) & _z < invnormal(0.66)
replace t0_freq_soc = 5 if _z >= invnormal(0.66)
drop _z

* --- freq_foreign ---
gen double _z = 0.30*_eta_gen + (-0.55)*_eta_pol + 0.780*rnormal()
replace t0_freq_foreign = 1 if _z < invnormal(0.25)
replace t0_freq_foreign = 2 if _z >= invnormal(0.25) & _z < invnormal(0.60)
replace t0_freq_foreign = 3 if _z >= invnormal(0.60) & _z < invnormal(0.85)
replace t0_freq_foreign = 4 if _z >= invnormal(0.85) & _z < invnormal(0.97)
replace t0_freq_foreign = 5 if _z >= invnormal(0.97)
drop _z

* --- freq_chat ---
gen double _z = 0.50*_eta_gen + 0.15*_eta_pol + 0.853*rnormal()
replace t0_freq_chat = 1 if _z < invnormal(0.08)
replace t0_freq_chat = 2 if _z >= invnormal(0.08) & _z < invnormal(0.22)
replace t0_freq_chat = 3 if _z >= invnormal(0.22) & _z < invnormal(0.60)
replace t0_freq_chat = 4 if _z >= invnormal(0.60) & _z < invnormal(0.88)
replace t0_freq_chat = 5 if _z >= invnormal(0.88)
drop _z

tab t0_freq_state
tab t0_freq_comm
tab t0_freq_soc
tab t0_freq_foreign
tab t0_freq_chat

* ===========================================================================
* B2. Media trust (t0) — same latent factors as freq block
* ---------------------------------------------------------------------------
* _eta_gen and _eta_pol already in memory from freq block above.
* Each person's "persona" is thus consistent:
*   high _eta_pol → more state media use AND higher state media trust
*                   less foreign media use AND lower foreign media trust
*
* Factor loadings (gen, pol) — eps_sd = sqrt(1 - gen² - pol²):
*   trust_state  : gen=0.10 pol=+0.55 eps_sd=0.829
*   trust_comm   : gen=0.15 pol=+0.12 eps_sd=0.981
*   trust_soc    : gen=0.30 pol=-0.20 eps_sd=0.933
*   trust_foreign: gen=0.10 pol=-0.55 eps_sd=0.829
*   trust_chat   : gen=0.30 pol=-0.15 eps_sd=0.942
*
* Key implied cross-variable correlations:
*   trust_state × trust_foreign  ≈ -0.29 (ideological mirror of freq)
*   trust_state × freq_state     ≈ +0.33 (use <-> trust same channel)
*   trust_foreign × freq_foreign ≈ +0.33
*   trust_soc   × trust_chat     ≈ +0.12 (both platform-skeptic)
*
* Marginal distributions:
*   trust_state  : 1~8%  2~18% 3~35% 4~28% 5~11% mean≈3.16
*   trust_comm   : 1~7%  2~20% 3~38% 4~27% 5~8%  mean≈3.09
*   trust_soc    : 1~12% 2~28% 3~35% 4~18% 5~7%  mean≈2.80
*   trust_foreign: 1~15% 2~25% 3~33% 4~20% 5~7%  mean≈2.79
*   trust_chat   : 1~14% 2~30% 3~34% 4~17% 5~5%  mean≈2.69
* ===========================================================================

set seed 20250328

* --- trust_state ---
gen double _z = 0.10*_eta_gen + 0.55*_eta_pol + 0.829*rnormal()
replace t0_trust_state = 1 if _z < invnormal(0.08)
replace t0_trust_state = 2 if _z >= invnormal(0.08) & _z < invnormal(0.26)
replace t0_trust_state = 3 if _z >= invnormal(0.26) & _z < invnormal(0.61)
replace t0_trust_state = 4 if _z >= invnormal(0.61) & _z < invnormal(0.89)
replace t0_trust_state = 5 if _z >= invnormal(0.89)
drop _z

* --- trust_comm ---
gen double _z = 0.15*_eta_gen + 0.12*_eta_pol + 0.981*rnormal()
replace t0_trust_comm = 1 if _z < invnormal(0.07)
replace t0_trust_comm = 2 if _z >= invnormal(0.07) & _z < invnormal(0.27)
replace t0_trust_comm = 3 if _z >= invnormal(0.27) & _z < invnormal(0.65)
replace t0_trust_comm = 4 if _z >= invnormal(0.65) & _z < invnormal(0.92)
replace t0_trust_comm = 5 if _z >= invnormal(0.92)
drop _z

* --- trust_soc ---
gen double _z = 0.30*_eta_gen + (-0.20)*_eta_pol + 0.933*rnormal()
replace t0_trust_soc = 1 if _z < invnormal(0.12)
replace t0_trust_soc = 2 if _z >= invnormal(0.12) & _z < invnormal(0.40)
replace t0_trust_soc = 3 if _z >= invnormal(0.40) & _z < invnormal(0.75)
replace t0_trust_soc = 4 if _z >= invnormal(0.75) & _z < invnormal(0.93)
replace t0_trust_soc = 5 if _z >= invnormal(0.93)
drop _z

* --- trust_foreign ---
gen double _z = 0.10*_eta_gen + (-0.55)*_eta_pol + 0.829*rnormal()
replace t0_trust_foreign = 1 if _z < invnormal(0.15)
replace t0_trust_foreign = 2 if _z >= invnormal(0.15) & _z < invnormal(0.40)
replace t0_trust_foreign = 3 if _z >= invnormal(0.40) & _z < invnormal(0.73)
replace t0_trust_foreign = 4 if _z >= invnormal(0.73) & _z < invnormal(0.93)
replace t0_trust_foreign = 5 if _z >= invnormal(0.93)
drop _z

* --- trust_chat ---
gen double _z = 0.30*_eta_gen + (-0.15)*_eta_pol + 0.942*rnormal()
replace t0_trust_chat = 1 if _z < invnormal(0.14)
replace t0_trust_chat = 2 if _z >= invnormal(0.14) & _z < invnormal(0.44)
replace t0_trust_chat = 3 if _z >= invnormal(0.44) & _z < invnormal(0.78)
replace t0_trust_chat = 4 if _z >= invnormal(0.78) & _z < invnormal(0.95)
replace t0_trust_chat = 5 if _z >= invnormal(0.95)
drop _z

* _eta_gen/_eta_pol retained for attitude block (rs/cen/nat)
tab t0_trust_state
tab t0_trust_comm
tab t0_trust_soc
tab t0_trust_foreign
tab t0_trust_chat

* --- t0_news_foreign_30d: foreign news by any channel, past 30 days ---
* Broader than freq_foreign but 4+5 kept modest (10%+4%)
* Target: 1~22%, 2~35%, 3~28%, 4~11%, 5~4% => mean ≈ 2.40
* Loadings: gen=0.30, pol=-0.50, eps_sd=0.812
set seed 20250329
gen double _z = 0.30*_eta_gen + (-0.50)*_eta_pol + 0.812*rnormal()
replace t0_news_foreign_30d = 1 if _z < invnormal(0.22)
replace t0_news_foreign_30d = 2 if _z >= invnormal(0.22) & _z < invnormal(0.57)
replace t0_news_foreign_30d = 3 if _z >= invnormal(0.57) & _z < invnormal(0.85)
replace t0_news_foreign_30d = 4 if _z >= invnormal(0.85) & _z < invnormal(0.96)
replace t0_news_foreign_30d = 5 if _z >= invnormal(0.96)
drop _z

tab t0_news_foreign_30d

* ===========================================================================
* B3. Platform use (t0) — binary probit with shared latent factors
* ---------------------------------------------------------------------------
* Foreign platforms require VPN in mainland China.
* All negatively load on _eta_pol (pro-regime -> less foreign platform use)
* and positively on _eta_gen; positive cross-platform correlations (~0.20)
* via shared factor loadings.
*
* Ranking by % Yes: ig(40%) > fb(32%) > yt(28%) > tw(20%) > tiktok(8%)
* Loadings:  ig: gen=0.20 pol=-0.40 eps_sd=0.894
*            fb: gen=0.20 pol=-0.40 eps_sd=0.894
*            yt: gen=0.20 pol=-0.38 eps_sd=0.904
*            tw: gen=0.15 pol=-0.45 eps_sd=0.881
*         tiktok: gen=0.15 pol=-0.15 eps_sd=0.977
* threshold = invnormal(1 - p) so P(z >= threshold) = p
* ===========================================================================

set seed 20250330

* --- Instagram ---
gen double _z = 0.20*_eta_gen + (-0.40)*_eta_pol + 0.894*rnormal()
replace t0_plat_ig = (_z >= invnormal(0.60))
drop _z

* --- Facebook ---
gen double _z = 0.20*_eta_gen + (-0.40)*_eta_pol + 0.894*rnormal()
replace t0_plat_fb = (_z >= invnormal(0.68))
drop _z

* --- YouTube ---
gen double _z = 0.20*_eta_gen + (-0.38)*_eta_pol + 0.904*rnormal()
replace t0_plat_yt = (_z >= invnormal(0.72))
drop _z

* --- Twitter/X ---
gen double _z = 0.15*_eta_gen + (-0.45)*_eta_pol + 0.881*rnormal()
replace t0_plat_tw = (_z >= invnormal(0.80))
drop _z

* --- TikTok (international) ---
gen double _z = 0.15*_eta_gen + (-0.15)*_eta_pol + 0.977*rnormal()
replace t0_plat_tiktok = (_z >= invnormal(0.92))
drop _z

tab t0_plat_ig
tab t0_plat_fb
tab t0_plat_yt
tab t0_plat_tw
tab t0_plat_tiktok

* --- t0_abroad_ever: ever been outside mainland China ---
* ~35% Yes; internationally-oriented (low eta_pol) more likely
* Loadings: gen=0.10, pol=-0.35, eps_sd = sqrt(1-0.01-0.1225) = 0.938
* threshold = invnormal(0.65) so P(z >= threshold) ≈ 0.35
set seed 20250331
gen double _z = 0.10*_eta_gen + (-0.35)*_eta_pol + 0.938*rnormal()
replace t0_abroad_ever = (_z >= invnormal(0.65))
drop _z

tab t0_abroad_ever

* --- Regional economic development level (auxiliary, all 12,215) ---
* 0 = less developed (West ~25%), 1 = mid (Central ~35%), 2 = developed (East ~40%)
* Used in abroad_plan DGP; reflects city/province economic tier
set seed 20250332
gen double _u = runiform()
gen byte _eco = 0
replace _eco = 1 if _u >= 0.25 & _u < 0.60
replace _eco = 2 if _u >= 0.60
drop _u

* --- t0_abroad_plan: plans to study/live abroad ---
* Ordered 1 (Definitely yes) to 4 (Definitely not); test-prep cohort → heavy 1+2
* Target: 1~38%, 2~47%, 3~10%, 4~5% => mean ≈ 1.82
* Drivers:
*   _eta_pol (+): pro-regime orientation → more 3/4 (stay)
*   _eco    (-): developed region → more 1/2 (go abroad); _eco centered at 1
* z ~ approx N(0,1): var ≈ 0.40²+0.20²*0.63+0.90² ≈ 1.0
set seed 20250332
gen double _z = 0.40*_eta_pol - 0.20*(_eco - 1) + 0.90*rnormal()
replace t0_abroad_plan = 1 if _z < invnormal(0.38)
replace t0_abroad_plan = 2 if _z >= invnormal(0.38) & _z < invnormal(0.85)
replace t0_abroad_plan = 3 if _z >= invnormal(0.85) & _z < invnormal(0.95)
replace t0_abroad_plan = 4 if _z >= invnormal(0.95)
drop _z _eco

tab t0_abroad_plan

* ===========================================================================
* FUNNEL: answer survey → QC screen → consent (recruited) → endline → followup
* ---------------------------------------------------------------------------
* recruited = 1  if person clicked consent button (N=6,365)
* Drivers: QC quality + abroad intent + noise
*   QC fail (att_pass=0 | straightline=1) → large negative → unlikely recruited
*   abroad_plan=1 (Definitely yes) → higher score → more likely recruited
* Within recruited: endline (5,215) and followup (2,115) randomly assigned
* ===========================================================================

set seed 20250405

* Step 1: QC variables (unconditional, before recruitment)
replace t0_att_pass          = (runiform() >= 0.062)   // ~6.2% fail
replace t0_straightline_flag = (runiform() < 0.037)    // ~3.7% flagged

* Step 2: selection score → sort → top 6,365 become recruited
gen byte   _qc_bad = (t0_att_pass == 0 | t0_straightline_flag == 1)
gen double _sel    = -8.0 * _qc_bad              ///
                   + 1.5  * (4 - t0_abroad_plan) ///
                   + rnormal(0, 3)
drop _qc_bad

sort _sel
replace recruited = 0 in 1/`=12215-`n_recruited''
replace recruited = 1 in `=12215-`n_recruited'+1'/12215
sort study_id
drop _sel

* Step 3: within recruited, randomly assign endline and followup completion
set seed `seed'
gen double _u = runiform() if recruited == 1
sort recruited _u
replace complete_endline  = 0 if recruited == 1
replace complete_endline  = 1 in `=12215-`n_endline'+1'/12215
replace complete_followup = 0 if complete_endline == 1
replace complete_followup = 1 in `=12215-`n_followup'+1'/12215
sort study_id
drop _u

replace complete_baseline = 1
replace any_weekly_data   = (recruited == 1)
replace last_week_active  = 12 if complete_endline == 1
set seed `seed'
replace last_week_active = max(1, min(11, ceil(11 * runiform()))) ///
    if recruited == 1 & complete_endline == 0


* (funnel variables set in FUNNEL block above)

* --- Six arms: exact sizes 1061+1061+1061+1061+1061+1060 = 6,365 ---
* Use a random shuffle within recruited (NOT study_id order) to ensure balance
gen int _rid = .
set seed 20250410
gen double _rnd_arm = runiform() if recruited == 1
sort recruited _rnd_arm
by recruited: replace _rid = _n if recruited == 1
drop _rnd_arm

replace arm = 1 if recruited == 1 & _rid >= 1   & _rid <= 1061
replace arm = 2 if _rid >= 1062 & _rid <= 2122
replace arm = 3 if _rid >= 2123 & _rid <= 3183
replace arm = 4 if _rid >= 3184 & _rid <= 4244
replace arm = 5 if _rid >= 4245 & _rid <= 5305
replace arm = 6 if _rid >= 5306 & _rid <= 6365
drop _rid

set seed `seed'
replace block_id = ceil(24 * runiform()) if recruited == 1
replace blk_region = 1 + floor(3 * runiform()) if recruited == 1
replace blk_eng_hi = 1 + (runiform() < 0.5) if recruited == 1
replace blk_nat_hi = 1 + (runiform() < 0.5) if recruited == 1

* --- Optional calendar months (teaching) ---
replace date_baseline_m = ym(2025, 6)
replace date_rand_m = ym(2025, 6) if recruited == 1
replace date_endline_m = ym(2025, 8) if complete_endline
replace date_followup_m = ym(2025, 11) if complete_followup

* ===========================================================================
* C. Attitude batteries (t0) — all driven by _eta_pol from media block
* ---------------------------------------------------------------------------
* _eta_pol (+) = pro-regime/nationalist orientation
*   → higher regime support, more pro-censorship, more nationalist
*   → consistent with lower freq_foreign, lower trust_foreign, no foreign platforms
*
* Regime support 5 items: satisfaction 1(low)–5(high)
* Items differ in baseline level; all share pol loading = 0.60
*   rs_econ : mean≈3.5 (economic growth widely acknowledged)
*   rs_stab : mean≈3.3
*   rs_eq   : mean≈2.9 (inequality widely felt)
*   rs_tech : mean≈3.8 (tech pride cuts across ideology)
*   rs_gov  : mean≈3.1
* Loadings: gen=0.05, pol=0.60, eps_sd=0.799
* Cor(any two items) ≈ 0.05²+0.60² = 0.3625 (correlated battery, realistic)
* ===========================================================================

set seed 20250401

* --- rs_econ: satisfaction with economic development ---
gen double _z = 0.05*_eta_gen + 0.60*_eta_pol + 0.799*rnormal()
replace t0_rs_econ = 1 if _z < invnormal(0.05)
replace t0_rs_econ = 2 if _z >= invnormal(0.05) & _z < invnormal(0.17)
replace t0_rs_econ = 3 if _z >= invnormal(0.17) & _z < invnormal(0.47)
replace t0_rs_econ = 4 if _z >= invnormal(0.47) & _z < invnormal(0.82)
replace t0_rs_econ = 5 if _z >= invnormal(0.82)
drop _z

* --- rs_stab: satisfaction with social stability ---
gen double _z = 0.05*_eta_gen + 0.60*_eta_pol + 0.799*rnormal()
replace t0_rs_stab = 1 if _z < invnormal(0.07)
replace t0_rs_stab = 2 if _z >= invnormal(0.07) & _z < invnormal(0.22)
replace t0_rs_stab = 3 if _z >= invnormal(0.22) & _z < invnormal(0.57)
replace t0_rs_stab = 4 if _z >= invnormal(0.57) & _z < invnormal(0.87)
replace t0_rs_stab = 5 if _z >= invnormal(0.87)
drop _z

* --- rs_eq: satisfaction with social equality ---
gen double _z = 0.05*_eta_gen + 0.60*_eta_pol + 0.799*rnormal()
replace t0_rs_eq = 1 if _z < invnormal(0.12)
replace t0_rs_eq = 2 if _z >= invnormal(0.12) & _z < invnormal(0.37)
replace t0_rs_eq = 3 if _z >= invnormal(0.37) & _z < invnormal(0.72)
replace t0_rs_eq = 4 if _z >= invnormal(0.72) & _z < invnormal(0.92)
replace t0_rs_eq = 5 if _z >= invnormal(0.92)
drop _z

* --- rs_tech: satisfaction with technological progress ---
gen double _z = 0.05*_eta_gen + 0.60*_eta_pol + 0.799*rnormal()
replace t0_rs_tech = 1 if _z < invnormal(0.03)
replace t0_rs_tech = 2 if _z >= invnormal(0.03) & _z < invnormal(0.11)
replace t0_rs_tech = 3 if _z >= invnormal(0.11) & _z < invnormal(0.36)
replace t0_rs_tech = 4 if _z >= invnormal(0.36) & _z < invnormal(0.74)
replace t0_rs_tech = 5 if _z >= invnormal(0.74)
drop _z

* --- rs_gov: satisfaction with government efficiency ---
gen double _z = 0.05*_eta_gen + 0.60*_eta_pol + 0.799*rnormal()
replace t0_rs_gov = 1 if _z < invnormal(0.10)
replace t0_rs_gov = 2 if _z >= invnormal(0.10) & _z < invnormal(0.30)
replace t0_rs_gov = 3 if _z >= invnormal(0.30) & _z < invnormal(0.65)
replace t0_rs_gov = 4 if _z >= invnormal(0.65) & _z < invnormal(0.92)
replace t0_rs_gov = 5 if _z >= invnormal(0.92)
drop _z

* Index: mean of 5 items, standardized (SD≈1 by construction)
egen _rsm = rowmean(t0_rs_econ t0_rs_stab t0_rs_eq t0_rs_tech t0_rs_gov)
replace t0_rs_index = (_rsm - 3.12) / 0.62
drop _rsm

tab t0_rs_econ
tab t0_rs_stab
tab t0_rs_eq
tab t0_rs_tech
tab t0_rs_gov
summarize t0_rs_index

* ===========================================================================
* C2. Censorship attitudes (t0)
* ---------------------------------------------------------------------------
* Items: 1(strongly disagree) – 5(strongly agree)
*   cen_stab : restricting content is necessary for stability  mean≈3.4
*   cen_prot : protect citizens from disordering info          mean≈3.3
*   cen_right: government has right to censor sensitive news   mean≈3.1
*
* Loadings: gen=0.05, pol=0.65, eps_sd=0.758  (stronger pol than rs)
* Key implied correlations (via shared _eta_pol):
*   cen × rs_index     ≈ +0.39  (pro-regime → pro-censorship)
*   cen × freq_foreign ≈ −0.36  (foreign media use → anti-censorship)
*   cen × trust_foreign≈ −0.36
*   within-battery (cen_stab × cen_right) ≈ 0.65² = 0.42
* ===========================================================================

set seed 20250402

* --- cen_stab: restricting content for stability ---
gen double _z = 0.05*_eta_gen + 0.65*_eta_pol + 0.758*rnormal()
replace t0_cen_stab = 1 if _z < invnormal(0.07)
replace t0_cen_stab = 2 if _z >= invnormal(0.07) & _z < invnormal(0.20)
replace t0_cen_stab = 3 if _z >= invnormal(0.20) & _z < invnormal(0.50)
replace t0_cen_stab = 4 if _z >= invnormal(0.50) & _z < invnormal(0.82)
replace t0_cen_stab = 5 if _z >= invnormal(0.82)
drop _z

* --- cen_prot: protect citizens from disordering info ---
gen double _z = 0.05*_eta_gen + 0.65*_eta_pol + 0.758*rnormal()
replace t0_cen_prot = 1 if _z < invnormal(0.08)
replace t0_cen_prot = 2 if _z >= invnormal(0.08) & _z < invnormal(0.24)
replace t0_cen_prot = 3 if _z >= invnormal(0.24) & _z < invnormal(0.55)
replace t0_cen_prot = 4 if _z >= invnormal(0.55) & _z < invnormal(0.85)
replace t0_cen_prot = 5 if _z >= invnormal(0.85)
drop _z

* --- cen_right: government has right to censor ---
gen double _z = 0.05*_eta_gen + 0.65*_eta_pol + 0.758*rnormal()
replace t0_cen_right = 1 if _z < invnormal(0.10)
replace t0_cen_right = 2 if _z >= invnormal(0.10) & _z < invnormal(0.30)
replace t0_cen_right = 3 if _z >= invnormal(0.30) & _z < invnormal(0.62)
replace t0_cen_right = 4 if _z >= invnormal(0.62) & _z < invnormal(0.88)
replace t0_cen_right = 5 if _z >= invnormal(0.88)
drop _z

* Index: mean of 3 items, standardized
egen _cenm = rowmean(t0_cen_stab t0_cen_prot t0_cen_right)
replace t0_cen_index = (_cenm - 3.27) / 0.82
drop _cenm

tab t0_cen_stab
tab t0_cen_prot
tab t0_cen_right
summarize t0_cen_index

* ===========================================================================
* C3. Nationalism battery (t0)
* ---------------------------------------------------------------------------
* Items: 1(strongly disagree) – 5(strongly agree)
*   nat_proud  : proud when China praised internationally      mean≈4.1
*   nat_bias   : foreign criticism usually biased              mean≈3.7
*   nat_unfair : Western countries judge China unfairly        mean≈3.5
*   nat_resist : resist outside pressure                       mean≈3.4
*
* nat_proud has weaker pol loading (near-universal pride, ideologically diffuse)
* nat_resist has strongest pol loading (most confrontational)
*
* Implied correlations (via _eta_pol):
*   nat_resist × nat_bias  ≈ 0.65×0.60 = 0.39
*   nat_proud  × nat_resist≈ 0.35×0.65 = 0.23  (lower — pride is more universal)
*   nat_* × rs_index       ≈ +0.21–0.39
*   nat_* × freq_foreign   ≈ −0.19–−0.36
*   nat_* × trust_foreign  ≈ −0.19–−0.36
*
* drop _eta_gen/_eta_pol after this block (no longer needed)
* ===========================================================================

set seed 20250403

* --- nat_proud: proud when China praised internationally ---
* Near-universal, mean≈4.1; pol=0.35, gen=0.05, eps_sd=0.935
gen double _z = 0.05*_eta_gen + 0.35*_eta_pol + 0.935*rnormal()
replace t0_nat_proud = 1 if _z < invnormal(0.02)
replace t0_nat_proud = 2 if _z >= invnormal(0.02) & _z < invnormal(0.07)
replace t0_nat_proud = 3 if _z >= invnormal(0.07) & _z < invnormal(0.25)
replace t0_nat_proud = 4 if _z >= invnormal(0.25) & _z < invnormal(0.60)
replace t0_nat_proud = 5 if _z >= invnormal(0.60)
drop _z

* --- nat_bias: foreign criticism usually biased ---
* mean≈3.7; pol=0.60, gen=0.05, eps_sd=0.799
gen double _z = 0.05*_eta_gen + 0.60*_eta_pol + 0.799*rnormal()
replace t0_nat_bias = 1 if _z < invnormal(0.04)
replace t0_nat_bias = 2 if _z >= invnormal(0.04) & _z < invnormal(0.12)
replace t0_nat_bias = 3 if _z >= invnormal(0.12) & _z < invnormal(0.36)
replace t0_nat_bias = 4 if _z >= invnormal(0.36) & _z < invnormal(0.72)
replace t0_nat_bias = 5 if _z >= invnormal(0.72)
drop _z

* --- nat_unfair: Western countries judge China unfairly ---
* mean≈3.5; pol=0.58, gen=0.05, eps_sd=0.814
gen double _z = 0.05*_eta_gen + 0.58*_eta_pol + 0.814*rnormal()
replace t0_nat_unfair = 1 if _z < invnormal(0.05)
replace t0_nat_unfair = 2 if _z >= invnormal(0.05) & _z < invnormal(0.15)
replace t0_nat_unfair = 3 if _z >= invnormal(0.15) & _z < invnormal(0.43)
replace t0_nat_unfair = 4 if _z >= invnormal(0.43) & _z < invnormal(0.78)
replace t0_nat_unfair = 5 if _z >= invnormal(0.78)
drop _z

* --- nat_resist: should resist outside pressure ---
* mean≈3.4; pol=0.65, gen=0.05, eps_sd=0.758 (strongest partisan loading)
gen double _z = 0.05*_eta_gen + 0.65*_eta_pol + 0.758*rnormal()
replace t0_nat_resist = 1 if _z < invnormal(0.06)
replace t0_nat_resist = 2 if _z >= invnormal(0.06) & _z < invnormal(0.18)
replace t0_nat_resist = 3 if _z >= invnormal(0.18) & _z < invnormal(0.48)
replace t0_nat_resist = 4 if _z >= invnormal(0.48) & _z < invnormal(0.80)
replace t0_nat_resist = 5 if _z >= invnormal(0.80)
drop _z

* Index: mean of 4 items, standardized
egen _natm = rowmean(t0_nat_bias t0_nat_resist t0_nat_proud t0_nat_unfair)
replace t0_nat_index = (_natm - 3.68) / 0.72
drop _natm

* Release latent factors — no longer needed
drop _eta_gen _eta_pol

tab t0_nat_proud
tab t0_nat_bias
tab t0_nat_unfair
tab t0_nat_resist
summarize t0_nat_index

* ===========================================================================
* C4. Feeling thermometers (t0) — 0–100 continuous
* ---------------------------------------------------------------------------
* therm_cn  : feelings toward China         mean≈75  SD≈14
* therm_west: feelings toward Western demo  mean≈58  SD≈17
* therm_gap : China minus West (derived)    mean≈17
*
* Use t0_rs_index as ideological anchor (already in data; _eta_pol dropped):
*   therm_cn  = 75 + 8*rs_index + 10*ε  clipped [0,100]
*   therm_west= 58 - 7*rs_index + 12*ε  clipped [0,100]
* Implied correlations:
*   therm_cn  × rs_index ≈ +0.45
*   therm_west × rs_index≈ −0.37
*   therm_cn  × therm_west≈ −0.31
* ===========================================================================

set seed 20250404
replace t0_therm_cn   = max(0, min(100, 75 + 8*t0_rs_index + 10*rnormal()))
replace t0_therm_west = max(0, min(100, 60 - 7*t0_rs_index + 12*rnormal()))
replace t0_therm_gap  = t0_therm_cn - t0_therm_west

summarize t0_therm_cn t0_therm_west t0_therm_gap

* ===========================================================================
* D. Submission timestamp (t0_ts_submit)
* ---------------------------------------------------------------------------
* QC variables already generated in funnel block above.
* Timestamp: June 2025, evening peak (19:00 ± 2h), uniform across days 1–30.
* ===========================================================================

local ts_lo  = clock("01jun2025 00:00:00", "DMYhms")
local day_sec = 86400000
local eve_mid = 68400000
local eve_sd  =  7200000
replace t0_ts_submit = `ts_lo'                                          ///
    + floor(29 * runiform()) * `day_sec'                                ///
    + max(25200000, min(82800000, `eve_mid' + `eve_sd' * rnormal()))
format t0_ts_submit %tc

* QC summary by flow_cat (verification)
tab t0_att_pass
tab t0_straightline_flag
tab recruited t0_att_pass, row nofreq

* ===========================================================================
* T1 ENDLINE OUTCOMES  (complete_endline == 1; N = 5,215)
* ---------------------------------------------------------------------------
* DGP:  t1_Y = t0_Y  +  τ_arm(Y)  +  β_HTE × t0_nat_index × I(pol.arm)  +  ε
*
* Treatment shifts (τ) on a standardised latent scale (mean 0 SD 1):
*   Arm 1 Pro low   : +0.10    Arm 3 Anti low   : −0.12
*   Arm 2 Pro high  : +0.18    Arm 4 Anti high  : −0.22
*   Arm 5 Apolitical: +0.02    Arm 6 Control    :  0.00  (reference)
*
* Heterogeneous treatment effects (HTE) via baseline nationalism (t0_nat_index):
*   Anti-China × nationalist (nat>0) → backlash: +β × nat   (rs, nat go UP)
*   Pro-China  × liberal     (nat<0) → scepticism:−β × |nat| (trust_foreign DOWN)
*
* Key hypothesis-consistent patterns:
*   H1: Anti-China ↓ regime support (on average); polarises by prior nationalism
*   H2: Pro-China ↑ trust in foreign media (costly-signal effect)
*   H3: Apol. ≠ control on China thermometer
*   H4: High dose > low dose in magnitude
*   H5: Dissonant high-dose: trust_foreign ↓ for nationalists in arm 4
* ===========================================================================

set seed 20250501

* ── 1. Arm-level treatment shift scalars ─────────────────────────────────────
* _tau: arm-level latent shift for rs/cen batteries
* Calibrated so that within-valence dose contrast (arm2-arm1, arm4-arm3) is **:
*   arm2-arm1 diff ≈ 0.13 SD → t≈2.4 **
*   arm4-arm3 diff ≈ 0.14 SD → t≈2.6 **
*   vs control: arm1 NS, arm2 ***, arm3 *, arm4 ***
gen double _tau = 0 if complete_endline == 1
replace _tau =  0.07 if arm == 1 & complete_endline == 1   // low dose: NS vs ctrl
replace _tau =  0.20 if arm == 2 & complete_endline == 1   // high dose: *** vs ctrl
replace _tau = -0.12 if arm == 3 & complete_endline == 1   // low dose: * vs ctrl
replace _tau = -0.26 if arm == 4 & complete_endline == 1   // high dose: *** vs ctrl
replace _tau =  0.02 if arm == 5 & complete_endline == 1

* ── 2. Regime support — items (for data richness) + index DIRECT (for HTE) ────
* Items still generated for descriptive use; index overridden directly below.
* Items: moderate noise so individual items are realistic
gen double _hte_rs = 0 if complete_endline == 1
replace _hte_rs =  0.20 * t0_nat_index if inlist(arm,3,4) & complete_endline==1
replace _hte_rs =  0.08 * t0_nat_index if inlist(arm,1,2) & complete_endline==1

gen double _s_rs = _tau + _hte_rs
foreach v in t0_rs_econ t0_rs_stab t0_rs_eq t0_rs_tech t0_rs_gov {
    local t1v = subinstr("`v'", "t0_", "t1_", 1)
    replace `t1v' = max(1, min(5, round(`v' + 0.6*_s_rs + 0.30*rnormal()))) ///
        if complete_endline == 1
}
drop _hte_rs _s_rs

* ===========================================================================
* t1_rs_index DIRECT — calibrated with explicit HTE terms
* ---------------------------------------------------------------------------
* Three moderators built in:
*   (A) Backlash HTE: anti-China × t0_nat_index (+0.15 arm4, +0.10 arm3)
*       → nationalists show LESS negative (or even positive) rs change
*       Expected t ≈ 2.9** (arm4) and 1.9* (arm3)
*   (B) Compliance HTE: arm × exam_z (attention amplifies effect)
*       → high-attention arm4 participants show LARGER rs decrease
*       Expected t ≈ 2.2* (arm4)
*   (C) Pro-China × nat: nationalists respond more (pro-China reinforces rs)
*       arm2×nat = 0.08 → t≈1.6 (borderline)
* Noise 0.55*rnormal() reduces test-retest from 0.979 to ~0.89
* (more realistic; SE_int ≈ 0.051; SE_main ≈ 0.029)
* ===========================================================================

* Exam-score z-score (proxy for attention/compliance)
gen double _exam_z = cond(mi(t0_exam_score), 0, (t0_exam_score - 53)/22)

gen double _d_rs = _tau if complete_endline == 1
* (A) Backlash HTE
replace _d_rs = _d_rs + 0.15*t0_nat_index if inlist(arm,3,4) & complete_endline==1
replace _d_rs = _d_rs + 0.08*t0_nat_index if inlist(arm,1,2) & complete_endline==1
* (B) Compliance HTE (attention amplifies anti-China persuasion)
replace _d_rs = _d_rs - 0.18*_exam_z if arm==4 & complete_endline==1
replace _d_rs = _d_rs - 0.10*_exam_z if arm==3 & complete_endline==1
replace _d_rs = _d_rs + 0.08*_exam_z if arm==2 & complete_endline==1

replace t1_rs_index = t0_rs_index + _d_rs + 0.55*rnormal() if complete_endline==1
drop _d_rs

* ── 3. Censorship attitudes  (3 items + index) ───────────────────────────────
* Follows rs direction: pro-China → slightly more pro-censorship; anti → less
gen double _s_cen = 0.55 * _tau if complete_endline == 1   // weaker than rs

foreach v in t0_cen_stab t0_cen_prot t0_cen_right {
    local t1v = subinstr("`v'", "t0_", "t1_", 1)
    replace `t1v' = max(1, min(5, round(`v' + 0.6*_s_cen + 0.30*rnormal()))) ///
        if complete_endline == 1
}
drop _s_cen

* cen_index: direct generation for calibration (avoids quantization attenuation).
* Target: arm4 *(−0.07 SD); arm1/2/3/5 NS
gen double _d_cen = 0 if complete_endline == 1
replace _d_cen =  0.04 if arm==1 & complete_endline==1
replace _d_cen =  0.05 if arm==2 & complete_endline==1
replace _d_cen = -0.04 if arm==3 & complete_endline==1
replace _d_cen = -0.09 if arm==4 & complete_endline==1
replace t1_cen_index = t0_cen_index + _d_cen + 0.65*rnormal() if complete_endline==1
drop _d_cen

* ── 4. Nationalism  (4 items + index) ────────────────────────────────────────
* Anti-China → backlash for nationalists (nat_index goes UP)
* Pro-China  → slight nationalism rise (pride when West acknowledges China)
gen double _hte_nat = 0 if complete_endline == 1
replace _hte_nat = 0.25 * t0_nat_index if inlist(arm,3,4) & complete_endline==1
replace _hte_nat = 0.05 * t0_nat_index if inlist(arm,1,2) & complete_endline==1

gen double _s_nat = 0 if complete_endline == 1
replace _s_nat =  0.06 if inlist(arm,1,2) & complete_endline == 1   // pro → slight nat up
replace _s_nat =  0.10 if inlist(arm,3,4) & complete_endline == 1   // anti → backlash (avg)
replace _s_nat = _s_nat + _hte_nat
drop _hte_nat

foreach v in t0_nat_bias t0_nat_resist t0_nat_proud t0_nat_unfair {
    local t1v = subinstr("`v'", "t0_", "t1_", 1)
    replace `t1v' = max(1, min(5, round(`v' + 0.6*_s_nat + 0.30*rnormal()))) ///
        if complete_endline == 1
}
drop _s_nat

* nat_index: generated DIRECTLY to avoid quantization attenuation from items.
* Items above are kept for descriptive richness; index drives the analysis.
* Target net effects vs control: arm1 NS(+0.04), arm2 *(+0.07),
*   arm3 *(+0.06 + 0.22×nat), arm4 **(+0.12 + 0.28×nat), arm5 NS(+0.02)
gen double _d_nat = 0 if complete_endline == 1
replace _d_nat = 0.04                      if arm==1 & complete_endline==1
replace _d_nat = 0.07                      if arm==2 & complete_endline==1
replace _d_nat = 0.06 + 0.22*t0_nat_index if arm==3 & complete_endline==1  // backlash HTE
replace _d_nat = 0.12 + 0.28*t0_nat_index if arm==4 & complete_endline==1  // strong backlash HTE
replace _d_nat = 0.02                      if arm==5 & complete_endline==1
replace t1_nat_index = t0_nat_index + _d_nat + 0.60*rnormal() if complete_endline==1
drop _d_nat

* ── 5. Feeling thermometers ───────────────────────────────────────────────────
* Pro-China → China thermometer up, West up slightly (costly signal)
*             → gap narrows (−3 / −5 pts for lo/hi dose)
* Anti-China → West thermometer down for nationalists (backlash: gap widens)
gen double _s_therm_cn   = 0 if complete_endline == 1
gen double _s_therm_west = 0 if complete_endline == 1

replace _s_therm_cn   =  3  if arm == 1 & complete_endline == 1
replace _s_therm_cn   =  5  if arm == 2 & complete_endline == 1
replace _s_therm_cn   = -2  if arm == 3 & complete_endline == 1
replace _s_therm_cn   = -4  if arm == 4 & complete_endline == 1
replace _s_therm_west =  4  if arm == 1 & complete_endline == 1   // costly signal
replace _s_therm_west =  7  if arm == 2 & complete_endline == 1
replace _s_therm_west = -3 * (t0_nat_index > 0) + 2*(t0_nat_index < 0) ///
    if arm == 3 & complete_endline == 1
replace _s_therm_west = -5 * (t0_nat_index > 0) + 3*(t0_nat_index < 0) ///
    if arm == 4 & complete_endline == 1

replace t1_therm_cn   = max(0, min(100, t0_therm_cn   + _s_therm_cn   + 8*rnormal())) ///
    if complete_endline == 1
replace t1_therm_west = max(0, min(100, t0_therm_west + _s_therm_west + 9*rnormal())) ///
    if complete_endline == 1
replace t1_therm_gap  = t1_therm_cn - t1_therm_west if complete_endline == 1
drop _s_therm_cn _s_therm_west

* ── 6. Media trust  (5 items; 1–5 Likert) ────────────────────────────────────
* trust_foreign: KEY outcome — pro-China arm → RISES (costly signal H2)
*               anti × nat → dismissal (falls); anti × liberal → rises

* trust_foreign: KEY costly-signal outcome (H2)
*   Calibrated to produce t ≈ 4–6 at t1 (not trivially significant)
*   Target net effects vs control: arm1 ≈ +0.12 pts, arm2 ≈ +0.22 pts (1–5 scale)
*   t1: arm1 *, arm2 ***;   t2: arm2 * (persists), arm1 borderline
* ===========================================================================
* trust_foreign: pro-China costly-signal with three HTE moderators
* ---------------------------------------------------------------------------
*   (A) Ideology (nat_index): pro-China × nat<0 (liberals) → LARGER trust rise
*       Nationalists already trust state media; pro-China from West is less novel
*       arm2 × nat: -0.16 → t≈3.0** (nat<0 shows bigger increase)
*   (B) Prior foreign exposure: arm2 × t0_freq_foreign_z → LARGER effect
*       People who already consume foreign media appreciate the credibility signal more
*       arm2 × freq_foreign: +0.14 → t≈2.6**
*   (C) Attention (exam_z): arm2 × exam_z → MORE attentive → larger shift
*       arm2 × exam_z: +0.12 → t≈2.3*
* ===========================================================================

* Centre freq_foreign for interaction
gen double _ff_z = t0_freq_foreign - 2.33    // centred at mean (~2.33)

gen double _s_tf = 0 if complete_endline == 1
replace _s_tf =  0.15 if arm == 1 & complete_endline == 1   // low dose base
replace _s_tf =  0.45 if arm == 2 & complete_endline == 1   // high dose base
replace _s_tf = -0.10 if arm == 3 & complete_endline == 1
replace _s_tf = -0.18 if arm == 4 & complete_endline == 1

* (A) Ideology HTE: pro × nat → liberal benefits more
replace _s_tf = _s_tf - 0.40 * t0_nat_index if inlist(arm,1,2) & complete_endline==1
replace _s_tf = _s_tf - 0.10 * t0_nat_index if inlist(arm,3,4) & complete_endline==1
* (B) Prior exposure HTE: more foreign media use → stronger credibility shift
replace _s_tf = _s_tf + 0.14 * _ff_z if arm==2 & complete_endline==1
replace _s_tf = _s_tf + 0.08 * _ff_z if arm==1 & complete_endline==1
* (C) Attention HTE: more attentive readers → stronger trust shift for pro-China
replace _s_tf = _s_tf + 0.12 * _exam_z if arm==2 & complete_endline==1

replace t1_trust_foreign = max(1, min(5, round(t0_trust_foreign + 0.5*_s_tf + 0.65*rnormal()))) ///
    if complete_endline == 1
drop _s_tf _ff_z

* trust_state: slight positive for pro-China arms (more state–foreign alignment)
replace t1_trust_state = max(1, min(5, round(t0_trust_state - 0.12*_tau + 0.55*rnormal()))) ///
    if complete_endline == 1

* trust_comm, trust_soc, trust_chat: no arm effect; measurement noise only
foreach v in t0_trust_comm t0_trust_soc t0_trust_chat {
    local t1v = subinstr("`v'", "t0_", "t1_", 1)
    replace `t1v' = max(1, min(5, round(`v' + 0.55*rnormal()))) ///
        if complete_endline == 1
}

* ── 7. Difference scores ─────────────────────────────────────────────────────
drop _tau

drop _exam_z

* ── 8. WTP: behavioral demand for continued foreign-news access ───────────────
* BDM mechanism: bid = stated max WTP; draw = random price; buy = (draw <= bid)
* H5: Pro-China high dose → HIGHER bid (credibility signal → higher demand)
*     Anti-China high dose → LOWER bid (dissonant exposure suppresses demand)
* Drivers: treatment arm, w_mean_similar (weekly behavioral demand ratings),
*          t0_freq_foreign (prior exposure), and idiosyncratic noise.
* ===========================================================================

set seed 20250601

* Arm-level WTP shift (in RMB, relative to control)
gen double _wtp_arm = 0 if complete_endline == 1
replace _wtp_arm =  3 if arm==1 & complete_endline==1   // pro low: modest rise
replace _wtp_arm =  6 if arm==2 & complete_endline==1   // pro high: largest H5 ***
replace _wtp_arm = -2 if arm==3 & complete_endline==1   // anti low: mild drop avg
replace _wtp_arm = -4 if arm==4 & complete_endline==1   // anti high: H5 drop avg ***
replace _wtp_arm =  1 if arm==5 & complete_endline==1   // apolitical: small rise

* HTE: congruence boosts demand; dissonance suppresses it
*   Pro arms  × nat>0 (nationalist): congruent → +WTP
*   Pro arms  × nat<0 (liberal):     dissonant → −WTP
*   Anti arms × nat<0 (liberal):     congruent → +WTP  ← user's key point
*   Anti arms × nat>0 (nationalist): dissonant → −WTP
* Coefficient sign: +2.5 × nat for pro arms; −2.5 × nat for anti arms
replace _wtp_arm = _wtp_arm + 2.5*t0_nat_index if inlist(arm,1,2) & complete_endline==1
replace _wtp_arm = _wtp_arm - 2.5*t0_nat_index if inlist(arm,3,4) & complete_endline==1

* Individual-level drivers (centred; replace missing with 0 to avoid Stata's
* treatment of missing as +infinity in min/max functions)
gen double _wsim_c = cond(mi(w_mean_similar), 0, w_mean_similar - 58)
gen double _wfr_c  = t0_freq_foreign - 2.33
gen double _wtp_ind = 0.30*_wsim_c + 2.0*_wfr_c if complete_endline==1
drop _wsim_c _wfr_c

* Latent WTP (base=20, noise SD=12) → truncated to [0,50]
gen double _wtp_lat = 20 + _wtp_arm + _wtp_ind + 12*rnormal() if complete_endline==1
* Use explicit bounds to avoid Stata missing-as-infinity issue
replace t1_wtp_bid = _wtp_lat          if complete_endline==1 & !mi(_wtp_lat)
replace t1_wtp_bid = 0  if t1_wtp_bid < 0  & complete_endline==1
replace t1_wtp_bid = 50 if t1_wtp_bid > 50 & complete_endline==1 & !mi(t1_wtp_bid)
drop _wtp_arm _wtp_ind _wtp_lat

* Random draw (U[0,50], independent of everything) — the mechanism price
replace t1_wtp_draw = runiform()*50 if complete_endline==1

* Purchase indicator: draw <= bid
replace t1_wtp_buy = (t1_wtp_draw <= t1_wtp_bid) if complete_endline==1

* Outlet choice: weakly correlated with valence (pro → WaPo/Economist; anti → NYT)
* Mostly preference-driven; no strong treatment effect by design
gen double _pref = runiform()
replace t1_wtp_outlet = 1 if _pref < 0.30 & complete_endline==1                  // NYT
replace t1_wtp_outlet = 2 if _pref >= 0.30 & _pref < 0.60 & complete_endline==1  // Economist
replace t1_wtp_outlet = 3 if _pref >= 0.60 & _pref < 0.80 & complete_endline==1  // WSJ
replace t1_wtp_outlet = 4 if _pref >= 0.80 & complete_endline==1                  // WaPo
drop _pref

* ===========================================================================
* KNOWLEDGE RETENTION — T1 (complete_endline = 1, N = 5,215)
* ---------------------------------------------------------------------------
* kq1–kq10: content-relevant items; treatment arms score higher
* kq11–kq12: placebo items (not in articles); no treatment effect
*
* P(correct) = logistic(ability + arm_boost + item_noise)
*   ability  = 0.20*exam_z + 0.12*comply_rate_z + rnormal()×0.40
*   arm_boost for kq1-10:
*     arm1/2 (pro-China): +0.30 (content-related knowledge improves)
*     arm3/4 (anti-China): +0.30 (same: exposure → retention)
*     arm5 (apolitical):   +0.15 (slight boost from China culture content)
*     arm6 (control):       0.00 (reference)
*   kq11-12: no arm boost (placebo; tests things not in materials)
* ===========================================================================

set seed 20250701

* Standardised compliance rate per person (proxy for engagement)
gen double _cz = cond(mi(w_n_comply), 0, (w_n_comply - 15.8)/7.0)
gen double _ez = cond(mi(t0_exam_score), 0, (t0_exam_score - 53)/22)

* Arm boost on content items (kq1-10)
gen double _ab = 0 if complete_endline == 1
replace _ab =  0.30 if inlist(arm,1,2,3,4) & complete_endline==1
replace _ab =  0.15 if arm==5 & complete_endline==1

* Person-level knowledge ability (persistent across items via _ka)
gen double _ka = 0.20*_ez + 0.12*_cz + 0.40*rnormal() if complete_endline==1

* Generate kq1–kq10 (content-relevant items; base logit = logit(0.62) ≈ 0.49)
forvalues k = 1/10 {
    gen double _lp = 0.49 + _ka + _ab + 0.25*rnormal() if complete_endline==1
    replace t1_kq`k' = (runiform() < invlogit(_lp)) if complete_endline==1
    drop _lp
}

* kq11–kq12: placebo items (no arm boost; base logit = logit(0.45) ≈ −0.20)
forvalues k = 11/12 {
    gen double _lp = -0.20 + _ka + 0.25*rnormal() if complete_endline==1
    replace t1_kq`k' = (runiform() < invlogit(_lp)) if complete_endline==1
    drop _lp
}

* Aggregate proportions
egen _know_all = rowmean(t1_kq1 t1_kq2 t1_kq3 t1_kq4 t1_kq5 t1_kq6 t1_kq7 t1_kq8 t1_kq9 t1_kq10 t1_kq11 t1_kq12) if complete_endline==1
replace t1_know_prop_all = _know_all if complete_endline==1
drop _know_all

egen _know10 = rowmean(t1_kq1 t1_kq2 t1_kq3 t1_kq4 t1_kq5 t1_kq6 t1_kq7 t1_kq8 t1_kq9 t1_kq10) if complete_endline==1
replace t1_know_prop10 = _know10 if complete_endline==1
drop _know10

drop _ab

* ===========================================================================
* KNOWLEDGE RETENTION — T2 (complete_followup = 1, N = 2,115)
* ---------------------------------------------------------------------------
* Forgetting: base rate drops from 0.62 → 0.50 (logit(0.50)=0)
* Same arm boost but attenuated by 50% (knowledge partially retained)
* ===========================================================================

set seed 20250702

gen double _ab2 = 0 if complete_followup == 1
replace _ab2 =  0.15 if inlist(arm,1,2,3,4) & complete_followup==1   // ~50% retention
replace _ab2 =  0.08 if arm==5 & complete_followup==1

forvalues k = 1/10 {
    gen double _lp = 0.00 + _ka + _ab2 + 0.30*rnormal() if complete_followup==1
    replace t2_kq`k' = (runiform() < invlogit(_lp)) if complete_followup==1
    drop _lp
}
forvalues k = 11/12 {
    gen double _lp = -0.30 + _ka + 0.30*rnormal() if complete_followup==1
    replace t2_kq`k' = (runiform() < invlogit(_lp)) if complete_followup==1
    drop _lp
}

egen _know2_all = rowmean(t2_kq1 t2_kq2 t2_kq3 t2_kq4 t2_kq5 t2_kq6 t2_kq7 t2_kq8 t2_kq9 t2_kq10 t2_kq11 t2_kq12) if complete_followup==1
replace t2_know_prop_all = _know2_all if complete_followup==1
drop _know2_all

egen _know2_10 = rowmean(t2_kq1 t2_kq2 t2_kq3 t2_kq4 t2_kq5 t2_kq6 t2_kq7 t2_kq8 t2_kq9 t2_kq10) if complete_followup==1
replace t2_know_prop10 = _know2_10 if complete_followup==1
drop _know2_10 _ab2

drop _ka _cz _ez

* ===========================================================================
* T2 BEHAVIORAL DEMAND (complete_followup = 1)
* ---------------------------------------------------------------------------
* t2_digest_signup: opted into foreign-news digest after endline
*   Driven by arm (same direction as WTP) + t0_freq_foreign + noise
*   Base P ≈ 0.35; Pro arms: +0.10–0.15; Anti high: −0.08
*
* t2_bias_cn: perceived bias of Chinese media (0–10)
*   Anti-China arms: slightly higher perceived CN bias (content confirms bias view)
*   No strong treatment effect for pro arms
*
* t2_bias_west: perceived bias of Western media on China (0–10)
*   Pro-China arms: lower perceived bias (credibility shift lowers bias perception)
*   Nationalists: higher baseline perceived Western bias
* ===========================================================================

set seed 20250703

* t2_digest_signup (0/1)
gen double _ds_lat = -0.62 ///                     // logit(0.35) ≈ -0.62
    + 0.20*(arm==1 & complete_followup==1) ///
    + 0.45*(arm==2 & complete_followup==1) ///      // pro high: biggest boost
    - 0.15*(arm==3 & complete_followup==1) ///
    - 0.35*(arm==4 & complete_followup==1) ///      // anti high: biggest drop
    + 0.10*(arm==5 & complete_followup==1) ///
    + 0.30*(t0_freq_foreign - 2.33)*(complete_followup==1) ///
    + 0.80*rnormal()*(complete_followup==1)
replace t2_digest_signup = (runiform() < invlogit(_ds_lat)) if complete_followup==1
drop _ds_lat

* t2_bias_cn: perceived Chinese media bias (0–10, mean ~6)
gen double _bcn = 6.0 ///
    + 0.50*(inlist(arm,3,4) & complete_followup==1) ///  anti: CN media perceived more biased
    - 0.20*(inlist(arm,1,2) & complete_followup==1) ///  pro: slight decrease
    - 0.60*t0_nat_index*(complete_followup==1) ///       nationalists perceive less CN bias
    + 1.80*rnormal()*(complete_followup==1)
replace t2_bias_cn = max(0, min(10, _bcn)) if complete_followup==1
drop _bcn

* t2_bias_west: perceived Western media bias on China (0–10, mean ~6.5)
gen double _bwest = 6.5 ///
    - 0.60*(inlist(arm,1,2) & complete_followup==1) ///  pro: West seen as less biased (credibility)
    + 0.20*(inlist(arm,3,4) & complete_followup==1) ///  anti: West seen as slightly more biased
    + 0.80*t0_nat_index*(complete_followup==1) ///       nationalists perceive more Western bias
    + 1.80*rnormal()*(complete_followup==1)
replace t2_bias_west = max(0, min(10, _bwest)) if complete_followup==1
drop _bwest

* ===========================================================================
* POLICY ATTITUDE ITEMS — T1  (1–5 Likert; follow rs direction)
* pol_econ: economic policy approval; pol_dev: domestic development
* pol_cult: culture & society; pol_sci: science & tech (most universally positive)
* ===========================================================================
set seed 20250801

* Policy items follow rs direction with arm-specific shifts
gen double _ps = 0 if complete_endline==1
replace _ps =  0.04 if arm==1 & complete_endline==1
replace _ps =  0.11 if arm==2 & complete_endline==1
replace _ps = -0.06 if arm==3 & complete_endline==1
replace _ps = -0.14 if arm==4 & complete_endline==1
replace _ps =  0.01 if arm==5 & complete_endline==1

replace t1_pol_econ = max(1, min(5, round(t0_rs_econ + 0.5*_ps + 0.30*rnormal()))) if complete_endline==1
replace t1_pol_dev  = max(1, min(5, round(t0_rs_stab + 0.5*_ps + 0.30*rnormal()))) if complete_endline==1
replace t1_pol_cult = max(1, min(5, round(t0_rs_eq   + 0.5*_ps + 0.30*rnormal()))) if complete_endline==1
replace t1_pol_sci  = max(1, min(5, round(t0_rs_tech + 0.5*_ps + 0.30*rnormal()))) if complete_endline==1
drop _ps

* ===========================================================================
* QC VARIABLES — T1 & T2 (attention checks, straightline flag, timestamps)
* Endline/followup completers have already passed self-selection filter:
*   att_pass = 0 is very rare (~3%); straightline ~1-2%
* ===========================================================================

set seed 20250802

* t1 QC (complete_endline = 1)
replace t1_att_pass        = (runiform() >= 0.030) if complete_endline == 1
replace t1_straightline_flag = (runiform() < 0.018) if complete_endline == 1

* t2 QC (complete_followup = 1)
replace t2_att_pass        = (runiform() >= 0.025) if complete_followup == 1
replace t2_straightline_flag = (runiform() < 0.012) if complete_followup == 1

* Submission timestamps
* Endline: Aug 2025 (7:00–23:00, evening peak)
local ts_lo1  = clock("01aug2025 00:00:00", "DMYhms")
local day_sec = 86400000
local eve_mid = 68400000
local eve_sd  =  7200000
replace t1_ts_submit = `ts_lo1' ///
    + floor(30 * runiform()) * `day_sec' ///
    + max(25200000, min(82800000, `eve_mid' + `eve_sd' * rnormal())) ///
    if complete_endline == 1
format t1_ts_submit %tc

* Followup: Nov 2025
local ts_lo2 = clock("01nov2025 00:00:00", "DMYhms")
replace t2_ts_submit = `ts_lo2' ///
    + floor(29 * runiform()) * `day_sec' ///
    + max(25200000, min(82800000, `eve_mid' + `eve_sd' * rnormal())) ///
    if complete_followup == 1
format t2_ts_submit %tc

* t2_open_feedback: open-ended text — placeholder (empty string is valid)

replace d1_rs_index      = t1_rs_index      - t0_rs_index      if complete_endline == 1
replace d1_cen_index     = t1_cen_index     - t0_cen_index     if complete_endline == 1
replace d1_nat_index     = t1_nat_index     - t0_nat_index     if complete_endline == 1
replace d1_therm_gap     = t1_therm_gap     - t0_therm_gap     if complete_endline == 1
replace d1_trust_foreign = t1_trust_foreign - t0_trust_foreign if complete_endline == 1

* ===========================================================================
* T2 FOLLOW-UP OUTCOMES  (complete_followup == 1; N = 2,115)
* ---------------------------------------------------------------------------
* Design: DIRECT generation — t2_Y = t0_Y + δ_arm(Y) + ε_t2
*   Avoids control-group noise inflation from the α×d1 persistence approach.
*
* Target effects at t2 (vs control; ANCOVA, n≈353/arm, SE≈0.05 for indices):
*   trust_foreign arm2: +0.10 pts → t≈2.1 *   (H2 KEY: credibility persists)
*   trust_foreign arm1: +0.05 pts → t≈1.0 NS  (low-dose mostly gone)
*   rs_index     arm4: −0.08 SD  → t≈1.6 NS  (direction visible, not sig)
*   rs_index     arm2: +0.04 SD  → t≈0.8 NS
*   nat_index    arm4: +0.07 SD  → t≈1.4 NS  (backlash trend, not sig)
*   everything else: clearly NS
* ===========================================================================

set seed 20250502

* ── Regime support items (items for realism; index direct below) ──────────────
foreach v in t0_rs_econ t0_rs_stab t0_rs_eq t0_rs_tech t0_rs_gov {
    local t2v = subinstr("`v'", "t0_", "t2_", 1)
    local t1v = subinstr("`v'", "t0_", "t1_", 1)
    replace `t2v' = max(1, min(5, round(`v' + 0.48*(`t1v'-`v') + 0.40*rnormal()))) ///
        if complete_followup == 1
}
* rs_index direct (calibrated)
gen double _d_rs2 = 0 if complete_followup == 1
replace _d_rs2 =  0.04 if arm==1 & complete_followup==1
replace _d_rs2 =  0.04 if arm==2 & complete_followup==1
replace _d_rs2 = -0.05 if arm==3 & complete_followup==1
replace _d_rs2 = -0.08 if arm==4 & complete_followup==1
replace _d_rs2 =  0.01 if arm==5 & complete_followup==1
replace t2_rs_index = t0_rs_index + _d_rs2 + 0.80*rnormal() if complete_followup==1
drop _d_rs2

* ── Censorship index direct ───────────────────────────────────────────────────
gen double _d_cen2 = 0 if complete_followup == 1
replace _d_cen2 =  0.02 if arm==1 & complete_followup==1
replace _d_cen2 =  0.02 if arm==2 & complete_followup==1
replace _d_cen2 = -0.02 if arm==3 & complete_followup==1
replace _d_cen2 = -0.04 if arm==4 & complete_followup==1
replace t2_cen_index = t0_cen_index + _d_cen2 + 0.80*rnormal() if complete_followup==1
drop _d_cen2

* cen items (background)
foreach v in t0_cen_stab t0_cen_prot t0_cen_right {
    local t2v = subinstr("`v'", "t0_", "t2_", 1)
    local t1v = subinstr("`v'", "t0_", "t1_", 1)
    replace `t2v' = max(1, min(5, round(`v' + 0.45*(`t1v'-`v') + 0.40*rnormal()))) ///
        if complete_followup == 1
}

* ── Nationalism index direct (backlash trend without significance) ─────────────
gen double _d_nat2 = 0 if complete_followup == 1
replace _d_nat2 =  0.03 if arm==1 & complete_followup==1
replace _d_nat2 =  0.04 if arm==2 & complete_followup==1
replace _d_nat2 =  0.04 if arm==3 & complete_followup==1
replace _d_nat2 =  0.07 if arm==4 & complete_followup==1  // arm4: trend persists NS
replace _d_nat2 =  0.02 if arm==5 & complete_followup==1
replace t2_nat_index = t0_nat_index + _d_nat2 + 0.78*rnormal() if complete_followup==1
drop _d_nat2

* nat items (background)
foreach v in t0_nat_bias t0_nat_resist t0_nat_proud t0_nat_unfair {
    local t2v = subinstr("`v'", "t0_", "t2_", 1)
    local t1v = subinstr("`v'", "t0_", "t1_", 1)
    replace `t2v' = max(1, min(5, round(`v' + 0.58*(`t1v'-`v') + 0.40*rnormal()))) ///
        if complete_followup == 1
}

* ── Feeling thermometers ──────────────────────────────────────────────────────
replace t2_therm_cn   = max(0, min(100, t0_therm_cn   + 2.5*(arm==1 | arm==2) - 1*(inlist(arm,3,4)) + 9*rnormal()))  if complete_followup==1
replace t2_therm_west = max(0, min(100, t0_therm_west + 2.5*(inlist(arm,1,2))                        + 9*rnormal()))  if complete_followup==1
replace t2_therm_gap  = t2_therm_cn - t2_therm_west if complete_followup == 1

* ── trust_foreign direct (KEY: arm2 * persists, everything else NS) ───────────
* arm2: +0.10 pts above t0, ctrl: ≈0 → net +0.10, t≈2.1 *
gen double _d_tf2 = 0 if complete_followup == 1
replace _d_tf2 =  0.12 if arm==1 & complete_followup==1  // pro low: fading, NS
replace _d_tf2 =  0.30 if arm==2 & complete_followup==1  // pro high: persists ** (robust to ctrl noise)
replace _d_tf2 = -0.02 if arm==3 & complete_followup==1
replace _d_tf2 = -0.02 if arm==4 & complete_followup==1
replace t2_trust_foreign = max(1, min(5, round(t0_trust_foreign + 0.5*_d_tf2 + 0.62*rnormal()))) ///
    if complete_followup == 1
drop _d_tf2

* trust_state: small, NS
replace t2_trust_state = max(1, min(5, round(t0_trust_state + 0.02*(inlist(arm,1,2)) + 0.55*rnormal()))) ///
    if complete_followup == 1

* trust_comm, soc, chat: noise only
foreach v in t0_trust_comm t0_trust_soc t0_trust_chat {
    local t2v = subinstr("`v'", "t0_", "t2_", 1)
    replace `t2v' = max(1, min(5, round(`v' + 0.50*rnormal()))) ///
        if complete_followup == 1
}

* ── Difference scores (t2 − t0) ──────────────────────────────────────────────
replace d2_rs_index      = t2_rs_index      - t0_rs_index      if complete_followup == 1
replace d2_cen_index     = t2_cen_index     - t0_cen_index     if complete_followup == 1
replace d2_nat_index     = t2_nat_index     - t0_nat_index     if complete_followup == 1
replace d2_therm_gap     = t2_therm_gap     - t0_therm_gap     if complete_followup == 1
replace d2_trust_foreign = t2_trust_foreign - t0_trust_foreign if complete_followup == 1

* Treatment dummies (ref arm 6)
forvalues a = 1/5 {
    replace arm`a' = (arm == `a') if recruited == 1
}

* Treatment content variables (derived from arm)
replace treat_valence =  1 if inlist(arm, 1, 2)   // Pro-China
replace treat_valence = -1 if inlist(arm, 3, 4)   // Anti-China
replace treat_valence =  0 if inlist(arm, 5, 6)   // Neutral / control

replace treat_dose_hi = 0 if inlist(arm, 1, 3)    // low dose
replace treat_dose_hi = 1 if inlist(arm, 2, 4)    // high dose
                                                    // arm 5/6: stays missing

replace n_pol_slots =  6 if inlist(arm, 1, 3)     // low dose:  6 political + 18 CTRL
replace n_pol_slots = 12 if inlist(arm, 2, 4)     // high dose: 12 political + 12 CTRL
replace n_pol_slots =  0 if inlist(arm, 5, 6)     // apolitical / control

tab treat_valence arm if recruited == 1, mi
tab treat_dose_hi arm if recruited == 1, mi

compress
recast strL t0_city
save participant.dta, replace

* --- Assertions: field totals ---
qui count
assert r(N) == 12215

qui count if recruited == 1
assert r(N) == 6365

qui count if complete_endline == 1
assert r(N) == 5215

qui count if complete_followup == 1
assert r(N) == 2115

tab arm if recruited == 1, mi

* --- Export arm assignments for Python content scheduler ---
preserve
keep if recruited == 1
keep study_id arm
export delimited using "sim_arm_export.csv", replace
restore

* --- Run Python content scheduler ---
* Reads sim_arm_export.csv + ../materials_master_bank.csv
* Writes content_assignment.csv  (6365 × 24 = 152,760 rows)
shell python3 "build_content_schedule.py"

* --- Load article assignment (before preserve) ---
* content_assignment.csv produced by build_content_schedule.py
import delimited using "content_assignment.csv", encoding(utf-8) clear
tempfile ca
save `ca'
use participant.dta, clear   // reload participant file

* --- Weekly long file (recruited only; 24 slots each) ---
preserve
keep if recruited == 1
* Carry baseline ideology proxy into weekly file for HTE DGP
keep study_id arm complete_endline last_week_active t0_nat_index t0_exam_score

* ── Person-level latent factors ──────────────────────────────────────────────
* _fe_eng : English ability / engagement (+ = more able/engaged)
*   TIED TO t0_exam_score so quiz scores correlate with exam performance (~0.35)
*   exam_score is on 0-100; mean~53, SD~22 → standardise before using
*   For missing exam_score (don't-yet-have-score people): use neutral = 0
gen double _exam_z = cond(mi(t0_exam_score), 0, (t0_exam_score - 53)/22)
gen double _fe_eng = 0.50*_exam_z + rnormal(0, 0.70)
* SD(_fe_eng) ≈ sqrt(0.25*Var(_exam_z) + 0.49) ≈ sqrt(0.25+0.49) ≈ 0.86 ≈ original 0.85
* Cor(_fe_eng, exam_z) ≈ 0.50/0.86 ≈ 0.58 → quiz ↔ exam corr ≈ 0.30-0.40
drop _exam_z

* _fe_pol : ideological orientation (+ = pro-regime/nationalist; derived from t0_nat_index)
*           high _fe_pol → more receptive to pro-China, resistant to anti-China
gen double _fe_pol = t0_nat_index + 0.30*rnormal()   // slightly noisy version of nat_index

* ── Expand to 24 slots ───────────────────────────────────────────────────────
expand 24
sort study_id
by study_id: gen byte content_id = _n
gen byte week     = ceil(content_id / 2)
gen byte slot_wk  = cond(mod(content_id, 2) == 1, 1, 2)

* ── Merge article assignment ─────────────────────────────────────────────────
merge 1:1 study_id content_id using `ca', ///
    keepusing(article_id article_title topic bank sched_valence sched_political) ///
    nogenerate assert(3)

* ── Active-week indicator ─────────────────────────────────────────────────────
* All recruited participants opened every slot in their active weeks.
* Variation is in EFFORT and QUALITY, not in whether they opened.
* Rows after dropout (week > last_week_active for complete_endline==0) → missing.
* complete_endline==1 → last_week_active==12, all 24 slots active.

gen byte wk_open = 1                             // always opened (in study)
replace  wk_open = . if complete_endline == 0 & week > last_week_active

set seed `seed'

* ── Time on task (missing after dropout) ─────────────────────────────────────
* wk_read_min: ~9 min base; political slots slightly longer; varies by engagement
gen float wk_read_min = max(2, min(25, ///
    9 + 1.5*sched_political + 2.0*_fe_eng + 1.5*rnormal())) if wk_open == 1

* wk_vid_pct: proportion of ~5-min audio listened; high base (incentivised app)
gen float wk_vid_pct = max(0.2, min(1, ///
    0.84 + 0.10*_fe_eng + 0.08*rnormal())) if wk_open == 1
gen float wk_vid_min = round(5 * wk_vid_pct, 0.1) if wk_open == 1

* ── Quiz scores (0–20 per subtype) ───────────────────────────────────────────
* All participants attempted quiz (teaching app with incentives); no skip.
* Performance varies by English ability (_fe_eng) and content difficulty.
gen double _qa   = 14 + 2.8*_fe_eng             // mean ~14/20 for average person
gen double _hard = 1.0 * sched_political         // political harder (vocab)

gen byte wk_quiz_comprehension = max(0, min(20, round(_qa - _hard  + 1.4*rnormal()))) if wk_open==1
gen byte wk_quiz_grammar       = max(0, min(20, round(_qa           + 1.4*rnormal()))) if wk_open==1
gen byte wk_quiz_vocab         = max(0, min(20, round(_qa - _hard  + 1.4*rnormal()))) if wk_open==1
gen byte wk_quiz_listen        = max(0, min(20, round(_qa + 2*wk_vid_pct - 1 + 1.4*rnormal()))) if wk_open==1
gen byte wk_quiz_sentence      = max(0, min(20, round(_qa           + 1.4*rnormal()))) if wk_open==1
drop _qa _hard

gen int wk_quiz_score = wk_quiz_comprehension + wk_quiz_grammar + ///
    wk_quiz_vocab + wk_quiz_listen + wk_quiz_sentence if wk_open == 1

* wk_comply: met watch-time threshold (vid_pct ≥ 0.8)
gen byte wk_comply = (wk_vid_pct >= 0.8) if wk_open == 1

* ── Weekly reaction ratings ───────────────────────────────────────────────────
* wk_rate_interest:
*   Base ~55; political +6; anti-China × nationalist → -7 (defensive);
*   pro-China × liberal → -4 (skeptical); slight novelty decay by week
gen float wk_rate_interest = max(0, min(100, ///
    55 + 6*sched_political                       ///
    - 7*(sched_valence==-1)*(_fe_pol > 0.5)     ///
    - 4*(sched_valence== 1)*(_fe_pol < -0.5)    ///
    + 8*_fe_eng                                  ///
    - 0.5*week                                   ///
    + 12*rnormal())) if wk_open == 1

* wk_rate_cred: costly-signal effect for pro-China; dismissal for anti×nationalist
gen float wk_rate_cred = max(0, min(100, ///
    50 + 5*(sched_valence== 1)                ///
    - 4*(sched_valence==-1)*(_fe_pol > 0.5)  ///
    + 3*(sched_valence==-1)*(_fe_pol < -0.5) ///
    + 0.4*week*(sched_valence== 1)            ///
    + 10*_fe_eng                              ///
    + 14*rnormal())) if wk_open == 1

* wk_rate_similar: demand for similar content; decays under dissonant high-dose
gen double _congruent = (sched_valence == 1)*(_fe_pol > 0) + ///
                        (sched_valence ==-1)*(_fe_pol < 0)
gen float wk_rate_similar = max(0, min(100, ///
    58 + 8*_congruent                                  ///
    - 1.2*sched_political*(1-_congruent)*week          ///
    + 6*_fe_eng                                        ///
    + 14*rnormal())) if wk_open == 1
drop _congruent

drop _fe_eng _fe_pol t0_nat_index t0_exam_score

compress
save weekly_long.dta, replace
restore

* ===========================================================================
* WEEKLY AGGREGATES → participant file (w_* variables)
* ---------------------------------------------------------------------------
* Collapse weekly long file to person level, then merge into participant file.
* Only recruited participants have weekly data; non-recruited get w_* = missing.
* ===========================================================================
preserve
use weekly_long.dta, clear

* Only use active slots (wk_open == 1)
keep if wk_open == 1

* Per-person aggregates
gen byte   _pol_open = (sched_political == 1)   // political slot opened

collapse ///
    (count)  w_n_slots      = wk_open          ///  total active slots
    (sum)    w_n_open        = wk_open          ///  = w_n_slots (all open=1)
    (sum)    w_n_comply      = wk_comply        ///  slots meeting watch+quiz
    (sum)    w_sum_read_min  = wk_read_min      ///  total reading minutes
    (sum)    w_sum_vid_min   = wk_vid_min       ///  total video minutes
    (mean)   w_mean_quiz     = wk_quiz_score    ///  mean quiz score (0–100)
    (mean)   w_mean_interest = wk_rate_interest ///  mean interest rating
    (mean)   w_mean_cred     = wk_rate_cred     ///  mean credibility rating
    (mean)   w_mean_similar  = wk_rate_similar  ///  mean "want more" rating
    (sum)    w_cnt_political_open = _pol_open   /// political slots opened
    , by(study_id)

drop w_n_open   // redundant with w_n_slots
tempfile wagg
save `wagg'
restore

* Merge aggregates into participant file
use participant.dta, clear
* update: fills missing w_* in master with values from aggregate (using dataset)
merge 1:1 study_id using `wagg', nogenerate update
compress
save participant.dta, replace

di ""
display as result "OK: participant.dta and weekly_long.dta saved in `c(pwd)'"
