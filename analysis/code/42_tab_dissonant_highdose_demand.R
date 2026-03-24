source(file.path("code", "_table_helpers.R"))

political_demand <- read_dta(file.path(root_dir, "data", "weekly_long.dta")) |>
  mutate(
    study_id = as.integer(study_id),
    arm = as.integer(arm)
  ) |>
  filter(slot_wk == 1, sched_political == 1) |>
  group_by(study_id, arm) |>
  summarise(
    pol_mean_interest = mean(wk_rate_interest, na.rm = TRUE),
    pol_mean_similar = mean(wk_rate_similar, na.rm = TRUE),
    .groups = "drop"
  )

participant <- prepare_participant() |>
  left_join(political_demand, by = c("study_id", "arm"))

contrast_outcomes <- tribble(
  ~sample,      ~outcome,             ~label,                                     ~controls,
  "endline",    "pol_mean_interest",  "Political-slot interest rating",           list(c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign")),
  "endline",    "pol_mean_similar",   "Political-slot want-more rating",          list(c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign")),
  "endline",    "t1_wtp_bid",         "WTP bid (RMB)",                            list(c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign")),
  "endline",    "t1_wtp_buy",         "WTP buy indicator",                        list(c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t1_wtp_draw")),
  "followup",   "t2_digest_signup",   "Digest signup",                            list(c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign"))
)

pair_contrasts <- function(data, outcome, label, controls) {
  dat <- data |>
    filter(arm %in% 1:4) |>
    select(all_of(c(outcome, controls)), arm_label, block_id) |>
    filter(!is.na(.data[[outcome]]), !is.na(block_id))

  for (cc in controls) {
    dat <- dat |> filter(!is.na(.data[[cc]]))
  }

  dat <- dat |>
    mutate(
      arm_label = droplevels(arm_label),
      arm_label = relevel(arm_label, ref = "pro_low")
    )

  mod <- lm(
    reformulate(c("arm_label", controls, "factor(block_id)"), response = outcome),
    data = dat
  )

  bind_rows(
    linear_contrast(mod, c("arm_labelpro_high" = 1), "Pro high - Pro low", label, NA_real_, nrow(dat)),
    linear_contrast(mod, c("arm_labelanti_low" = 1, "arm_labelpro_high" = -1), "Anti low - Pro high (unused)", label, NA_real_, nrow(dat)),
    linear_contrast(mod, c("arm_labelanti_high" = 1, "arm_labelanti_low" = -1), "Anti high - Anti low", label, NA_real_, nrow(dat))
  ) |>
    filter(term %in% c("Pro high - Pro low", "Anti high - Anti low"))
}

results <- pmap_dfr(
  contrast_outcomes,
  function(sample, outcome, label, controls) {
    dat <- if (sample == "endline") {
      participant |> filter(recruited == 1, complete_endline == 1)
    } else {
      participant |> filter(recruited == 1, complete_followup == 1)
    }

    pair_contrasts(dat, outcome, label, unlist(controls, use.names = FALSE))
  }
) |>
  mutate(
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
  file.path(tables_dir, "tab_dissonant_highdose_demand.tex"),
  "Dose Contrasts for Continued Demand and Interest Within Political Frames",
  "tab:dissonant_highdose_demand",
  align = "llcccc",
  notes = "Entries report within-frame high-versus-low dose contrasts among the political treatment arms only. The table is designed to map as closely as possible to the registered hypothesis that ideologically dissonant high-dose exposure should suppress continued demand. `Political-slot' outcomes aggregate ratings over the political slot-1 articles only. Endline models include baseline exam score, baseline regime support, baseline nationalism, baseline trust in foreign media, and randomization-block fixed effects; the WTP purchase-indicator model additionally controls for the randomized BDM draw. The digest-signup model uses the follow-up sample."
)

message("Wrote tables/tab_dissonant_highdose_demand.tex")
