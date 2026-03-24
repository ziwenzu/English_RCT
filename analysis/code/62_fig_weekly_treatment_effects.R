source(file.path("code", "_figure_helpers.R"))

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

treatment_labels <- c(
  pro_any = "Pooled Pro-China",
  anti_any = "Pooled Anti-China",
  apol = "Apolitical China"
)

plot_data <- pmap_dfr(
  outcome_map,
  function(outcome, label) {
    map_dfr(
      sort(unique(weekly$week)),
      function(week_num) {
        dat <- weekly |>
          filter(week == week_num, !is.na(.data[[outcome]]), !is.na(block_id))

        mod <- lm(
          as.formula(paste0(outcome, " ~ pro_any + anti_any + apol + factor(block_id)")),
          data = dat
        )

        vc <- cluster_vcov(mod, dat$study_id)

        tidy_with_vcov(mod, vc) |>
          filter(term %in% names(treatment_labels)) |>
          mutate(
            week = week_num,
            outcome_label = label,
            treatment = unname(treatment_labels[term]),
            n = nrow(dat)
          )
      }
    )
  }
)

write_csv(
  plot_data,
  file.path(weekly_output_dir, "weekly_treatment_effects_by_week.csv")
)

plot_out <- ggplot(
  plot_data,
  aes(x = week, y = estimate, color = treatment, fill = treatment)
) +
  geom_hline(yintercept = 0, color = "grey70", linetype = "dashed") +
  geom_ribbon(
    aes(ymin = conf.low, ymax = conf.high),
    alpha = 0.12,
    linewidth = 0
  ) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.6) +
  facet_wrap(~ outcome_label, scales = "free_y", ncol = 2) +
  scale_x_continuous(breaks = 1:12) +
  scale_color_manual(
    values = c(
      "Pooled Pro-China" = "#00BFC4",
      "Pooled Anti-China" = "#F8766D",
      "Apolitical China" = "#c99a2e"
    )
  ) +
  scale_fill_manual(
    values = c(
      "Pooled Pro-China" = "#00BFC4",
      "Pooled Anti-China" = "#F8766D",
      "Apolitical China" = "#c99a2e"
    )
  ) +
  labs(
    title = "Weekly Treatment Effects on Slot-1 Engagement and Acceptance",
    subtitle = paste(
      "Points show week-specific contrasts relative to the non-China control arm.",
      "Each panel reports separate regressions with block fixed effects and participant-clustered standard errors."
    ),
    x = "Study week",
    y = "Estimated effect relative to control"
  ) +
  paper_theme()

save_figure(plot_out, "fig_weekly_treatment_effects", width = 10.5, height = 8.2)

message("Wrote figures/fig_weekly_treatment_effects.pdf")
