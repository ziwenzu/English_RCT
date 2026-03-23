source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
endline <- participant |> filter(recruited == 1, complete_endline == 1)

pooled_results <- pmap_dfr(
  main_outcome_map(),
  \(outcome, baseline, label) run_pooled_ancova(endline, outcome, baseline, label)
) |>
  mutate(
    term = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China"
    )
  ) |>
  select(outcome_label, term, estimate, std.error, p.value, control_mean, n)

pooled_latex <- pooled_results |>
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
  pooled_latex,
  file.path(tables_dir, "tab_pooled_effects_t1.tex"),
  "Pooled Endline ANCOVA Estimates",
  "tab:pooled_effects_t1",
  align = "llcccc",
  notes = "Entries report pooled treatment contrasts relative to the non-China control arm. All specifications include the lagged dependent variable and block fixed effects. Heteroskedasticity-robust HC2 standard errors are reported in the table. Significance: + p $<$ 0.10, * p $<$ 0.05, ** p $<$ 0.01, *** p $<$ 0.001."
)

message("Wrote tables/tab_pooled_effects_t1.tex")
