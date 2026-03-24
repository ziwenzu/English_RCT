source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
base_covars <- default_weighting_covariates()

weekly <- read_dta(file.path(root_dir, "data", "weekly_long.dta")) |>
  left_join(
    participant |>
      select(study_id, block_id, all_of(base_covars)),
    by = "study_id"
  ) |>
  mutate(
    arm = as.integer(arm),
    study_id = as.integer(study_id),
    week = as.integer(week),
    slot_wk = as.integer(slot_wk),
    pro_any = as.integer(arm %in% c(1L, 2L)),
    anti_any = as.integer(arm %in% c(3L, 4L)),
    apol = as.integer(arm == 5L)
  ) |>
  filter(slot_wk == 1)

weekly_specs <- tribble(
  ~outcome,          ~label,
  "wk_comply",       "Compliance",
  "wk_read_min",     "Reading minutes",
  "wk_rate_cred",    "Credibility rating",
  "wk_rate_similar", "Want more similar"
)

fit_weekly_model <- function(data, outcome_name, spec_label, weights = NULL) {
  mod <- if (is.null(weights)) {
    lm(
      as.formula(paste0(outcome_name, " ~ pro_any + anti_any + apol + factor(week) + factor(block_id)")),
      data = data
    )
  } else {
    lm(
      as.formula(paste0(outcome_name, " ~ pro_any + anti_any + apol + factor(week) + factor(block_id)")),
      data = data,
      weights = weights
    )
  }

  vc <- cluster_vcov(mod, data$study_id)
  tidy_with_vcov(mod, vc) |>
    filter(term %in% c("pro_any", "anti_any", "apol")) |>
    mutate(specification = spec_label, n = nrow(data))
}

results <- pmap_dfr(
  weekly_specs,
  function(outcome, label) {
    observed_dat <- weekly |>
      filter(!is.na(.data[[outcome]]), !is.na(block_id))

    zero_dat <- weekly |>
      filter(!is.na(block_id)) |>
      mutate("{outcome}" := if_else(is.na(.data[[outcome]]), 0, .data[[outcome]]))

    ipw_base <- weekly |>
      filter(!is.na(block_id)) |>
      mutate(observed_outcome = as.integer(!is.na(.data[[outcome]])))

    ipw_design <- add_imputed_covariates(ipw_base, base_covars)
    ipw_dat <- ipw_design$data

    obs_model <- suppressWarnings(
      glm(
        reformulate(
          c("pro_any", "anti_any", "apol", "factor(week)", "factor(block_id)", ipw_design$terms),
          response = "observed_outcome"
        ),
        data = ipw_dat,
        family = binomial()
      )
    )

    ipw_obs <- ipw_dat |>
      mutate(
        p_obs = trim_probabilities(predict(obs_model, type = "response")),
        obs_weight = normalize_weights(1 / p_obs)
      ) |>
      filter(observed_outcome == 1)

    bind_rows(
      fit_weekly_model(observed_dat, outcome, "Observed-only"),
      fit_weekly_model(zero_dat, outcome, "Zero-imputed after dropout"),
      fit_weekly_model(ipw_obs, outcome, "IPW weekly cells", weights = ipw_obs$obs_weight)
    ) |>
      mutate(outcome_label = label)
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
    Outcome = outcome_label,
    Specification = specification,
    Contrast,
    Estimate,
    `Std. Error`,
    `p-value`,
    N
  ) |>
  arrange(Outcome, Specification, Contrast)

write_latex_df(
  results,
  file.path(tables_dir, "tab_weekly_selection_robustness.tex"),
  "Weekly Panel Robustness to Dropout and Cell Nonresponse",
  "tab:weekly_selection_robustness",
  align = "lllcccc",
  notes = "Entries report pooled treatment contrasts relative to the non-China control arm using slot-1 weekly observations. `Observed-only' uses non-missing weekly outcomes. `Zero-imputed after dropout' sets missing weekly outcomes to zero on the full scheduled panel. `IPW weekly cells' reweights observed weekly cells by the inverse predicted probability of observing the corresponding outcome, estimated from treatment indicators, week fixed effects, randomization-block fixed effects, and baseline covariates; predicted probabilities are trimmed to [0.05, 0.95]. Standard errors are clustered at the participant level."
)

message("Wrote tables/tab_weekly_selection_robustness.tex")
