source(file.path("code", "_figure_helpers.R"))

participant <- prepare_participant()
endline <- participant |> filter(recruited == 1, complete_endline == 1)

plot_results <- pmap_dfr(
  tibble(
    outcome = c("t1_rs_index", "t1_cen_index", "t1_nat_index", "t1_trust_foreign"),
    baseline = c("t0_rs_index", "t0_cen_index", "t0_nat_index", "t0_trust_foreign"),
    label = c("Regime support", "Censorship support", "Nationalism", "Trust in foreign media")
  ),
  \(outcome, baseline, label) run_arm_ancova(endline, outcome, baseline, label)
) |>
  mutate(
    term = dplyr::recode(
      term,
      "arm_labelpro_low" = "Pro-China, low dose",
      "arm_labelpro_high" = "Pro-China, high dose",
      "arm_labelanti_low" = "Anti-China, low dose",
      "arm_labelanti_high" = "Anti-China, high dose",
      "arm_labelapol_china" = "Apolitical China"
    ),
    group = case_when(
      grepl("^Pro-China", term) ~ "Pro-China",
      grepl("^Anti-China", term) ~ "Anti-China",
      TRUE ~ "Apolitical"
    ),
    term = factor(
      term,
      levels = c(
        "Pro-China, high dose",
        "Pro-China, low dose",
        "Apolitical China",
        "Anti-China, low dose",
        "Anti-China, high dose"
      )
    )
  )

p <- ggplot(plot_results, aes(x = estimate, y = term, color = group)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.15, linewidth = 0.45) +
  geom_point(size = 2.2) +
  facet_wrap(~ outcome_label, scales = "free_x", ncol = 2) +
  scale_color_manual(values = c("Pro-China" = "#2166ac", "Anti-China" = "#b2182b", "Apolitical" = "#4d4d4d")) +
  labs(
    x = "Estimated effect relative to control",
    y = NULL,
    title = "Endline Treatment Effects by Arm"
  ) +
  paper_theme()

save_figure(p, "fig_main_effects_t1", width = 9, height = 6.5)
message("Wrote figures/fig_main_effects_t1.pdf")
