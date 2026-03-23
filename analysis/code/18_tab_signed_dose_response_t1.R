source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
endline <- participant |>
  filter(recruited == 1, complete_endline == 1) |>
  mutate(
    signed_sched = n_pol_slots * treat_valence,
    apol = as.integer(arm == 5L)
  )

dose_specs <- main_outcome_map() |>
  transmute(
    outcome,
    baseline,
    outcome_label = label
  )

results <- pmap_dfr(
  dose_specs,
  function(outcome, baseline, outcome_label) {
    dat <- endline |>
      select(all_of(c(outcome, baseline)), signed_sched, apol, block_id) |>
      filter(
        !is.na(.data[[outcome]]),
        !is.na(.data[[baseline]]),
        !is.na(signed_sched),
        !is.na(apol),
        !is.na(block_id)
      )

    mod <- lm(
      as.formula(
        paste0(
          outcome,
          " ~ signed_sched + apol + ",
          baseline,
          " + factor(block_id)"
        )
      ),
      data = dat
    )

    tidy_hc2(mod) |>
      filter(term == "signed_sched") |>
      mutate(
        Outcome = outcome_label,
        Parameter = "Signed political dose",
        Estimate = paste0(fmt_num(estimate, 3), sig_stars(p.value)),
        `Std. Error` = fmt_num(std.error, 3),
        `p-value` = fmt_p(p.value),
        N = fmt_int(nrow(dat))
      ) |>
      select(Outcome, Parameter, Estimate, `Std. Error`, `p-value`, N)
  }
)

write_latex_df(
  results,
  file.path(tables_dir, "tab_signed_dose_response_t1.tex"),
  "Signed Dose-Response Estimates at Endline",
  "tab:signed_dose_response_t1",
  align = "llcccc",
  notes = "Entries report OLS dose-response estimates on endline respondents. `Signed political dose' equals the number of scheduled political China stories, coded positively for pro-China treatments and negatively for anti-China treatments. All specifications include an apolitical-China indicator, the baseline value of the dependent variable, and randomization-block fixed effects. In the endline sample, realized political openings equal scheduled political dose exactly, so an IV specification adds no identifying variation beyond this design-based dose regression. Heteroskedasticity-robust HC2 standard errors are reported in the table."
)

message("Wrote tables/tab_signed_dose_response_t1.tex")
