source(file.path("code", "_figure_helpers.R"))

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
  filter(slot_wk == 1)

outcome_map <- tribble(
  ~outcome,          ~label,
  "wk_comply",       "Compliance",
  "wk_read_min",     "Reading minutes",
  "wk_rate_cred",    "Credibility rating",
  "wk_rate_similar", "Want more similar"
)

event_results <- pmap_dfr(
  outcome_map,
  function(outcome, label) {
    weekly_zero <- weekly |>
      mutate(y = if_else(is.na(.data[[outcome]]), 0, .data[[outcome]]))

    map_dfr(
      sort(unique(weekly_zero$week)),
      function(week_value) {
        dat <- weekly_zero |>
          filter(week == week_value, !is.na(block_id))

        mod <- lm(y ~ pro_any + anti_any + apol + factor(block_id), data = dat)

        tidy_hc2(mod) |>
          filter(term %in% c("pro_any", "anti_any")) |>
          mutate(
            week = week_value,
            outcome = label
          )
      }
    )
  }
) |>
  mutate(
    treatment = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China"
    )
  )

plot <- ggplot(
  event_results,
  aes(x = week, y = estimate, color = treatment, fill = treatment)
) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.12, linewidth = 0) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.4) +
  facet_wrap(~ outcome, scales = "free_y", ncol = 2) +
  scale_x_continuous(breaks = 1:12) +
  labs(
    title = "Weekly Dynamics of Engagement and Acceptance",
    subtitle = "Slot-1 outcomes by week; missing post-dropout outcomes are set to zero",
    x = "Study week",
    y = "Treatment effect relative to control"
  ) +
  paper_theme()

save_figure(plot, "fig_weekly_event_study", width = 9, height = 6)

message("Wrote figures/fig_weekly_event_study.pdf")
