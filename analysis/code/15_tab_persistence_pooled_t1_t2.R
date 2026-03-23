source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
endline <- participant |> filter(recruited == 1, complete_endline == 1)
followup <- participant |> filter(recruited == 1, complete_followup == 1)

results_t1 <- pmap_dfr(
  main_outcome_map(),
  \(outcome, baseline, label) run_pooled_ancova(endline, outcome, baseline, label)
) |>
  mutate(wave = "T1")

results_t2 <- pmap_dfr(
  t2_outcome_map(),
  \(outcome, baseline, label) run_pooled_ancova(followup, outcome, baseline, label)
) |>
  mutate(wave = "T2")

all_results <- bind_rows(results_t1, results_t2) |>
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
    Wave = wave,
    Contrast = term,
    Estimate,
    `Std. Error`,
    `p-value`,
    N
  ) |>
  arrange(Outcome, Contrast, Wave)

write_latex_df(
  all_results,
  file.path(tables_dir, "tab_persistence_pooled_t1_t2.tex"),
  "Pooled Treatment Effects at Endline and Follow-up",
  "tab:persistence_pooled_t1_t2",
  align = "lllcccc",
  notes = "Entries report pooled ANCOVA estimates relative to the non-China control arm. T1 models are estimated on endline respondents; T2 models are estimated on follow-up respondents. All specifications include the baseline value of the dependent variable and randomization-block fixed effects. Heteroskedasticity-robust HC2 standard errors are reported in the table. Significance: + p $<$ 0.10, * p $<$ 0.05, ** p $<$ 0.01, *** p $<$ 0.001."
)

message("Wrote tables/tab_persistence_pooled_t1_t2.tex")
