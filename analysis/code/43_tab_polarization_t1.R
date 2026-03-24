source(file.path("code", "_table_helpers.R"))

suppressPackageStartupMessages({
  library(quantreg)
})

participant <- prepare_participant() |>
  filter(recruited == 1, complete_endline == 1, arm %in% 1:5)

brown_forsythe_two_group <- function(data, outcome, baseline, treat_arms, contrast_label, outcome_label) {
  dat <- data |>
    filter(arm %in% c(treat_arms, 5)) |>
    mutate(
      treat = as.integer(arm %in% treat_arms)
    ) |>
    select(all_of(c(outcome, baseline)), treat, block_id) |>
    filter(!is.na(.data[[outcome]]), !is.na(.data[[baseline]]), !is.na(block_id))

  grp_median <- dat |>
    group_by(treat) |>
    summarise(group_median = median(.data[[outcome]], na.rm = TRUE), .groups = "drop")

  dat <- dat |>
    left_join(grp_median, by = "treat") |>
    mutate(abs_dev = abs(.data[[outcome]] - group_median))

  mod <- lm(
    as.formula(paste0("abs_dev ~ treat + ", baseline, " + factor(block_id)")),
    data = dat
  )
  est <- tidy_hc2(mod) |>
    filter(term == "treat") |>
    slice(1)

  tibble(
    Panel = "Panel A: Brown-Forsythe dispersion",
    Outcome = outcome_label,
    Contrast = contrast_label,
    Estimate = paste0(fmt_num(est$estimate, 3), sig_stars(est$p.value)),
    `Std. Error` = fmt_num(est$std.error, 3),
    `p-value` = fmt_p(est$p.value),
    N = fmt_int(nrow(dat))
  )
}

qte_row <- function(data, tau, treat_arms, contrast_label) {
  dat <- data |>
    filter(arm %in% c(treat_arms, 5)) |>
    mutate(
      treat = as.integer(arm %in% treat_arms)
    ) |>
    select(t1_rs_index, t0_rs_index, treat, block_id) |>
    filter(!is.na(t1_rs_index), !is.na(t0_rs_index), !is.na(block_id))

  mod <- rq(
    t1_rs_index ~ treat + t0_rs_index + factor(block_id),
    tau = tau,
    data = dat
  )
  summ <- summary(mod, se = "nid")
  est <- summ$coefficients["treat", ]

  tibble(
    Panel = "Panel B: Quantile treatment effects for regime support",
    Outcome = paste0("Regime support, q", sprintf("%02d", round(100 * tau))),
    Contrast = contrast_label,
    Estimate = paste0(fmt_num(est[1], 3), sig_stars(est[4])),
    `Std. Error` = fmt_num(est[2], 3),
    `p-value` = fmt_p(est[4]),
    N = fmt_int(nrow(dat))
  )
}

panel_a <- pmap_dfr(
  main_outcome_map(),
  function(outcome, baseline, label) {
    bind_rows(
      brown_forsythe_two_group(participant, outcome, baseline, c(1, 2), "Pooled Pro vs Apolitical", label),
      brown_forsythe_two_group(participant, outcome, baseline, c(3, 4), "Pooled Anti vs Apolitical", label)
    )
  }
)

panel_b <- bind_rows(
  qte_row(participant, 0.10, c(1, 2), "Pooled Pro vs Apolitical"),
  qte_row(participant, 0.10, c(3, 4), "Pooled Anti vs Apolitical"),
  qte_row(participant, 0.50, c(1, 2), "Pooled Pro vs Apolitical"),
  qte_row(participant, 0.50, c(3, 4), "Pooled Anti vs Apolitical"),
  qte_row(participant, 0.90, c(1, 2), "Pooled Pro vs Apolitical"),
  qte_row(participant, 0.90, c(3, 4), "Pooled Anti vs Apolitical")
)

results <- bind_rows(panel_a, panel_b)

write_latex_df(
  results,
  file.path(tables_dir, "tab_polarization_t1.tex"),
  "Polarization Tests at Endline",
  "tab:polarization_t1",
  align = "lllcccc",
  notes = "Panel A reports Brown-Forsythe style dispersion tests implemented as ANCOVA regressions of absolute deviations from the within-group median on treatment, the lagged outcome, and randomization-block fixed effects, estimated separately for Pro-versus-Apolitical and Anti-versus-Apolitical comparisons. Panel B reports quantile treatment effects for regime support at the 10th, 50th, and 90th percentiles using quantile regressions with the lagged dependent variable and randomization-block fixed effects. These analyses are intended to approximate the registered polarization tests in the implemented six-arm design."
)

message("Wrote tables/tab_polarization_t1.tex")
