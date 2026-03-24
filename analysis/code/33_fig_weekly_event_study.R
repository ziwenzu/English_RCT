source(file.path("code", "_figure_helpers.R"))

weekly <- read_dta(file.path(root_dir, "data", "weekly_long.dta")) |>
  mutate(
    arm = as.integer(arm),
    week = as.integer(week),
    slot_wk = as.integer(slot_wk)
  ) |>
  filter(slot_wk == 1)

outcome_map <- tribble(
  ~outcome,          ~label,
  "wk_rate_interest","Interest rating",
  "wk_rate_cred",    "Credibility rating",
  "wk_rate_similar", "Want more similar"
)

plot_data <- pmap_dfr(
  outcome_map,
  function(outcome, label) {
    weekly |>
      mutate(
        y = .data[[outcome]],
        period = ceiling(week / 2),
        dose = case_when(
          arm %in% c(1L, 3L) ~ "Low dose",
          arm %in% c(2L, 4L) ~ "High dose",
          arm == 6L ~ "Control reference",
          TRUE ~ NA_character_
        ),
        series = case_when(
          arm %in% c(1L, 2L) ~ "Pro-China",
          arm %in% c(3L, 4L) ~ "Anti-China",
          arm == 6L ~ "Control",
          TRUE ~ NA_character_
        )
      ) |>
      filter(!is.na(dose), !is.na(series), !is.na(y)) |>
      group_by(dose, series, period) |>
      summarise(
        mean = mean(y, na.rm = TRUE),
        std.error = sd(y, na.rm = TRUE) / sqrt(sum(!is.na(y))),
        conf.low = mean - 1.96 * std.error,
        conf.high = mean + 1.96 * std.error,
        .groups = "drop"
      ) |>
      mutate(week = period) |>
      mutate(outcome = label)
  }
)

control_reference <- plot_data |>
  filter(dose == "Control reference") |>
  mutate(dose = "Low dose") |>
  bind_rows(
    plot_data |>
      filter(dose == "Control reference") |>
      mutate(dose = "High dose")
  ) |>
  filter(series == "Control")

treatment_lines <- plot_data |>
  filter(dose != "Control reference")

plot <- ggplot() +
  geom_ribbon(
    data = control_reference,
    aes(x = week, ymin = conf.low, ymax = conf.high, group = dose),
    inherit.aes = FALSE,
    fill = "grey60",
    alpha = 0.12
  ) +
  geom_line(
    data = control_reference,
    aes(x = week, y = mean),
    color = "grey35",
    linetype = "dashed",
    linewidth = 0.8
  ) +
  geom_ribbon(
    data = treatment_lines,
    aes(x = week, ymin = conf.low, ymax = conf.high, fill = series),
    alpha = 0.12,
    linewidth = 0
  ) +
  geom_line(
    data = treatment_lines,
    aes(x = week, y = mean, color = series),
    linewidth = 1
  ) +
  geom_point(
    data = treatment_lines,
    aes(x = week, y = mean, color = series),
    size = 1.6
  ) +
  facet_grid(dose ~ outcome, scales = "free_y") +
  scale_x_continuous(breaks = 1:6) +
  scale_color_manual(
    values = c(
      "Pro-China" = "#00BFC4",
      "Anti-China" = "#F8766D"
    )
  ) +
  scale_fill_manual(
    values = c(
      "Pro-China" = "#00BFC4",
      "Anti-China" = "#F8766D"
    )
  ) +
  labs(
    title = "Biweekly Engagement and Acceptance Patterns in Slot 1",
    subtitle = paste(
      "Each point averages two study weeks for a treatment arm.",
      "The control group is repeated as a grey reference."
    ),
    x = "Two-week period",
    y = "Mean rating"
  ) +
  paper_theme()

save_figure(plot, "fig_weekly_event_study", width = 9, height = 5.8)

message("Wrote figures/fig_weekly_event_study.pdf")
