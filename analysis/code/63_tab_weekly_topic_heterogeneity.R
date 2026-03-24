source(file.path("code", "_table_helpers.R"))

weekly <- prepare_weekly_panel(slot = 1)
weekly_output_dir <- file.path(dirname(root_dir), "archive", "analysis_support", "weekly")
dir.create(weekly_output_dir, recursive = TRUE, showWarnings = FALSE)

outcome_map <- tribble(
  ~outcome,            ~label,
  "wk_quiz_score",     "Quiz score",
  "wk_rate_interest",  "Interest rating",
  "wk_read_min",       "Reading minutes",
  "wk_rate_cred",      "Credibility rating",
  "wk_rate_similar",   "Want more similar"
)

topic_order <- c(
  "Pro: Macro growth support",
  "Pro: Green / technology",
  "Pro: Housing / property",
  "Pro: Family / demographics",
  "Anti: Censorship / repression",
  "Anti: Economy / property",
  "Anti: Labor / social stress",
  "Apolitical: Food / cuisine",
  "Apolitical: Travel / culture"
)

results <- pmap_dfr(
  outcome_map,
  function(outcome, label) {
    dat <- weekly |>
      filter(!is.na(.data[[outcome]]), !is.na(topic_family_weekly), !is.na(block_id))

    mod <- lm(
      as.formula(paste0(outcome, " ~ topic_family_weekly + factor(week) + factor(block_id)")),
      data = dat
    )

    vc <- cluster_vcov(mod, dat$study_id)
    ctrl_mean <- dat |>
      filter(topic_family_weekly == "Control benchmark") |>
      summarise(m = mean(.data[[outcome]], na.rm = TRUE)) |>
      pull(m)

    tidy_with_vcov(mod, vc) |>
      filter(grepl("^topic_family_weekly", term)) |>
      mutate(
        outcome_label = label,
        topic_family = sub("^topic_family_weekly", "", term),
        control_mean = ctrl_mean,
        n = nrow(dat)
      )
  }
) |>
  mutate(
    topic_family = factor(topic_family, levels = topic_order)
  ) |>
  arrange(outcome_label, topic_family)

write_csv(
  results |>
    mutate(topic_family = as.character(topic_family)),
  file.path(weekly_output_dir, "weekly_topic_heterogeneity.csv")
)

table_df <- results |>
  mutate(
    topic_family = as.character(topic_family),
    Estimate = paste0(fmt_num(estimate, 3), sig_stars(p.value)),
    `Std. Error` = fmt_num(std.error, 3),
    `p-value` = fmt_p(p.value),
    `Control mean` = fmt_num(control_mean, 3),
    N = fmt_int(n)
  ) |>
  transmute(
    Outcome = outcome_label,
    `Topic family` = topic_family,
    Estimate,
    `Std. Error`,
    `p-value`,
    `Control mean`,
    N
  )

write_latex_df(
  table_df,
  file.path(tables_dir, "tab_weekly_topic_heterogeneity.tex"),
  "Weekly Slot-1 Topic Heterogeneity",
  "tab:weekly_topic_heterogeneity",
  align = "llccccc",
  notes = paste(
    "Entries report week-level contrasts relative to the non-China control benchmark for broad slot-1 topic families.",
    "Each specification includes week fixed effects and randomization-block fixed effects.",
    "Standard errors are clustered at the participant level.",
    "Topic families pool substantively similar article themes within the Pro-China, Anti-China, and Apolitical-China banks."
  )
)

message("Wrote tables/tab_weekly_topic_heterogeneity.tex")
