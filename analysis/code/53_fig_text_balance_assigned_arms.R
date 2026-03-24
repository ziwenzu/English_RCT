#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(patchwork)
  library(readr)
  library(tidyr)
})

source("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/analysis/code/_text_analysis_helpers.R")

dir.create(text_balance_dir_text, showWarnings = FALSE, recursive = TRUE)

figure_path <- file.path(figures_dir_text, "fig_text_balance_assigned_arms.pdf")
assignment_path <- file.path(text_balance_dir_text, "simulated_content_assignment_text_balance.csv")
full_summary_path <- file.path(text_balance_dir_text, "assigned_arm_text_balance_all.csv")
slot1_summary_path <- file.path(text_balance_dir_text, "assigned_arm_text_balance_slot1.csv")
participant_full_path <- file.path(text_balance_dir_text, "participant_text_balance_all.csv")
participant_slot1_path <- file.path(text_balance_dir_text, "participant_text_balance_slot1.csv")

selected_metrics <- c("word_count", "avg_sentence_length", "avg_word_length", "flesch_kincaid")
arm_colors <- c(
  "Pro low" = "#5ab4ac",
  "Pro high" = "#01665e",
  "Anti low" = "#f4a582",
  "Anti high" = "#ca0020",
  "Apolitical China" = "#c99a2e",
  "Control" = "#6b7280"
)

article_features <- compute_article_text_features()
assignment_df <- simulate_content_assignment_text(article_features)
full_exposure <- summarise_assigned_text_exposure(assignment_df, slot_filter = "all")
slot1_exposure <- summarise_assigned_text_exposure(assignment_df, slot_filter = "slot1")

make_plot_long <- function(summary_df, panel_label) {
  summary_df |>
    transmute(
      arm_label,
      n_participants,
      word_count_mean,
      word_count_ci_low,
      word_count_ci_high,
      avg_sentence_length_mean,
      avg_sentence_length_ci_low,
      avg_sentence_length_ci_high,
      avg_word_length_mean,
      avg_word_length_ci_low,
      avg_word_length_ci_high,
      flesch_kincaid_mean,
      flesch_kincaid_ci_low,
      flesch_kincaid_ci_high
    ) |>
    pivot_longer(
      cols = -c(arm_label, n_participants),
      names_to = c("metric", ".value"),
      names_pattern = "(.+)_(mean|ci_low|ci_high)"
    ) |>
    mutate(
      panel = panel_label,
      metric_label = factor(unname(text_metric_labels_text[metric]), levels = unname(text_metric_labels_text[selected_metrics]))
    )
}

plot_long <- bind_rows(
  make_plot_long(full_exposure$arm_summary, "Average across all 24 assigned readings"),
  make_plot_long(slot1_exposure$arm_summary, "Average across treated-slot readings only")
) |>
  mutate(arm_label = factor(arm_label, levels = unname(arm_labels_text)))

plot_out <- ggplot(plot_long, aes(x = mean, y = arm_label, color = arm_label, xmin = ci_low, xmax = ci_high)) +
  geom_errorbarh(height = 0, linewidth = 0.5) +
  geom_point(size = 2.2) +
  facet_grid(panel ~ metric_label, scales = "free_x") +
  scale_color_manual(values = arm_colors, guide = "none") +
  labs(
    x = NULL,
    y = NULL,
    title = "Textual Balance of Assigned Readings by Experimental Arm",
    subtitle = paste0(
      "Assignment is simulated from the realized randomized sample (N=",
      scales::comma(nrow(full_exposure$participant_means)),
      ") using the implemented schedule design and the finalized article bank."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(size = 17, face = "bold"),
    plot.subtitle = element_text(size = 10.5)
  )

write_csv(assignment_df, assignment_path)
write_csv(full_exposure$arm_summary, full_summary_path)
write_csv(slot1_exposure$arm_summary, slot1_summary_path)
write_csv(full_exposure$participant_means, participant_full_path)
write_csv(slot1_exposure$participant_means, participant_slot1_path)

ggsave(
  filename = figure_path,
  plot = plot_out,
  width = 13.5,
  height = 7.8,
  units = "in"
)

cat("Saved figure to:", figure_path, "\n")
cat("Saved simulated assignment to:", assignment_path, "\n")
cat("Saved full-exposure summary to:", full_summary_path, "\n")
cat("Saved slot1-exposure summary to:", slot1_summary_path, "\n")
