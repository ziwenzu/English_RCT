source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
recruited <- participant |>
  filter(recruited == 1) |>
  add_investment_index(ref_data = participant |> filter(recruited == 1))

investment_cut <- median(recruited$investment_z, na.rm = TRUE)

endline <- recruited |>
  filter(complete_endline == 1) |>
  mutate(high_invest = as.integer(investment_z >= investment_cut))

results_full <- pmap_dfr(
  main_outcome_map(),
  \(outcome, baseline, label) run_pooled_ancova(endline, outcome, baseline, label)
) |>
  mutate(sample = "Full endline sample")

results_high <- pmap_dfr(
  main_outcome_map(),
  \(outcome, baseline, label) run_pooled_ancova(endline |> filter(high_invest == 1), outcome, baseline, label)
) |>
  mutate(sample = "High-investment sample")

results <- bind_rows(results_full, results_high) |>
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
    Sample = sample,
    Contrast,
    Estimate,
    `Std. Error`,
    `p-value`,
    N
  ) |>
  arrange(Outcome, Contrast, Sample)

write_latex_df(
  results,
  file.path(tables_dir, "tab_high_investment_robustness_t1.tex"),
  "Main Endline Effects in the High-Investment Subsample",
  "tab:high_investment_robustness_t1",
  align = "lllcccc",
  notes = "Entries report pooled ANCOVA estimates relative to the non-China control arm for the full endline sample and for respondents above the median of the pre-specified study-investment index. All specifications include the baseline value of the dependent variable and randomization-block fixed effects. Heteroskedasticity-robust HC2 standard errors are reported in the table."
)

message("Wrote tables/tab_high_investment_robustness_t1.tex")
