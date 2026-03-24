source(file.path("code", "_figure_helpers.R"))

endline <- prepare_participant() |>
  filter(recruited == 1, complete_endline == 1, !is.na(t1_wtp_bid)) |>
  mutate(
    group = case_when(
      arm == 6 ~ "Control",
      arm == 5 ~ "Apolitical China",
      arm %in% c(1, 2) ~ "Pooled Pro-China",
      arm %in% c(3, 4) ~ "Pooled Anti-China"
    )
  )

group_stats <- endline |>
  group_by(group) |>
  summarise(cs = mean(t1_wtp_bid, na.rm = TRUE), .groups = "drop")

label_map <- setNames(
  paste0(group_stats$group, " (CS=", sprintf("%.1f", group_stats$cs), " RMB)"),
  group_stats$group
)

price_grid <- tibble(price = seq(0, 50, by = 1))

demand_df <- crossing(
  group = unique(endline$group),
  price_grid
) |>
  left_join(group_stats, by = "group") |>
  rowwise() |>
  mutate(
    n = sum(endline$group == group),
    demand = mean(endline$t1_wtp_bid[endline$group == group] >= price, na.rm = TRUE),
    std.error = sqrt(demand * (1 - demand) / n),
    conf.low = pmax(0, demand - 1.96 * std.error),
    conf.high = pmin(1, demand + 1.96 * std.error),
    group_label = label_map[[group]]
  ) |>
  ungroup()

plot <- ggplot(
  demand_df,
  aes(x = price, y = demand, color = group_label, fill = group_label)
) +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.12, linewidth = 0) +
  geom_line(linewidth = 0.9) +
  scale_x_continuous(breaks = seq(0, 50, by = 10)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Demand Curves for Continued Access to Foreign News",
    subtitle = "Area under each curve equals mean willingness to pay / consumer surplus",
    x = "Price (RMB)",
    y = "Predicted purchase probability"
  ) +
  paper_theme()

save_figure(plot, "fig_wtp_demand_curve", width = 8.5, height = 5.5)

message("Wrote figures/fig_wtp_demand_curve.pdf")
