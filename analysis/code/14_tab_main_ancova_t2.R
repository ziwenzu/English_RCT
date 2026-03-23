source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
followup <- participant |> filter(recruited == 1, complete_followup == 1)

arm_results <- pmap_dfr(
  t2_outcome_map(),
  \(outcome, baseline, label) run_arm_ancova(followup, outcome, baseline, label)
) |>
  mutate(
    term = dplyr::recode(
      term,
      "arm_labelpro_low" = "Pro-China, low dose",
      "arm_labelpro_high" = "Pro-China, high dose",
      "arm_labelanti_low" = "Anti-China, low dose",
      "arm_labelanti_high" = "Anti-China, high dose",
      "arm_labelapol_china" = "Apolitical China"
    )
  ) |>
  select(outcome_label, term, estimate, std.error, p.value, control_mean, n)

write_latex_reg_table(
  arm_results,
  file.path(tables_dir, "tab_main_ancova_t2.tex"),
  "Follow-up ANCOVA Estimates by Treatment Arm",
  "tab:main_ancova_t2",
  notes = "Each column reports a follow-up ANCOVA specification estimated on follow-up respondents. All models include the baseline value of the dependent variable and randomization-block fixed effects. Omitted category: non-China control. Heteroskedasticity-robust HC2 standard errors are in parentheses. Significance: + p $<$ 0.10, * p $<$ 0.05, ** p $<$ 0.01, *** p $<$ 0.001.",
  term_order = c(
    "Pro-China, low dose",
    "Pro-China, high dose",
    "Anti-China, low dose",
    "Anti-China, high dose",
    "Apolitical China"
  ),
  outcome_order = c(
    "Regime support",
    "Censorship support",
    "Nationalism",
    "China-West thermometer gap",
    "Trust in foreign media"
  )
)

message("Wrote tables/tab_main_ancova_t2.tex")
