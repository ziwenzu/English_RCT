source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()

selection_specs <- tribble(
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

results <- pmap_dfr(
  selection_specs,
  \(var, label) group_mean_difference(participant, var, "recruited", label)
) |>
  mutate(
    `Recruited` = fmt_num(mean_group1, 3),
    `Not recruited` = fmt_num(mean_group0, 3),
    Diff = paste0(fmt_num(diff, 3), sig_stars(p.value)),
    `p-value` = fmt_p(p.value),
    N = fmt_int(n)
  ) |>
  transmute(
    Variable = variable,
    `Recruited`,
    `Not recruited`,
    Diff,
    `p-value`,
    N
  )

write_latex_df(
  results,
  file.path(tables_dir, "tab_recruitment_selection.tex"),
  "Baseline Differences Between Recruited and Non-Recruited Baseline Respondents",
  "tab:recruitment_selection",
  align = "lccccc",
  notes = "Entries compare baseline respondents who entered the randomized study sample (`recruited = 1`) with baseline respondents who did not. Differences are estimated from bivariate OLS regressions with HC2 standard errors. Recruitment was partially based on baseline quality checks and study-abroad interest, so this table is informative about sample selection and external validity rather than experimental balance."
)

message("Wrote tables/tab_recruitment_selection.tex")
