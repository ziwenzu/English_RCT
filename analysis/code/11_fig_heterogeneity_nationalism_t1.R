source(file.path("code", "_figure_helpers.R"))

participant <- prepare_participant(include_moderators = TRUE)
endline <- participant |> filter(recruited == 1, complete_endline == 1)

grid <- seq(
  quantile(endline$nat0_z, 0.05, na.rm = TRUE),
  quantile(endline$nat0_z, 0.95, na.rm = TRUE),
  length.out = 100
)

mod_regime <- fit_het_model_for_figure(endline, "t1_rs_index", "t0_rs_index", "nat0_z")
mod_trust <- fit_het_model_for_figure(endline, "t1_trust_foreign", "t0_trust_foreign", "nat0_z")

plot_df <- bind_rows(
  marginal_effect_grid(
    mod_regime,
    "nat0_z",
    "Regime support",
    c("pro_any" = "Pro-China", "anti_any" = "Anti-China"),
    grid
  ),
  marginal_effect_grid(
    mod_trust,
    "nat0_z",
    "Trust in foreign media",
    c("pro_any" = "Pro-China", "anti_any" = "Anti-China"),
    grid
  )
)

p <- ggplot(plot_df, aes(x = z, y = estimate, color = treatment, fill = treatment)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.9) +
  facet_wrap(~ outcome, scales = "free_y", ncol = 2) +
  scale_color_manual(values = c("Pro-China" = "#2166ac", "Anti-China" = "#b2182b")) +
  scale_fill_manual(values = c("Pro-China" = "#2166ac", "Anti-China" = "#b2182b")) +
  labs(
    x = "Baseline nationalism (z)",
    y = "Marginal treatment effect",
    title = "Heterogeneous Effects by Baseline Nationalism"
  ) +
  paper_theme()

save_figure(p, "fig_heterogeneity_nationalism_t1", width = 9, height = 4.8)
message("Wrote figures/fig_heterogeneity_nationalism_t1.pdf")
