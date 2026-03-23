source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant(include_moderators = TRUE)
endline <- participant |> filter(recruited == 1, complete_endline == 1)

results <- pmap_dfr(
  het_outcome_map(),
  \(outcome, baseline, label) run_het_model(endline, outcome, baseline, label, "nat0_z", "Baseline nationalism (z)")
) |>
  mutate(
    term = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China",
      "nat0_z" = "Baseline nationalism (z)",
      "pro_any:nat0_z" = "Pro-China x nationalism",
      "anti_any:nat0_z" = "Anti-China x nationalism",
      "apol:nat0_z" = "Apolitical x nationalism"
    )
  ) |>
  select(outcome_label, term, estimate, std.error, p.value, control_mean, n)

write_latex_reg_table(
  results,
  file.path(tables_dir, "tab_heterogeneity_nat_t1.tex"),
  "Heterogeneous Treatment Effects by Baseline Nationalism",
  "tab:het_nat_t1",
  notes = "Each column reports an endline ANCOVA specification with interactions between pooled treatment indicators and standardized baseline nationalism. The omitted group is the non-China control arm. All models include the lagged dependent variable and randomization-block fixed effects. HC2 standard errors are in parentheses. Significance: + p $<$ 0.10, * p $<$ 0.05, ** p $<$ 0.01, *** p $<$ 0.001.",
  term_order = c(
    "Pooled Pro-China",
    "Pooled Anti-China",
    "Apolitical China",
    "Baseline nationalism (z)",
    "Pro-China x nationalism",
    "Anti-China x nationalism",
    "Apolitical x nationalism"
  ),
  outcome_order = c("Regime support", "Censorship support", "Nationalism", "Trust in foreign media")
)

message("Wrote tables/tab_heterogeneity_nat_t1.tex")
