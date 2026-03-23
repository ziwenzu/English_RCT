source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
recruited <- participant |> filter(recruited == 1)
followup_base <- recruited |> filter(complete_endline == 1)

attrition_specs <- tribble(
  ~var,                    ~label,
  "t0_att_pass",           "Baseline attention check passed",
  "t0_straightline_flag",  "Baseline straightlining flag",
  "t0_abroad_plan",        "Study-abroad plan (1=yes, 4=no)",
  "t0_news_foreign_30d",   "Foreign-news exposure (30 days)",
  "t0_trust_foreign",      "Trust in foreign media",
  "t0_rs_index",           "Regime support",
  "t0_nat_index",          "Nationalism",
  "t0_cen_index",          "Censorship support",
  "t0_therm_gap",          "China-West thermometer gap",
  "t0_exam_score",         "Exam score",
  "t0_female",             "Female"
)

endline_results <- pmap_dfr(
  attrition_specs,
  \(var, label) group_mean_difference(recruited, var, "complete_endline", label)
) |>
  transmute(
    variable,
    end_comp = mean_group1,
    end_attr = mean_group0,
    end_diff = diff,
    end_p = p.value
  )

followup_results <- pmap_dfr(
  attrition_specs,
  \(var, label) group_mean_difference(followup_base, var, "complete_followup", label)
) |>
  transmute(
    variable,
    fu_comp = mean_group1,
    fu_attr = mean_group0,
    fu_diff = diff,
    fu_p = p.value,
    fu_n = n
  )

results <- endline_results |>
  left_join(followup_results, by = "variable") |>
  mutate(
    `Endline completers` = fmt_num(end_comp, 3),
    `Endline attriters` = fmt_num(end_attr, 3),
    `Diff (E)` = paste0(fmt_num(end_diff, 3), sig_stars(end_p)),
    `p (E)` = fmt_p(end_p),
    `Follow-up completers` = fmt_num(fu_comp, 3),
    `Follow-up attriters` = fmt_num(fu_attr, 3),
    `Diff (F)` = paste0(fmt_num(fu_diff, 3), sig_stars(fu_p)),
    `p (F)` = fmt_p(fu_p)
  ) |>
  transmute(
    Variable = variable,
    `Endline completers`,
    `Endline attriters`,
    `Diff (E)`,
    `p (E)`,
    `Follow-up completers`,
    `Follow-up attriters`,
    `Diff (F)`,
    `p (F)`
  )

write_latex_df(
  results,
  file.path(tables_dir, "tab_attrition_composition.tex"),
  "Observable Differences Between Completers and Attriters",
  "tab:attrition_composition",
  align = "lcccccccc",
  notes = "Endline comparisons use the full recruited sample and compare endline completers with endline attriters. Follow-up comparisons are estimated among endline respondents and compare follow-up completers with follow-up non-completers. Differences are estimated from bivariate OLS regressions with HC2 standard errors. Differential attrition by treatment arm is reported separately in the main attrition table."
)

message("Wrote tables/tab_attrition_composition.tex")
