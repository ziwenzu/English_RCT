source(file.path("code", "_table_helpers.R"))

suppressPackageStartupMessages({
  library(fixest)
})

panel_specs <- tribble(
  ~baseline,          ~endline,            ~followup,           ~label,
  "t0_rs_index",      "t1_rs_index",       "t2_rs_index",       "Regime support",
  "t0_cen_index",     "t1_cen_index",      "t2_cen_index",      "Censorship support",
  "t0_nat_index",     "t1_nat_index",      "t2_nat_index",      "Nationalism",
  "t0_therm_gap",     "t1_therm_gap",      "t2_therm_gap",      "China-West thermometer gap",
  "t0_trust_foreign", "t1_trust_foreign",  "t2_trust_foreign",  "Trust in foreign media"
)

participant <- prepare_participant() |>
  filter(recruited == 1)

coef_row <- function(model, term) {
  ct <- summary(model)$coeftable
  tibble(
    estimate = unname(ct[term, "Estimate"]),
    std.error = unname(ct[term, "Std. Error"]),
    p.value = unname(ct[term, "Pr(>|t|)"])
  )
}

contrast_row <- function(model, end_term, follow_term, contrast_label, outcome_label, n_id, n_obs) {
  vc <- vcov(model)
  beta <- coef(model)

  end_row <- coef_row(model, end_term)
  follow_row <- coef_row(model, follow_term)

  cvec <- rep(0, length(beta))
  names(cvec) <- names(beta)
  cvec[follow_term] <- 1
  cvec[end_term] <- -1

  diff_est <- sum(cvec * beta)
  diff_se <- sqrt(as.numeric(t(cvec) %*% vc %*% cvec))
  diff_stat <- diff_est / diff_se
  diff_p <- 2 * pnorm(abs(diff_stat), lower.tail = FALSE)

  tibble(
    Outcome = outcome_label,
    Contrast = contrast_label,
    `Endline FE` = paste0(fmt_num(end_row$estimate, 3), sig_stars(end_row$p.value)),
    `Follow-up FE` = paste0(fmt_num(follow_row$estimate, 3), sig_stars(follow_row$p.value)),
    `Follow-up - Endline` = paste0(fmt_num(diff_est, 3), sig_stars(diff_p)),
    `p-value (difference)` = fmt_p(diff_p),
    `Participants` = fmt_int(n_id),
    `Observations` = fmt_int(n_obs)
  )
}

results <- pmap_dfr(
  panel_specs,
  function(baseline, endline, followup, label) {
    dat <- participant |>
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
      contrast_row(mod, "wave::t1:pro_any", "wave::t2:pro_any", "Pooled Pro-China", label, n_distinct(dat$study_id), nrow(dat)),
      contrast_row(mod, "wave::t1:anti_any", "wave::t2:anti_any", "Pooled Anti-China", label, n_distinct(dat$study_id), nrow(dat)),
      contrast_row(mod, "wave::t1:apol", "wave::t2:apol", "Apolitical China", label, n_distinct(dat$study_id), nrow(dat))
    )
  }
)

write_latex_df(
  results,
  file.path(tables_dir, "tab_persistence_panel_fe.tex"),
  "Persistence Estimates from Individual Fixed-Effects Panel Models",
  "tab:persistence_panel_fe",
  align = "lllccccc",
  notes = "Entries report treatment-by-wave coefficients from individual fixed-effects panel models stacking baseline, endline, and follow-up observations. The omitted period is baseline and the omitted treatment group is the non-China control arm. Standard errors are clustered at the participant level. `Follow-up - Endline' tests whether the follow-up effect differs from the endline effect for the same contrast."
)

message("Wrote tables/tab_persistence_panel_fe.tex")
