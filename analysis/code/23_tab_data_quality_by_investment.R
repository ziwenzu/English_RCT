source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
recruited <- participant |>
  filter(recruited == 1) |>
  add_investment_index(ref_data = participant |> filter(recruited == 1))

investment_cut <- median(recruited$investment_z, na.rm = TRUE)

quality_data <- recruited |>
  mutate(
    high_invest = as.integer(investment_z >= investment_cut),
    t1_no_straight = 1 - t1_straightline_flag,
    t2_no_straight = 1 - t2_straightline_flag
  )

quality_specs <- tribble(
  ~sample_flag,          ~outcome,            ~label,
  "complete_endline",    "t1_att_pass",       "Endline attention check passed",
  "complete_endline",    "t1_no_straight",    "Endline no straightlining",
  "complete_followup",   "t2_att_pass",       "Follow-up attention check passed",
  "complete_followup",   "t2_no_straight",    "Follow-up no straightlining"
)

results <- pmap_dfr(
  quality_specs,
  function(sample_flag, outcome, label) {
    dat <- quality_data |>
      filter(.data[[sample_flag]] == 1) |>
      select(all_of(c(outcome, "high_invest")), pro_any, anti_any, apol, block_id) |>
      filter(!is.na(.data[[outcome]]), !is.na(high_invest), !is.na(block_id))

    mod <- lm(
      as.formula(paste0(outcome, " ~ high_invest + pro_any + anti_any + apol + factor(block_id)")),
      data = dat
    )

    est <- tidy_hc2(mod) |>
      filter(term == "high_invest") |>
      slice(1)

    tibble(
      Outcome = label,
      low_mean = mean(dat[[outcome]][dat$high_invest == 0], na.rm = TRUE),
      high_mean = mean(dat[[outcome]][dat$high_invest == 1], na.rm = TRUE),
      diff = est$estimate,
      p.value = est$p.value,
      n = nrow(dat)
    )
  }
) |>
  mutate(
    `Low investment` = fmt_num(low_mean, 3),
    `High investment` = fmt_num(high_mean, 3),
    `High - Low` = paste0(fmt_num(diff, 3), sig_stars(p.value)),
    `p-value` = fmt_p(p.value),
    N = fmt_int(n)
  ) |>
  select(Outcome, `Low investment`, `High investment`, `High - Low`, `p-value`, N)

write_latex_df(
  results,
  file.path(tables_dir, "tab_data_quality_by_investment.tex"),
  "Survey Data Quality by Study Investment",
  "tab:data_quality_by_investment",
  align = "lccccc",
  notes = "High-investment respondents are defined as those above the median of a pre-specified investment index combining last active week, compliance rate, reading minutes per slot, video minutes per slot, and mean quiz score. Reported differences come from regressions of each quality outcome on the high-investment indicator, treatment indicators, and randomization-block fixed effects with HC2 standard errors."
)

message("Wrote tables/tab_data_quality_by_investment.tex")
