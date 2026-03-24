source(file.path("code", "_figure_helpers.R"))

weekly <- prepare_weekly_panel(slot = 1)
weekly_output_dir <- file.path(dirname(root_dir), "archive", "analysis_support", "weekly")
dir.create(weekly_output_dir, recursive = TRUE, showWarnings = FALSE)

outcome_map <- tribble(
  ~outcome,            ~label,
  "wk_rate_interest",  "Interest rating",
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

plot_data <- pmap_dfr(
  outcome_map,
  function(outcome, label) {
    dat <- weekly |>
      filter(!is.na(.data[[outcome]]), !is.na(topic_family_weekly), !is.na(block_id))

    mod <- lm(
      as.formula(paste0(outcome, " ~ topic_family_weekly + factor(week) + factor(block_id)")),
      data = dat
    )

    vc <- cluster_vcov(mod, dat$study_id)

    tidy_with_vcov(mod, vc) |>
      filter(grepl("^topic_family_weekly", term)) |>
      mutate(
        outcome_label = label,
        topic_family = sub("^topic_family_weekly", "", term)
      )
  }
) |>
  mutate(
    topic_family = factor(topic_family, levels = rev(topic_order)),
    bank_group = case_when(
      grepl("^Pro:", topic_family) ~ "Pro-China topics",
      grepl("^Anti:", topic_family) ~ "Anti-China topics",
      TRUE ~ "Apolitical China topics"
    )
  )

write_csv(
  plot_data |>
    mutate(topic_family = as.character(topic_family)),
  file.path(weekly_output_dir, "weekly_topic_heterogeneity_focus.csv")
)

plot_out <- ggplot(
  plot_data,
  aes(x = estimate, y = topic_family, color = bank_group)
) +
  geom_vline(xintercept = 0, color = "grey75", linetype = "dashed") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0, linewidth = 0.55) +
  geom_point(size = 2) +
  facet_wrap(~ outcome_label, scales = "free_x", ncol = 1) +
  scale_color_manual(
    values = c(
      "Pro-China topics" = "#00BFC4",
      "Anti-China topics" = "#F8766D",
      "Apolitical China topics" = "#c99a2e"
    )
  ) +
  labs(
    title = "Topic-Level Weekly Heterogeneity in Acceptance Outcomes",
    subtitle = paste(
      "Effects are estimated relative to the non-China control benchmark.",
      "Topic families pool substantively similar slot-1 articles across weeks."
    ),
    x = "Estimated effect relative to control",
    y = NULL
  ) +
  paper_theme() +
  theme(
    panel.grid.major.y = element_blank(),
    legend.position = "top"
  )

save_figure(plot_out, "fig_weekly_topic_heterogeneity", width = 10.5, height = 8.5)

message("Wrote figures/fig_weekly_topic_heterogeneity.pdf")
