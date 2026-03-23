source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant(include_moderators = TRUE)
endline <- participant |> filter(recruited == 1, complete_endline == 1)

results <- pmap_dfr(
  het_outcome_map(),
  \(outcome, baseline, label) run_het_model(endline, outcome, baseline, label, "foreign_exp_z", "Foreign media exposure (z)")
) |>
  mutate(
    term = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China",
      "foreign_exp_z" = "Foreign media exposure (z)",
      "pro_any:foreign_exp_z" = "Pro-China x foreign exposure",
      "anti_any:foreign_exp_z" = "Anti-China x foreign exposure",
      "apol:foreign_exp_z" = "Apolitical x foreign exposure"
    )
  ) |>
  select(outcome_label, term, estimate, std.error, p.value, control_mean, n)

write_latex_reg_table(
  results,
  file.path(tables_dir, "tab_heterogeneity_foreign_t1.tex"),
  "Heterogeneous Treatment Effects by Prior Foreign-Media Exposure",
  "tab:het_foreign_t1",
  notes = "Each column reports an endline ANCOVA specification with interactions between pooled treatment indicators and a standardized pre-treatment foreign-media exposure index. The index averages standardized measures of foreign-news exposure in the past 30 days, foreign-news frequency, and use of foreign platforms (Facebook, Twitter, YouTube, Instagram). The omitted group is the non-China control arm. All models include the lagged dependent variable and randomization-block fixed effects. HC2 standard errors are in parentheses. Significance: + p $<$ 0.10, * p $<$ 0.05, ** p $<$ 0.01, *** p $<$ 0.001.",
  term_order = c(
    "Pooled Pro-China",
    "Pooled Anti-China",
    "Apolitical China",
    "Foreign media exposure (z)",
    "Pro-China x foreign exposure",
    "Anti-China x foreign exposure",
    "Apolitical x foreign exposure"
  ),
  outcome_order = c("Regime support", "Censorship support", "Nationalism", "Trust in foreign media")
)

message("Wrote tables/tab_heterogeneity_foreign_t1.tex")
