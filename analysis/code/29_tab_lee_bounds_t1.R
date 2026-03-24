source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
recruited <- participant |> filter(recruited == 1)
endline <- recruited |> filter(complete_endline == 1)

contrast_specs <- tribble(
  ~var,       ~label,
  "pro_any",  "Pooled Pro-China",
  "anti_any", "Pooled Anti-China",
  "apol",     "Apolitical China"
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

lee_bound_pair <- function(data, outcome, baseline, treat_var) {
  dat_pair <- data |>
    filter(.data[[treat_var]] == 1 | arm == 6) |>
    mutate(treat = as.integer(.data[[treat_var]] == 1))

  resp_t <- mean(dat_pair$complete_endline[dat_pair$treat == 1], na.rm = TRUE)
  resp_c <- mean(dat_pair$complete_endline[dat_pair$treat == 0], na.rm = TRUE)

  observed <- run_pooled_ancova(
    data |> filter(complete_endline == 1),
    outcome,
    baseline,
    "tmp"
  ) |>
    filter(term == treat_var) |>
    slice(1) |>
    pull(estimate)

  obs_dat <- dat_pair |>
    filter(complete_endline == 1) |>
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
    response_treat = resp_t,
    response_control = resp_c,
    observed = observed,
    lee_lower = lower,
    lee_upper = upper
  )
}

results <- pmap_dfr(
  main_outcome_map(),
  function(outcome, baseline, label) {
    outcome_label <- label
    pmap_dfr(
      contrast_specs,
      function(var, label) {
        lee_bound_pair(recruited, outcome, baseline, var) |>
          mutate(
            Outcome = outcome_label,
            Contrast = label
          )
      }
    )
  }
) |>
  mutate(
    `Response rate (T)` = fmt_num(response_treat, 3),
    `Response rate (C)` = fmt_num(response_control, 3),
    `Observed ITT` = fmt_num(observed, 3),
    `Lee lower` = fmt_num(lee_lower, 3),
    `Lee upper` = fmt_num(lee_upper, 3)
  ) |>
  select(Outcome, Contrast, `Response rate (T)`, `Response rate (C)`, `Observed ITT`, `Lee lower`, `Lee upper`)

write_latex_df(
  results,
  file.path(tables_dir, "tab_lee_bounds_t1.tex"),
  "Lee Bounds for Endline Treatment Effects Under Attrition",
  "tab:lee_bounds_t1",
  align = "llccccc",
  notes = "Entries report Lee (2009) monotonicity bounds for pooled treatment contrasts relative to the non-China control arm. Outcomes are first residualized on the corresponding baseline value and randomization-block fixed effects among endline respondents; trimming is then applied to the group with the higher endline response rate so that treatment and control response rates are equalized within each pairwise comparison. `Observed ITT' reports the corresponding pooled ANCOVA estimate from the observed endline sample."
)

message("Wrote tables/tab_lee_bounds_t1.tex")
