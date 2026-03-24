source(file.path("code", "_table_helpers.R"))

set.seed(20260323)

slot1_acceptance <- read_dta(file.path(root_dir, "data", "weekly_long.dta")) |>
  mutate(
    study_id = as.integer(study_id),
    arm = as.integer(arm)
  ) |>
  filter(slot_wk == 1) |>
  group_by(study_id, arm) |>
  summarise(
    slot1_mean_cred = mean(wk_rate_cred, na.rm = TRUE),
    slot1_mean_interest = mean(wk_rate_interest, na.rm = TRUE),
    .groups = "drop"
  )

participant <- prepare_participant() |>
  left_join(slot1_acceptance, by = c("study_id", "arm")) |>
  filter(recruited == 1, complete_endline == 1, arm %in% 1:5)

participant <- participant |>
  mutate(
    cred_z = z_from_ref(slot1_mean_cred, slot1_mean_cred[arm %in% 1:5]),
    interest_z = z_from_ref(slot1_mean_interest, slot1_mean_interest[arm %in% 1:5]),
    acceptance_z = rowMeans(cbind(cred_z, interest_z), na.rm = TRUE)
  )

mediation_specs <- tribble(
  ~contrast_arm, ~contrast_label,      ~outcome,            ~baseline,           ~outcome_label,
  "pro",         "Pro vs Apolitical",  "t1_rs_index",       "t0_rs_index",       "Regime support",
  "anti",        "Anti vs Apolitical", "t1_rs_index",       "t0_rs_index",       "Regime support",
  "pro",         "Pro vs Apolitical",  "t1_trust_foreign",  "t0_trust_foreign",  "Trust in foreign media",
  "anti",        "Anti vs Apolitical", "t1_trust_foreign",  "t0_trust_foreign",  "Trust in foreign media"
)

estimate_mediation <- function(data, outcome, baseline, contrast_arm, n_boot = 300L) {
  dat <- if (contrast_arm == "pro") {
    data |>
      filter(arm %in% c(1, 2, 5)) |>
      mutate(treat = as.integer(arm %in% c(1, 2)))
  } else {
    data |>
      filter(arm %in% c(3, 4, 5)) |>
      mutate(treat = as.integer(arm %in% c(3, 4)))
  }

  dat <- dat |>
    select(all_of(c(outcome, baseline, "acceptance_z", "t0_exam_score", "t0_nat_index", "t0_trust_foreign")), treat, block_id) |>
    filter(
      !is.na(.data[[outcome]]),
      !is.na(.data[[baseline]]),
      !is.na(acceptance_z),
      !is.na(t0_exam_score),
      !is.na(t0_nat_index),
      !is.na(t0_trust_foreign),
      !is.na(block_id)
    )

  med_mod <- lm(
    as.formula(
      paste0(
        "acceptance_z ~ treat + ", baseline,
        " + t0_exam_score + t0_nat_index + t0_trust_foreign + factor(block_id)"
      )
    ),
    data = dat
  )

  out_mod <- lm(
    as.formula(
      paste0(
        outcome,
        " ~ treat + acceptance_z + ", baseline,
        " + t0_exam_score + t0_nat_index + t0_trust_foreign + factor(block_id)"
      )
    ),
    data = dat
  )

  med_tidy <- tidy_hc2(med_mod)
  out_tidy <- tidy_hc2(out_mod)
  a1 <- med_tidy |> filter(term == "treat") |> slice(1)
  b1 <- out_tidy |> filter(term == "acceptance_z") |> slice(1)
  direct_row <- out_tidy |> filter(term == "treat") |> slice(1)
  indirect_est <- a1$estimate * b1$estimate

  boot_indirect <- replicate(
    n_boot,
    {
      idx <- sample.int(nrow(dat), nrow(dat), replace = TRUE)
      boot_dat <- dat[idx, , drop = FALSE]

      med_b <- lm(
        as.formula(
          paste0(
            "acceptance_z ~ treat + ", baseline,
            " + t0_exam_score + t0_nat_index + t0_trust_foreign + factor(block_id)"
          )
        ),
        data = boot_dat
      )
      out_b <- lm(
        as.formula(
          paste0(
            outcome,
            " ~ treat + acceptance_z + ", baseline,
            " + t0_exam_score + t0_nat_index + t0_trust_foreign + factor(block_id)"
          )
        ),
        data = boot_dat
      )

      coef(med_b)[["treat"]] * coef(out_b)[["acceptance_z"]]
    }
  )

  tibble(
    a_path = a1$estimate,
    a_p = a1$p.value,
    b_path = b1$estimate,
    b_p = b1$p.value,
    indirect = indirect_est,
    indirect_lo = quantile(boot_indirect, 0.025, na.rm = TRUE),
    indirect_hi = quantile(boot_indirect, 0.975, na.rm = TRUE),
    direct = direct_row$estimate,
    direct_p = direct_row$p.value,
    n = nrow(dat)
  )
}

results <- pmap_dfr(
  mediation_specs,
  function(contrast_arm, contrast_label, outcome, baseline, outcome_label) {
    estimate_mediation(participant, outcome, baseline, contrast_arm) |>
      mutate(
        Contrast = contrast_label,
        Outcome = outcome_label
      )
  }
) |>
  mutate(
    `a-path: T -> acceptance` = paste0(fmt_num(a_path, 3), sig_stars(a_p)),
    `b-path: acceptance -> Y` = paste0(fmt_num(b_path, 3), sig_stars(b_p)),
    `Indirect effect` = fmt_num(indirect, 3),
    `Bootstrap 95% CI` = paste0("[", fmt_num(indirect_lo, 3), ", ", fmt_num(indirect_hi, 3), "]"),
    `Direct effect` = paste0(fmt_num(direct, 3), sig_stars(direct_p)),
    N = fmt_int(n)
  ) |>
  select(
    Outcome,
    Contrast,
    `a-path: T -> acceptance`,
    `b-path: acceptance -> Y`,
    `Indirect effect`,
    `Bootstrap 95% CI`,
    `Direct effect`,
    N
  )

write_latex_df(
  results,
  file.path(tables_dir, "tab_acceptance_mediation.tex"),
  "Exploratory Mediation via Acceptance of Assigned Content",
  "tab:acceptance_mediation",
  align = "llcccccc",
  notes = "Entries implement a product-of-coefficients mediation design that maps as closely as possible to the registered acceptance mechanism. The mediator is a participant-level acceptance composite averaging standardized slot-1 credibility and interest ratings over assigned weekly content. Each contrast compares a pooled political frame to the apolitical-China arm only. The mediator model includes treatment, the baseline value of the outcome, baseline exam score, baseline nationalism, baseline trust in foreign media, and randomization-block fixed effects; the outcome model adds the mediator. `Indirect effect' equals the estimated a-path times the b-path, and the confidence interval is a nonparametric bootstrap interval with 300 resamples. Because the mediator is post-treatment, these estimates should be interpreted as suggestive mechanism evidence rather than design-based causal mediation."
)

message("Wrote tables/tab_acceptance_mediation.tex")
