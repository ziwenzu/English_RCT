source(file.path("code", "_table_helpers.R"))

suppressPackageStartupMessages({
  library(fixest)
})

participant <- prepare_participant()
recruited <- participant |>
  filter(recruited == 1) |>
  mutate(followup_observed = if_else(complete_followup == 1, 1L, 0L, missing = 0L))
followup <- recruited |>
  filter(complete_followup == 1)

weight_covars <- default_weighting_covariates()

ipw_design <- add_imputed_covariates(recruited, weight_covars)
recruited_ipw <- ipw_design$data

followup_ps_model <- glm(
  reformulate(
    c("pro_any", "anti_any", "apol", ipw_design$terms, "factor(block_id)"),
    response = "followup_observed"
  ),
  data = recruited_ipw,
  family = binomial()
)

recruited_ipw <- recruited_ipw |>
  mutate(
    p_followup = trim_probabilities(predict(followup_ps_model, type = "response")),
    ipw_followup = normalize_weights(1 / p_followup)
  )

trimmed_mean <- function(x, trim_share, trim = c("none", "top", "bottom")) {
  trim <- match.arg(trim)
  x <- sort(x)
  if (trim == "none" || trim_share <= 0) {
    return(mean(x, na.rm = TRUE))
  }
  n_trim <- floor(length(x) * trim_share)
  if (n_trim <= 0) {
    return(mean(x, na.rm = TRUE))
  }
  if (trim == "top") {
    x <- x[seq_len(length(x) - n_trim)]
  } else {
    x <- x[(n_trim + 1):length(x)]
  }
  mean(x, na.rm = TRUE)
}

lee_bound_pair_t2 <- function(data, outcome, baseline, treat_var) {
  dat_pair <- data |>
    filter(.data[[treat_var]] == 1 | arm == 6) |>
    mutate(treat = as.integer(.data[[treat_var]] == 1))

  resp_t <- mean(dat_pair$followup_observed[dat_pair$treat == 1], na.rm = TRUE)
  resp_c <- mean(dat_pair$followup_observed[dat_pair$treat == 0], na.rm = TRUE)

  observed <- run_pooled_ancova(
    data |> filter(complete_followup == 1),
    outcome,
    baseline,
    "tmp"
  ) |>
    filter(term == treat_var) |>
    slice(1) |>
    pull(estimate)

  obs_dat <- dat_pair |>
    filter(complete_followup == 1) |>
    select(all_of(c(outcome, baseline)), block_id, treat) |>
    filter(!is.na(.data[[outcome]]), !is.na(.data[[baseline]]), !is.na(block_id))

  resid_mod <- lm(as.formula(paste0(outcome, " ~ ", baseline, " + factor(block_id)")), data = obs_dat)
  obs_dat <- obs_dat |>
    mutate(resid_y = resid(resid_mod))

  treat_y <- obs_dat$resid_y[obs_dat$treat == 1]
  control_y <- obs_dat$resid_y[obs_dat$treat == 0]

  if (resp_t >= resp_c) {
    trim_share <- 1 - (resp_c / resp_t)
    lower <- trimmed_mean(treat_y, trim_share, "top") - mean(control_y, na.rm = TRUE)
    upper <- trimmed_mean(treat_y, trim_share, "bottom") - mean(control_y, na.rm = TRUE)
  } else {
    trim_share <- 1 - (resp_t / resp_c)
    lower <- mean(treat_y, na.rm = TRUE) - trimmed_mean(control_y, trim_share, "bottom")
    upper <- mean(treat_y, na.rm = TRUE) - trimmed_mean(control_y, trim_share, "top")
  }

  tibble(
    observed = observed,
    lee_lower = lower,
    lee_upper = upper
  )
}

coef_row <- function(model, term) {
  ct <- summary(model)$coeftable
  tibble(
    estimate = unname(ct[term, "Estimate"]),
    std.error = unname(ct[term, "Std. Error"]),
    p.value = unname(ct[term, "Pr(>|t|)"])
  )
}

balanced_followup_fe <- function(data, baseline, endline, followup, outcome_label) {
  dat <- data |>
    select(study_id, pro_any, anti_any, apol, all_of(c(baseline, endline, followup))) |>
    transmute(
      study_id,
      pro_any,
      anti_any,
      apol,
      t0 = .data[[baseline]],
      t1 = .data[[endline]],
      t2 = .data[[followup]]
    ) |>
    pivot_longer(
      cols = c(t0, t1, t2),
      names_to = "wave",
      values_to = "y"
    ) |>
    filter(!is.na(y)) |>
    mutate(wave = factor(wave, levels = c("t0", "t1", "t2")))

  mod <- feols(
    y ~ i(wave, pro_any, ref = "t0") + i(wave, anti_any, ref = "t0") + i(wave, apol, ref = "t0") | study_id + wave,
    cluster = ~ study_id,
    data = dat
  )

  bind_rows(
    coef_row(mod, "wave::t2:pro_any") |> mutate(term = "pro_any"),
    coef_row(mod, "wave::t2:anti_any") |> mutate(term = "anti_any"),
    coef_row(mod, "wave::t2:apol") |> mutate(term = "apol")
  ) |>
    mutate(outcome_label = outcome_label)
}

balanced_panel <- recruited |>
  filter(complete_endline == 1, complete_followup == 1)

observed_results <- pmap_dfr(
  t2_outcome_map(),
  function(outcome, baseline, label) {
    run_pooled_ancova(followup, outcome, baseline, label)
  }
) |>
  select(outcome_label, term, estimate, p.value) |>
  rename(observed_est = estimate, observed_p = p.value)

ipw_results <- pmap_dfr(
  t2_outcome_map(),
  function(outcome, baseline, label) {
    dat <- recruited_ipw |>
      filter(complete_followup == 1) |>
      select(all_of(c(outcome, baseline, "ipw_followup")), pro_any, anti_any, apol, block_id, arm_label) |>
      filter(!is.na(.data[[outcome]]), !is.na(.data[[baseline]]), !is.na(block_id), !is.na(ipw_followup))

    mod <- lm(
      as.formula(paste0(outcome, " ~ pro_any + anti_any + apol + ", baseline, " + factor(block_id)")),
      data = dat,
      weights = ipw_followup
    )

    tidy_with_vcov(mod, sandwich::vcovHC(mod, type = "HC2")) |>
      filter(term %in% c("pro_any", "anti_any", "apol")) |>
      mutate(outcome_label = label)
  }
) |>
  select(outcome_label, term, estimate, p.value) |>
  rename(ipw_est = estimate, ipw_p = p.value)

lee_results <- pmap_dfr(
  t2_outcome_map(),
  function(outcome, baseline, label) {
    bind_rows(
      lee_bound_pair_t2(recruited, outcome, baseline, "pro_any") |> mutate(term = "pro_any"),
      lee_bound_pair_t2(recruited, outcome, baseline, "anti_any") |> mutate(term = "anti_any"),
      lee_bound_pair_t2(recruited, outcome, baseline, "apol") |> mutate(term = "apol")
    ) |>
      mutate(outcome_label = label)
  }
)

balanced_results <- pmap_dfr(
  t2_outcome_map() |>
    mutate(endline = main_outcome_map()$outcome),
  function(outcome, baseline, label, endline) {
    balanced_followup_fe(balanced_panel, baseline, endline, outcome, label)
  }
) |>
  select(outcome_label, term, estimate, p.value) |>
  rename(balanced_est = estimate, balanced_p = p.value)

results <- observed_results |>
  left_join(ipw_results, by = c("outcome_label", "term")) |>
  left_join(lee_results, by = c("outcome_label", "term")) |>
  left_join(balanced_results, by = c("outcome_label", "term")) |>
  mutate(
    Contrast = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China"
    ),
    `Observed ANCOVA` = paste0(fmt_num(observed_est, 3), sig_stars(observed_p)),
    `IPW ANCOVA` = paste0(fmt_num(ipw_est, 3), sig_stars(ipw_p)),
    `Lee lower` = fmt_num(lee_lower, 3),
    `Lee upper` = fmt_num(lee_upper, 3),
    `Balanced-panel FE` = paste0(fmt_num(balanced_est, 3), sig_stars(balanced_p))
  ) |>
  transmute(
    Outcome = outcome_label,
    Contrast,
    `Observed ANCOVA`,
    `IPW ANCOVA`,
    `Lee lower`,
    `Lee upper`,
    `Balanced-panel FE`
  ) |>
  arrange(Outcome, Contrast)

write_latex_df(
  results,
  file.path(tables_dir, "tab_t2_attrition_sensitivity.tex"),
  "Follow-up Attrition Sensitivity for the Primary Outcome Family",
  "tab:t2_attrition_sensitivity",
  align = "llccccc",
  notes = "Entries compare four follow-up estimators for pooled treatment contrasts relative to the non-China control arm. `Observed ANCOVA' reports the baseline-controlled follow-up ANCOVA. `IPW ANCOVA' reweights follow-up respondents by the inverse predicted probability of completing the follow-up survey using treatment indicators, baseline covariates, and randomization-block fixed effects; predicted probabilities are trimmed to [0.05, 0.95]. `Lee lower' and `Lee upper' report Lee (2009) monotonicity bounds. `Balanced-panel FE' reports the follow-up treatment effect from individual fixed-effects panel models estimated on the balanced three-wave panel."
)

message("Wrote tables/tab_t2_attrition_sensitivity.tex")
