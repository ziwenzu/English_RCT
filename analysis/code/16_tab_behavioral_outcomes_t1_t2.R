source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
endline <- participant |> filter(recruited == 1, complete_endline == 1)
followup <- participant |> filter(recruited == 1, complete_followup == 1)

behavior_specs <- tribble(
  ~dataset, ~outcome,           ~label,                         ~controls,
  "t1",     "t1_wtp_bid",       "WTP bid (RMB)",               list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "t1",     "t1_wtp_buy",       "WTP buy indicator",           list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score", "t1_wtp_draw")),
  "t1",     "t1_know_prop10",   "Knowledge retention",         list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "t2",     "t2_digest_signup", "Digest signup",               list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "t2",     "t2_bias_cn",       "Perceived bias: China media", list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "t2",     "t2_bias_west",     "Perceived bias: Western media", list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score"))
)

results <- pmap_dfr(
  behavior_specs,
  function(dataset, outcome, label, controls) {
    dat <- if (dataset == "t1") endline else followup
    run_pooled_model(
      dat,
      outcome,
      label,
      controls = unlist(controls, use.names = FALSE),
      vcov = "HC2"
    )
  }
) |>
  mutate(
    term = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China"
    ),
    Estimate = paste0(fmt_num(estimate, 3), sig_stars(p.value)),
    `Std. Error` = fmt_num(std.error, 3),
    `p-value` = fmt_p(p.value),
    N = fmt_int(n)
  ) |>
  transmute(
    Outcome = outcome_label,
    Contrast = term,
    Estimate,
    `Std. Error`,
    `p-value`,
    N
  ) |>
  arrange(Outcome, Contrast)

write_latex_df(
  results,
  file.path(tables_dir, "tab_behavioral_outcomes_t1_t2.tex"),
  "Behavioral and Mechanism Outcomes",
  "tab:behavioral_outcomes_t1_t2",
  align = "llcccc",
  notes = "Entries report pooled treatment contrasts relative to the non-China control arm. Continuous outcomes are estimated by OLS and binary outcomes by linear probability models for comparability. T1 outcomes are estimated on endline respondents; T2 outcomes are estimated on follow-up respondents. All specifications include randomization-block fixed effects and baseline covariates for regime support, nationalism, trust in foreign media, and exam performance. The WTP purchase-indicator model additionally controls for the randomized BDM draw (`t1_wtp_draw`) to improve precision. Heteroskedasticity-robust HC2 standard errors are reported in the table. Significance: + p $<$ 0.10, * p $<$ 0.05, ** p $<$ 0.01, *** p $<$ 0.001."
)

message("Wrote tables/tab_behavioral_outcomes_t1_t2.tex")
