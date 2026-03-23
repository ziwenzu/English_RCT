/*==============================================================================
  rct_framework.do
  
  Teaching-only simulation scaffold for the six-arm English-news RCT described
  in writing/proposal.tex. No observations are populated here; fill values in a
  later step when you inject treatment effects / DGP.
  
  --------------------------------------------------------------------------
  REALIZED SAMPLE FLOW (authoritative counts from proposal / field timeline)
  --------------------------------------------------------------------------
    N = 12,215   Completed prescreen + baseline survey (June 2025 pool).
                 Baseline measures: demographics, exam profile, blocking vars
                 (gender, region, English proficiency, baseline nationalism),
                 and pre-treatment attitudes (regime support, censorship,
                 thermometers, media habits, foreign exposure, etc.).

    -> funnel    NOT everyone with baseline is randomized. After baseline,
                 the partner app contacted respondents for (i) informed consent
                 to the randomized content arms and (ii) verification that
                 content-delivery methods work (can receive articles/videos in-app).
                 People who decline consent or fail delivery verification do not
                 enter the RCT — this is why counts drop sharply here (mainly
                 eligibility / logistics / willingness, not "blocking" as exclusion).

    N = 6,365    Block-randomized into 6 arms (~1/6 each), consent + delivery OK.
                 Arms + strata (24 blocks) apply ONLY here. ITT / ATE sample.

    N = 5,215    Completed weekly module + endline (June–October 2025).
                 Subset of randomized; interim dropout between weeks / nonresponse.

    N = 2,115    Follow-up survey (November 2025).
                 Further attrition from endline.

  Accounting (for simulation / teaching checks; mutually exclusive groups):
    12,215 = 5,850 (never randomized) + 6,365 (randomized)
    5,850  = flow_cat 1 + 2 + 3  (decline consent / fail delivery / other exclusion)
    6,365  = 1,150 (rand., no endline) + 5,215 (with endline)
           = flow_cat 4 + (flow_cat 5 + flow_cat 6)
    5,215  = 3,100 (endline, no follow-up) + 2,115 (with follow-up)
           = flow_cat 5 + flow_cat 6

  Recommended simulation frame: set N = 12,215 at the person level with baseline
  fields for everyone; set sample_randomized = 1 for 6,365; assign arm only
  when sample_randomized; set complete_endline / complete_followup for 5,215 /
  2,115 among appropriate denominators (typically randomized).
  Fill flow_cat (1–6) so tab flow_cat sums to the above; set reach_* flags
  consistently (see variable notes below).

  Outputs (after run):
    participant_template.dta  — one row per study_id (design: up to 12,215)
    weekly_template.dta       — one row per study_id × week × slot (24 rows
                                    per randomized participant who remains in
                                    weekly frame; others missing or zero rows)
==============================================================================*/

version 16.0
clear all
set more off

* Run this do-file from the teaching/ folder, or rely on the path below:
capture cd "/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/teaching"

*---------------------------------------------------------------------------
* Value labels (arms, blocks, exams, etc.)
*---------------------------------------------------------------------------

label define arm_lbl ///
  1 "Pro-China, low dose" ///
  2 "Pro-China, high dose" ///
  3 "Anti-China, low dose" ///
  4 "Anti-China, high dose" ///
  5 "Apolitical China" ///
  6 "Non-China control (ref)"

label define yesno_lbl 0 "No" 1 "Yes"

label define gender_lbl 1 "Male" 2 "Female"

label define region_lbl 1 "East" 2 "Central" 3 "West"

label define blkbin_lbl 1 "Lower / block low" 2 "Higher / block high"

label define exam_lbl 1 "TOEFL" 2 "IELTS" 3 "GRE" 4 "GMAT" 5 "Other"

label define educ_lbl 1 "Associate or below" 2 "Bachelor" 3 "Master" 4 "Doctorate"

label define likert5_lbl 1 "Low / disagree" 2 "2" 3 "3" 4 "4" 5 "High / agree"

* News exposure: how often you get news from this channel (baseline ~90d; same scale for t0_news_foreign_30d)
label define freq90d_lbl ///
  1 "Never or almost never" ///
  2 "Rarely (less than once a month)" ///
  3 "Sometimes (a few times a month)" ///
  4 "Often (several times a week)" ///
  5 "Daily or almost daily"

* Trust: how much you trust news/information from this channel/type
label define trust_src_lbl ///
  1 "No trust at all" ///
  2 "Low trust" ///
  3 "Moderate" ///
  4 "High trust" ///
  5 "Complete trust"

label define abroad_plan_lbl 1 "Definitely yes" 2 "Probably yes" 3 "Probably not" 4 "Definitely not"

label define wtp_outlet_lbl 1 "NYT" 2 "Economist" 3 "WSJ" 4 "Washington Post"

label define valence_lbl -1 "Anti-China framing" 0 "Neutral / apolitical / non-China" 1 "Pro-China framing"

*---------------------------------------------------------------------------
* A) Participant-level template (wide survey + design + aggregates)
*---------------------------------------------------------------------------*/

clear
set obs 0

* --- Design / sampling ---
gen double study_id = .                 // anonymous link key
format study_id %20.0g

gen byte arm = .                        // 1–6, Non-China = 6 (reference)
label values arm arm_lbl

gen byte block_id = .                   // 1–24 stratification cells

gen byte blk_gender = .                 // 1 male 2 female (blocking factor)
label values blk_gender gender_lbl

gen byte blk_region = .                 // 1 east 2 central 3 west
label values blk_region region_lbl

gen byte blk_eng_hi = .                 // 1 low proficiency group 2 high (binary split)
label values blk_eng_hi blkbin_lbl

gen byte blk_nat_hi = .                 // 1 low nationalism group 2 high (binary split)
label values blk_nat_hi blkbin_lbl

* --- Sample flow: 12,215 baseline -> 6,365 recruited -> 5,215 endline -> 2,115 FU ---
gen byte recruited = .                  // 1 = clicked consent; entered RCT (N=6,365)
label values recruited yesno_lbl

gen float date_baseline_m = .
gen float date_rand_m = .
gen float date_endline_m = .
gen float date_followup_m = .
format date_baseline_m date_rand_m date_endline_m date_followup_m %tm

gen byte complete_baseline = .          // 1 = t0 survey complete (all 12,215)
gen byte complete_endline = .           // 1 = endline done (N=5,215; subset of recruited)
gen byte complete_followup = .          // 1 = follow-up done (N=2,115; subset of endline)
label values complete_baseline yesno_lbl
label values complete_endline yesno_lbl
label values complete_followup yesno_lbl

gen byte any_weekly_data = .            // 1 if any app engagement log exists (recruited only)
label values any_weekly_data yesno_lbl

gen byte last_week_active = .           // last week (1-12) with engagement; 12 = completed

* --- Baseline: background (appendix Background) ---
gen byte t0_age_cat = .                 // coded age bracket
gen byte t0_female = .
label values t0_female yesno_lbl

gen byte t0_ethnic_han = .              // 1 Han 0 minority (or missing)
label values t0_ethnic_han yesno_lbl

gen byte t0_educ = .
label values t0_educ educ_lbl

gen str32 t0_city = ""

gen byte t0_party_id = .                // party / political id (coded)

gen byte t0_exam_type = .
label values t0_exam_type exam_lbl

gen float t0_exam_score = .             // most recent reported score (scale depends on exam)

gen float t0_prep_weeks = .             // prep length

gen str100 t0_join_motivation = ""      // main motivation text or short code

* --- Baseline: media exposure & foreign orientation (appendix Media) ---
gen byte t0_freq_state = .
gen byte t0_freq_comm = .
gen byte t0_freq_soc = .
gen byte t0_freq_foreign = .
gen byte t0_freq_chat = .
label values t0_freq_state t0_freq_comm t0_freq_soc t0_freq_foreign t0_freq_chat freq90d_lbl

gen byte t0_trust_state = .
gen byte t0_trust_comm = .
gen byte t0_trust_soc = .
gen byte t0_trust_foreign = .
gen byte t0_trust_chat = .
label values t0_trust_state t0_trust_comm t0_trust_soc t0_trust_foreign t0_trust_chat trust_src_lbl

gen byte t0_news_foreign_30d = .        // frequency past month, 1–5 (same anchors as 90d items)
label values t0_news_foreign_30d freq90d_lbl

gen byte t0_plat_tiktok = .
gen byte t0_plat_fb = .
gen byte t0_plat_tw = .
gen byte t0_plat_yt = .
gen byte t0_plat_ig = .
label values t0_plat_tiktok t0_plat_fb t0_plat_tw t0_plat_yt t0_plat_ig yesno_lbl

gen byte t0_abroad_ever = .
label values t0_abroad_ever yesno_lbl

gen byte t0_abroad_plan = .
label values t0_abroad_plan abroad_plan_lbl

* --- Baseline: primary attitudes (construct items) ---
gen byte t0_rs_econ = .
gen byte t0_rs_stab = .
gen byte t0_rs_eq = .
gen byte t0_rs_tech = .
gen byte t0_rs_gov = .
label values t0_rs_econ t0_rs_stab t0_rs_eq t0_rs_tech t0_rs_gov likert5_lbl

gen float t0_rs_index = .               // z-scored or averaged index at t0 (analysis)

gen byte t0_cen_stab = .
gen byte t0_cen_right = .
gen byte t0_cen_prot = .
label values t0_cen_stab t0_cen_right t0_cen_prot likert5_lbl

gen float t0_cen_index = .

gen float t0_therm_cn = .
gen float t0_therm_west = .
gen float t0_therm_gap = .              // China minus West (0–100 scales)

gen byte t0_nat_bias = .
gen byte t0_nat_resist = .
gen byte t0_nat_proud = .
gen byte t0_nat_unfair = .
label values t0_nat_bias t0_nat_resist t0_nat_proud t0_nat_unfair likert5_lbl

gen float t0_nat_index = .

* --- Endline: repeat batteries + knowledge + WTP ---
gen byte t1_rs_econ = .
gen byte t1_rs_stab = .
gen byte t1_rs_eq = .
gen byte t1_rs_tech = .
gen byte t1_rs_gov = .
label values t1_rs_econ t1_rs_stab t1_rs_eq t1_rs_tech t1_rs_gov likert5_lbl
gen float t1_rs_index = .

gen byte t1_cen_stab = .
gen byte t1_cen_right = .
gen byte t1_cen_prot = .
label values t1_cen_stab t1_cen_right t1_cen_prot likert5_lbl
gen float t1_cen_index = .

gen float t1_therm_cn = .
gen float t1_therm_west = .
gen float t1_therm_gap = .

gen byte t1_nat_bias = .
gen byte t1_nat_resist = .
gen byte t1_nat_proud = .
gen byte t1_nat_unfair = .
label values t1_nat_bias t1_nat_resist t1_nat_proud t1_nat_unfair likert5_lbl
gen float t1_nat_index = .

gen byte t1_trust_state = .
gen byte t1_trust_comm = .
gen byte t1_trust_soc = .
gen byte t1_trust_foreign = .
gen byte t1_trust_chat = .
label values t1_trust_state t1_trust_comm t1_trust_soc t1_trust_foreign t1_trust_chat trust_src_lbl

* Policy / issue items tied to content banks (endline)
gen byte t1_pol_econ = .
gen byte t1_pol_dev = .
gen byte t1_pol_cult = .
gen byte t1_pol_sci = .
label values t1_pol_econ t1_pol_dev t1_pol_cult t1_pol_sci likert5_lbl

* Knowledge: 10 content + 2 placebo (0/1 each); store item-level + summary
forvalues k = 1/12 {
    gen byte t1_kq`k' = .
    label values t1_kq`k' yesno_lbl
}
gen float t1_know_prop_all = .          // mean of 12
gen float t1_know_prop10 = .          // mean of first 10 (content only)

* Becker–DeGroot–Marschak style WTP (continuous bid + random price + purchase)
gen float t1_wtp_bid = .                // 0–50 RMB stated maximum
gen float t1_wtp_draw = .               // uniform draw 0–50
gen byte t1_wtp_buy = .                 // 1 if draw <= bid
label values t1_wtp_buy yesno_lbl

gen byte t1_wtp_outlet = .              // chosen outlet if applicable
label values t1_wtp_outlet wtp_outlet_lbl

* --- Follow-up: repeat + digest + optional bias ratings ---
gen byte t2_rs_econ = .
gen byte t2_rs_stab = .
gen byte t2_rs_eq = .
gen byte t2_rs_tech = .
gen byte t2_rs_gov = .
label values t2_rs_econ t2_rs_stab t2_rs_eq t2_rs_tech t2_rs_gov likert5_lbl
gen float t2_rs_index = .

gen byte t2_cen_stab = .
gen byte t2_cen_right = .
gen byte t2_cen_prot = .
label values t2_cen_stab t2_cen_right t2_cen_prot likert5_lbl
gen float t2_cen_index = .

gen float t2_therm_cn = .
gen float t2_therm_west = .
gen float t2_therm_gap = .

gen byte t2_nat_bias = .
gen byte t2_nat_resist = .
gen byte t2_nat_proud = .
gen byte t2_nat_unfair = .
label values t2_nat_bias t2_nat_resist t2_nat_proud t2_nat_unfair likert5_lbl
gen float t2_nat_index = .

gen byte t2_trust_state = .
gen byte t2_trust_comm = .
gen byte t2_trust_soc = .
gen byte t2_trust_foreign = .
gen byte t2_trust_chat = .
label values t2_trust_state t2_trust_comm t2_trust_soc t2_trust_foreign t2_trust_chat trust_src_lbl

forvalues k = 1/12 {
    gen byte t2_kq`k' = .
    label values t2_kq`k' yesno_lbl
}
gen float t2_know_prop_all = .
gen float t2_know_prop10 = .

gen float t2_bias_cn = .                // 0–10 perceived bias, domestic media
gen float t2_bias_west = .              // 0–10 perceived bias, Western media on China

gen byte t2_digest_signup = .
label values t2_digest_signup yesno_lbl


* --- Survey quality (per wave) ---
gen byte t0_att_pass = .
gen byte t1_att_pass = .
gen byte t2_att_pass = .
label values t0_att_pass t1_att_pass t2_att_pass yesno_lbl

gen int t0_straightline_flag = .
gen int t1_straightline_flag = .
gen int t2_straightline_flag = .

gen double t0_ts_submit = .
gen double t1_ts_submit = .
gen double t2_ts_submit = .
format t0_ts_submit t1_ts_submit t2_ts_submit %tc

* --- Derived change scores (fill after simulation) ---
gen float d1_rs_index = .               // t1 - t0
gen float d2_rs_index = .               // t2 - t0
gen float d1_cen_index = .
gen float d2_cen_index = .
gen float d1_therm_gap = .
gen float d2_therm_gap = .
gen float d1_nat_index = .
gen float d2_nat_index = .

gen float d1_trust_foreign = .         // trust in foreign media: t1 - t0
gen float d2_trust_foreign = .         // trust in foreign media: t2 - t0

* --- Treatment dummies (reference arm 6) ---
forvalues a = 1/5 {
    gen byte arm`a' = .
    label values arm`a' yesno_lbl
}

* --- Treatment content variables (derived from arm; recruited only) ---
* treat_valence : +1 pro-China (arm 1/2), -1 anti-China (arm 3/4), 0 neutral (arm 5/6)
gen byte treat_valence = .
label values treat_valence valence_lbl

* treat_dose_hi : 1 = high political dose (arm 2/4), 0 = low (arm 1/3), . for arm 5/6
gen byte treat_dose_hi = .
label values treat_dose_hi yesno_lbl

* n_pol_slots: scheduled political article slots (5 low / 20 high / 0 control|apolitical)
gen byte n_pol_slots = .

* --- Weekly-aggregated process measures (merge from long file or compute) ---
gen int w_n_slots = .                   // should be 24 if full exposure opportunity
gen int w_n_comply = .                  // count compliant weeks/slots per definition
gen float w_sum_read_min = .
gen float w_sum_vid_min = .
gen float w_mean_quiz = .
gen float w_mean_interest = .
gen float w_mean_cred = .
gen float w_mean_similar = .
gen int w_cnt_political_open = .        // political slots opened (schedule-dependent)

compress
save "`c(pwd)'/participant_template.dta", replace

*---------------------------------------------------------------------------
* B) Weekly long template: 12 weeks × 2 readings = 24 rows per person
*---------------------------------------------------------------------------*/

clear
set obs 0

gen double study_id = .
format study_id %20.0g

gen byte arm = .                        // duplicate for merge checks / teaching
label values arm arm_lbl

gen int week = .                        // 1–12
gen byte slot_wk = .                    // 1 or 2 within week

gen byte content_id = .                 // 1–24 sequential slot index

gen str20 article_id = ""               // e.g. "PRO_003", "CTRL_011"
gen str200 article_title = ""           // article headline
gen str100 topic = ""                   // topic tag from master bank
gen str20  bank = ""                    // PRO / ANTI / APOL_CHINA / NONCHINA_CONTROL

gen byte sched_political = .            // 1 if slot is political (valence != 0)
label values sched_political yesno_lbl

gen byte sched_valence = .              // -1 anti  0 neutral/apolitical  1 pro
label values sched_valence valence_lbl

* Realized behavior — opening and compliance
gen byte wk_open = .                    // 1 = article opened this slot
gen byte wk_comply = .                  // 1 = vid_pct>=0.8 AND quiz attempted
label values wk_open wk_comply yesno_lbl

* Time-on-task (missing if wk_open==0)
gen float wk_read_min = .              // minutes spent reading article
gen float wk_vid_min = .               // minutes of audio/video consumed
gen float wk_vid_pct = .               // proportion of audio listened (0–1)

* Quiz scores — 5 sub-tests, each 0–20; total 0–100
* All missing if quiz was skipped (~15% of openers)
gen byte wk_quiz_comprehension = .     // reading comprehension (0-20)
gen byte wk_quiz_grammar = .           // grammar and syntax (0-20)
gen byte wk_quiz_vocab = .             // vocabulary (0-20)
gen byte wk_quiz_listen = .            // listening (0-20)
gen byte wk_quiz_sentence = .          // sentence accumulation (0-20)
gen int  wk_quiz_score = .             // aggregate: sum of 5 subtests (0–100)

* Weekly reaction ratings (missing if wk_open==0)
* These are the key weekly OUTCOME variables for treatment-effect analysis
gen float wk_rate_interest = .         // How interesting? (0–100)
gen float wk_rate_cred = .             // How credible? (0–100)
gen float wk_rate_similar = .          // Want more similar content? (0–100)

compress
save "`c(pwd)'/weekly_template.dta", replace

*---------------------------------------------------------------------------
* Variable labels — participant file
*---------------------------------------------------------------------------*/

use participant_template.dta, clear

label var study_id "Anonymous study ID (links survey + logs)"
label var arm "Assigned arm (1–6; 6 = non-China control, reference)"
label var block_id "Randomization block (1–24)"
label var blk_gender "Blocking: gender"
label var blk_region "Blocking: region (East/Central/West)"
label var blk_eng_hi "Blocking: English proficiency split"
label var blk_nat_hi "Blocking: baseline nationalism split"

label var date_baseline_m "Baseline month (%tm), e.g. June 2025"
label var date_rand_m "Randomization / camp start month (%tm)"
label var date_endline_m "Endline month (%tm), Jun–Oct 2025"
label var date_followup_m "Follow-up month (%tm), e.g. Nov 2025"

label var complete_baseline "Completed baseline survey t0 (should be 1 for 12,215 pool)"
label var complete_endline "Completed endline t1 (N=5,215; subset of randomized)"
label var complete_followup "Completed follow-up t2 (N=2,115)"

label var any_weekly_data "Any weekly app log during intervention (Jun–Oct 2025)"
label var recruited "Recruited: clicked consent and entered RCT (N=6,365)"
label var last_week_active "Last active week 1-12 (12 = completed programme)"




label var t0_age_cat "Age category (baseline)"
label var t0_female "Female (baseline)"
label var t0_ethnic_han "Han ethnicity (baseline)"
label var t0_educ "Highest education (baseline)"
label var t0_city "City of residence (string, baseline)"
label var t0_party_id "Party / political ID code (baseline)"
label var t0_exam_type "Exam preparing for (baseline)"
label var t0_exam_score "Most recent exam score (baseline)"
label var t0_prep_weeks "Weeks preparing for exam (baseline)"
label var t0_join_motivation "Main motivation for joining program (baseline)"

label var t0_freq_state "News frequency: Chinese state media (90d)"
label var t0_freq_comm "News frequency: Chinese commercial apps (90d)"
label var t0_freq_soc "News frequency: social media (90d)"
label var t0_freq_foreign "News frequency: foreign English sites (90d)"
label var t0_freq_chat "News frequency: chat-forwarded news (90d)"

label var t0_trust_state "Trust: state-run Chinese media"
label var t0_trust_comm "Trust: commercial Chinese media"
label var t0_trust_soc "Trust: social media"
label var t0_trust_foreign "Trust: foreign English outlets"
label var t0_trust_chat "Trust: chat-shared news"

label var t0_news_foreign_30d "Self-reported foreign news frequency (past month)"
label var t0_plat_tiktok "Uses TikTok (baseline)"
label var t0_plat_fb "Uses Facebook (baseline)"
label var t0_plat_tw "Uses Twitter/X (baseline)"
label var t0_plat_yt "Uses YouTube (baseline)"
label var t0_plat_ig "Uses Instagram (baseline)"
label var t0_abroad_ever "Ever lived/traveled outside mainland China"
label var t0_abroad_plan "Plans to study/live abroad (next few years)"

label var t0_rs_econ "Satisfaction: economic development (t0)"
label var t0_rs_stab "Satisfaction: social stability (t0)"
label var t0_rs_eq "Satisfaction: social equality (t0)"
label var t0_rs_tech "Satisfaction: technological progress (t0)"
label var t0_rs_gov "Satisfaction: government efficiency (t0)"
label var t0_rs_index "Regime support index (t0)"

label var t0_cen_stab "Censorship: restricting content for stability (t0)"
label var t0_cen_right "Censorship: government right to censor sensitive news (t0)"
label var t0_cen_prot "Censorship: protect citizens from disordering info (t0)"
label var t0_cen_index "Censorship attitude scale (t0)"

label var t0_therm_cn "Feeling thermometer: China (t0)"
label var t0_therm_west "Feeling thermometer: Western democracies (t0)"
label var t0_therm_gap "China minus West thermometer (t0)"

label var t0_nat_bias "Nationalism: foreign criticism usually biased (t0)"
label var t0_nat_resist "Nationalism: resist outside pressure (t0)"
label var t0_nat_proud "Nationalism: pride when China praised abroad (t0)"
label var t0_nat_unfair "Nationalism: West judges China unfairly (t0)"
label var t0_nat_index "Nationalism battery index (t0)"

label var t1_rs_econ "Satisfaction: economic development (t1)"
label var t1_rs_stab "Satisfaction: social stability (t1)"
label var t1_rs_eq "Satisfaction: social equality (t1)"
label var t1_rs_tech "Satisfaction: technological progress (t1)"
label var t1_rs_gov "Satisfaction: government efficiency (t1)"
label var t1_rs_index "Regime support index (t1, endline)"

label var t1_cen_stab "Censorship: restricting content for stability (t1)"
label var t1_cen_right "Censorship: government right to censor sensitive news (t1)"
label var t1_cen_prot "Censorship: protect citizens from disordering info (t1)"
label var t1_cen_index "Censorship attitude scale (t1)"

label var t1_therm_cn "Feeling thermometer: China (t1)"
label var t1_therm_west "Feeling thermometer: Western democracies (t1)"
label var t1_therm_gap "China minus West thermometer (t1)"

label var t1_nat_bias "Nationalism: foreign criticism usually biased (t1)"
label var t1_nat_resist "Nationalism: resist outside pressure (t1)"
label var t1_nat_proud "Nationalism: pride when China praised abroad (t1)"
label var t1_nat_unfair "Nationalism: West judges China unfairly (t1)"
label var t1_nat_index "Nationalism battery index (t1)"

label var t1_trust_state "Trust: state-run Chinese media (t1)"
label var t1_trust_comm "Trust: commercial Chinese media (t1)"
label var t1_trust_soc "Trust: social media (t1)"
label var t1_trust_foreign "Trust: foreign English outlets (t1)"
label var t1_trust_chat "Trust: chat-shared news (t1)"

label var t1_pol_econ "Policy attitude: economics cluster (t1)"
label var t1_pol_dev "Policy attitude: domestic development cluster (t1)"
label var t1_pol_cult "Policy attitude: culture & society cluster (t1)"
label var t1_pol_sci "Policy attitude: science & technology cluster (t1)"

forvalues k = 1/12 {
    label var t1_kq`k' "Knowledge item `k' correct (0/1, t1)"
}
label var t1_know_prop_all "Knowledge: proportion correct (12 items, t1)"
label var t1_know_prop10 "Knowledge: proportion correct (10 content items, t1)"

label var t1_wtp_bid "WTP bid for one-month outlet bundle (RMB, t1)"
label var t1_wtp_draw "Random drawn price (RMB, t1)"
label var t1_wtp_buy "Purchase indicator: draw <= bid (t1)"
label var t1_wtp_outlet "Chosen outlet if applicable (t1)"

label var t2_rs_econ "Satisfaction: economic development (t2)"
label var t2_rs_stab "Satisfaction: social stability (t2)"
label var t2_rs_eq "Satisfaction: social equality (t2)"
label var t2_rs_tech "Satisfaction: technological progress (t2)"
label var t2_rs_gov "Satisfaction: government efficiency (t2)"
label var t2_rs_index "Regime support index (t2, follow-up)"

label var t2_cen_stab "Censorship: restricting content for stability (t2)"
label var t2_cen_right "Censorship: government right to censor sensitive news (t2)"
label var t2_cen_prot "Censorship: protect citizens from disordering info (t2)"
label var t2_cen_index "Censorship attitude scale (t2)"

label var t2_therm_cn "Feeling thermometer: China (t2)"
label var t2_therm_west "Feeling thermometer: Western democracies (t2)"
label var t2_therm_gap "China minus West thermometer (t2)"

label var t2_nat_bias "Nationalism: foreign criticism usually biased (t2)"
label var t2_nat_resist "Nationalism: resist outside pressure (t2)"
label var t2_nat_proud "Nationalism: pride when China praised abroad (t2)"
label var t2_nat_unfair "Nationalism: West judges China unfairly (t2)"
label var t2_nat_index "Nationalism battery index (t2)"

label var t2_trust_state "Trust: state-run Chinese media (t2)"
label var t2_trust_comm "Trust: commercial Chinese media (t2)"
label var t2_trust_soc "Trust: social media (t2)"
label var t2_trust_foreign "Trust: foreign English outlets (t2)"
label var t2_trust_chat "Trust: chat-shared news (t2)"

forvalues k = 1/12 {
    label var t2_kq`k' "Knowledge item `k' correct (0/1, t2)"
}
label var t2_know_prop_all "Knowledge: proportion correct (12 items, t2)"
label var t2_know_prop10 "Knowledge: proportion correct (10 content items, t2)"

label var t2_digest_signup "Signed up for optional foreign-news digest (t2)"
label var t2_bias_cn "Perceived bias: domestic media (0–10, t2)"
label var t2_bias_west "Perceived bias: Western coverage of China (0–10, t2)"

label var t0_att_pass "Passed attention check (t0)"
label var t1_att_pass "Passed attention check (t1)"
label var t2_att_pass "Passed attention check (t2)"

label var t0_straightline_flag "Straightlining flag / low variance battery (t0)"
label var t1_straightline_flag "Straightlining flag (t1)"
label var t2_straightline_flag "Straightlining flag (t2)"

label var t0_ts_submit "Submission time (t0, %tc)"
label var t1_ts_submit "Submission time (t1, %tc)"
label var t2_ts_submit "Submission time (t2, %tc)"

label var d1_rs_index "Change regime support index: t1 - t0"
label var d2_rs_index "Change regime support index: t2 - t0"
label var d1_cen_index "Change censorship index: t1 - t0"
label var d2_cen_index "Change censorship index: t2 - t0"
label var d1_therm_gap "Change China–West gap: t1 - t0"
label var d2_therm_gap "Change China–West gap: t2 - t0"
label var d1_nat_index "Change nationalism index: t1 - t0"
label var d2_nat_index "Change nationalism index: t2 - t0"
label var d1_trust_foreign "Change trust foreign media: t1 - t0"
label var d2_trust_foreign "Change trust foreign media: t2 - t0"

label var arm1 "Dummy: arm==1 (Pro-China low)"
label var arm2 "Dummy: arm==2 (Pro-China high)"
label var arm3 "Dummy: arm==3 (Anti-China low)"
label var arm4 "Dummy: arm==4 (Anti-China high)"
label var arm5 "Dummy: arm==5 (Apolitical China)"

label var treat_valence "Treatment valence: +1 pro-China, -1 anti-China, 0 neutral/control"
label var treat_dose_hi "High political dose (1=high/arm 2|4, 0=low/arm 1|3, .=arm 5|6)"
label var n_pol_slots   "Scheduled political article slots (5=low, 20=high, 0=apolitical/control)"

label var w_n_slots "Number of scheduled content slots (typically 24)"
label var w_n_comply "Count of compliant slots (per watch+quiz rule)"
label var w_sum_read_min "Total reading minutes across slots"
label var w_sum_vid_min "Total video minutes across slots"
label var w_mean_quiz "Mean quiz score across slots (participant summary)"
label var w_mean_interest "Mean interest rating across slots"
label var w_mean_cred "Mean article credibility rating (participant summary)"
label var w_mean_similar "Mean 'want similar' rating across slots"
label var w_cnt_political_open "Count of political slots opened (schedule-dependent)"

save participant_template.dta, replace

*---------------------------------------------------------------------------
* Variable labels — weekly file
*---------------------------------------------------------------------------*/

use weekly_template.dta, clear

label var study_id "Anonymous study ID"
label var arm "Assigned arm (for weekly file merges)"
label var week "Intervention week (1–12)"
label var slot_wk "Reading slot within week (1–2)"
label var content_id "Sequential content index (1–24)"
label var article_id      "Assigned article ID (e.g. PRO_003)"
label var article_title   "Assigned article headline"
label var topic           "Topic tag from master bank"
label var bank            "Article bank: PRO / ANTI / APOL_CHINA / NONCHINA_CONTROL"
label var sched_political "1 if this slot has political content (sched_valence != 0)"
label var sched_valence   "Scheduled valence: -1 anti-China, 0 neutral/apolitical, 1 pro-China"

label var wk_open         "Opened article this slot (0/1)"
label var wk_comply       "Compliant: vid_pct>=0.8 AND quiz attempted (0/1)"
label var wk_read_min     "Minutes spent reading (missing if not opened)"
label var wk_vid_min      "Minutes of audio/video consumed"
label var wk_vid_pct      "Proportion of audio listened (0–1)"
label var wk_quiz_comprehension "Reading comprehension quiz score (0-20)"
label var wk_quiz_grammar       "Grammar and syntax quiz score (0-20)"
label var wk_quiz_vocab         "Vocabulary quiz score (0-20)"
label var wk_quiz_listen        "Listening comprehension quiz score (0-20)"
label var wk_quiz_sentence      "Sentence accumulation quiz score (0-20)"
label var wk_quiz_score         "Aggregate quiz score: sum of 5 subtests (0–100)"
label var wk_rate_interest "Article interest rating (0–100)"
label var wk_rate_cred     "Article credibility rating (0–100)"
label var wk_rate_similar  "Want more similar content (0–100)"
label var wk_open "Opened article (indicator)"
label var wk_comply "Compliance: watch + quiz thresholds met"
label var wk_read_min "Reading minutes (app log)"
label var wk_vid_min "Video minutes watched"
label var wk_vid_pct "Fraction of video watched (0–1)"
label var wk_quiz_score "Quiz score (0–10)"
label var wk_rate_interest "Article interest rating (0–100)"
label var wk_rate_cred "Perceived credibility (0–100)"
label var wk_rate_similar "Want similar stories (0–100)"
label var wk_political_delivered "Political content delivered flag (if needed)"

save weekly_template.dta, replace

display as result "Created participant_template.dta and weekly_template.dta in `c(pwd)'"

*---------------------------------------------------------------------------
* After you simulate / fill values, use logic like (uncomment to run):
*---------------------------------------------------------------------------
* // Consistency from flow_cat:
* replace attrit_pre_rct = inlist(flow_cat, 1, 2, 3)
* replace attrit_rand_no_endline = (flow_cat == 4)
* replace attrit_endline_no_fu = (flow_cat == 5)
* // Count checks (should match field totals):
* assert inlist(flow_cat,1,2,3,4,5,6) if sample_baseline_pool==1
* tab flow_cat, mi
* qui count if sample_baseline_pool==1
* assert r(N) == 12215
* qui count if inlist(flow_cat,1,2,3)
* assert r(N) == 5850
* qui count if flow_cat==4
* assert r(N) == 1150
* qui count if flow_cat==5
* assert r(N) == 3100
* qui count if flow_cat==6
* assert r(N) == 2115
* // reach_* flags (example):
* replace reach_baseline = (sample_baseline_pool==1)
* replace reach_consent = consent_rct
* replace reach_delivery = delivery_verified
* replace reach_randomized = sample_randomized
* replace reach_endline = complete_endline
* replace reach_followup = complete_followup
*---------------------------------------------------------------------------
