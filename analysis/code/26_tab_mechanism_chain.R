source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
recruited <- participant |> filter(recruited == 1)
endline <- recruited |> filter(complete_endline == 1)
followup <- recruited |> filter(complete_followup == 1)

mechanism_specs <- tribble(
  ~stage,                ~sample,    ~outcome,            ~label,                      ~controls,
  "Weekly engagement",   "recruited","w_n_comply",        "Compliant slots",           list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Weekly engagement",   "recruited","w_sum_read_min",    "Total reading minutes",     list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Weekly acceptance",   "recruited","w_mean_cred",       "Mean credibility rating",   list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Weekly acceptance",   "recruited","w_mean_similar",    "Mean want-more rating",     list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Immediate demand",    "endline",  "t1_wtp_bid",        "WTP bid (RMB)",             list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Immediate demand",    "endline",  "t1_wtp_buy",        "WTP buy indicator",         list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score", "t1_wtp_draw")),
  "Post-study demand",   "followup", "t2_digest_signup",  "Digest signup",             list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score"))
)

results <- pmap_dfr(
  mechanism_specs,
  function(stage, sample, outcome, label, controls) {
    dat <- switch(
      sample,
      recruited = recruited,
      endline = endline,
      followup = followup
    )

    run_pooled_model(
      dat,
      outcome,
      label,
      controls = unlist(controls, use.names = FALSE),
      vcov = "HC2"
    ) |>
      mutate(stage = stage)
  }
) |>
  mutate(
    Contrast = dplyr::recode(
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
    Stage = stage,
    Outcome = outcome_label,
    Contrast,
    Estimate,
    `Std. Error`,
    `p-value`,
    N
  ) |>
  arrange(factor(Stage, levels = c("Weekly engagement", "Weekly acceptance", "Immediate demand", "Post-study demand")), Outcome, Contrast)

write_latex_df(
  results,
  file.path(tables_dir, "tab_mechanism_chain.tex"),
  "Mechanism Chain: Weekly Behavior, Acceptance, and Continued Demand",
  "tab:mechanism_chain",
  align = "lllcccc",
  notes = "Entries report pooled treatment contrasts relative to the non-China control arm. Weekly outcomes are participant-level aggregates over the 12-week study; endline and follow-up outcomes are measured in the corresponding survey waves. All models include randomization-block fixed effects and baseline covariates for regime support, nationalism, trust in foreign media, and exam performance. The WTP purchase-indicator model additionally controls for the randomized BDM draw."
)

message("Wrote tables/tab_mechanism_chain.tex")
