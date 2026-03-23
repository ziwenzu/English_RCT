source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant(include_moderators = TRUE)
endline <- participant |> filter(recruited == 1, complete_endline == 1)

results <- pmap_dfr(
  het_outcome_map(),
  \(outcome, baseline, label) run_het_model(endline, outcome, baseline, label, "rs0_z", "Baseline regime support (z)")
) |>
  mutate(
    term = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China",
      "rs0_z" = "Baseline regime support (z)",
      "pro_any:rs0_z" = "Pro-China x regime support",
      "anti_any:rs0_z" = "Anti-China x regime support",
      "apol:rs0_z" = "Apolitical x regime support"
    )
  ) |>
  select(outcome_label, term, estimate, std.error, p.value, control_mean, n)

write_latex_reg_table(
  results,
  file.path(tables_dir, "tab_heterogeneity_rs_t1.tex"),
  "Heterogeneous Treatment Effects by Baseline Regime Support",
  "tab:het_rs_t1",
  notes = "Each column reports an endline ANCOVA specification with interactions between pooled treatment indicators and standardized baseline regime support. The omitted group is the non-China control arm. All models include the lagged dependent variable and randomization-block fixed effects. HC2 standard errors are in parentheses. Significance: + p $<$ 0.10, * p $<$ 0.05, ** p $<$ 0.01, *** p $<$ 0.001.",
  term_order = c(
    "Pooled Pro-China",
    "Pooled Anti-China",
    "Apolitical China",
    "Baseline regime support (z)",
    "Pro-China x regime support",
    "Anti-China x regime support",
    "Apolitical x regime support"
  ),
  outcome_order = c("Regime support", "Censorship support", "Nationalism", "Trust in foreign media")
)

message("Wrote tables/tab_heterogeneity_rs_t1.tex")
