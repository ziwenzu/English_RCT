source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
endline <- participant |> filter(recruited == 1, complete_endline == 1)

planned_contrasts <- pmap_dfr(
  main_outcome_map(),
  \(outcome, baseline, label) run_planned_contrasts(endline, outcome, baseline, label)
)

planned_latex <- planned_contrasts |>
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
  )

write_latex_df(
  planned_latex,
  file.path(tables_dir, "tab_planned_contrasts_t1.tex"),
  "Planned Dose Contrasts at Endline",
  "tab:planned_contrasts_t1",
  align = "llcccc",
  notes = "Entries report linear contrasts from the arm-level ANCOVA models. All specifications include the lagged dependent variable and block fixed effects. Heteroskedasticity-robust HC2 standard errors are reported in the table. Significance: + p $<$ 0.10, * p $<$ 0.05, ** p $<$ 0.01, *** p $<$ 0.001."
)

message("Wrote tables/tab_planned_contrasts_t1.tex")
