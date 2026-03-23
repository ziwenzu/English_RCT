source(file.path("code", "_table_helpers.R"))

weekly <- read_dta(file.path(root_dir, "data", "weekly_long.dta")) |>
  left_join(
    prepare_participant() |> select(study_id, block_id),
    by = "study_id"
  ) |>
  mutate(
    arm = as.integer(arm),
    study_id = as.integer(study_id),
    week = as.integer(week),
    slot_wk = as.integer(slot_wk),
    pro_any = as.integer(arm %in% c(1L, 2L)),
    anti_any = as.integer(arm %in% c(3L, 4L)),
    apol = as.integer(arm == 5L)
  ) |>
  filter(slot_wk == 1, !is.na(wk_open))

weekly_specs <- tribble(
  ~outcome,          ~label,
  "wk_comply",       "Compliance",
  "wk_read_min",     "Reading minutes",
  "wk_quiz_score",   "Quiz score",
  "wk_rate_cred",    "Credibility rating",
  "wk_rate_similar", "Want more similar"
)

results <- pmap_dfr(
  weekly_specs,
  function(outcome, label) {
    dat <- weekly |> filter(!is.na(.data[[outcome]]))
    mod <- lm(
      as.formula(paste0(outcome, " ~ pro_any + anti_any + apol + factor(week) + factor(block_id)")),
      data = dat
    )
    vc <- cluster_vcov(mod, dat$study_id)
    ctrl_mean <- dat |> filter(arm == 6) |> summarise(m = mean(.data[[outcome]], na.rm = TRUE)) |> pull(m)
    tidy_with_vcov(mod, vc) |>
      filter(term %in% c("pro_any", "anti_any", "apol")) |>
      mutate(outcome_label = label, control_mean = ctrl_mean, n = nrow(dat))
  }
) |>
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
    `Control mean` = fmt_num(control_mean, 3),
    N = fmt_int(n)
  ) |>
  transmute(
    Outcome = outcome_label,
    Contrast = term,
    Estimate,
    `Std. Error`,
    `p-value`,
    `Control mean`,
    N
  ) |>
  arrange(Outcome, Contrast)

write_latex_df(
  results,
  file.path(tables_dir, "tab_weekly_panel_slot1.tex"),
  "Weekly Slot-1 Engagement Outcomes",
  "tab:weekly_panel_slot1",
  align = "llccccc",
  notes = "Entries report pooled treatment contrasts relative to the non-China control arm using slot-1 observations from the weekly panel. All specifications include week fixed effects and randomization-block fixed effects. Standard errors are clustered at the participant level. The sample includes active slot-1 observations with non-missing engagement data."
)

message("Wrote tables/tab_weekly_panel_slot1.tex")
