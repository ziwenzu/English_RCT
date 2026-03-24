#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(haven)
  library(patchwork)
  library(readr)
  library(stringr)
})

source("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/analysis/code/_text_analysis_helpers.R")

chenhan_path <- file.path(project_dir_text, "3-replication-package", "data", "analysis data", "work_data.dta")
figure_path <- file.path(analysis_dir_text, "figures", "fig_content_validity_tone.pdf")
scores_path <- file.path(output_dir_text, "article_tone_scores.csv")
summary_path <- file.path(output_dir_text, "article_tone_summary.csv")
benchmark_path <- file.path(output_dir_text, "chen_han_benchmarks.csv")

texts <- load_article_bank_texts()
article_scores <- compute_article_tone_scores(texts)

bank_summary <- article_scores |>
  group_by(bank) |>
  summarise(
    n_articles = n(),
    mean_tone = mean(tone_score, na.rm = TRUE),
    sd_tone = sd(tone_score, na.rm = TRUE),
    se_tone = sd_tone / sqrt(n_articles),
    ci_low = mean_tone - 1.96 * se_tone,
    ci_high = mean_tone + 1.96 * se_tone,
    .groups = "drop"
  ) |>
  mutate(
    bank_label = paste0(unname(bank_labels_text[as.character(bank)]), " (n=", n_articles, ")")
  )

chenhan <- read_dta(chenhan_path) |>
  as_tibble() |>
  filter(news_general == 1, keywordfreqchina >= 3) |>
  mutate(group = if_else(press == "chinadaily", "China Daily", "UK/US outlets")) |>
  group_by(group) |>
  summarise(
    n_articles = n(),
    mean_score1new = mean(score1new, na.rm = TRUE),
    sd_score1new = sd(score1new, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(article_scores, scores_path)
write_csv(bank_summary, summary_path)
write_csv(chenhan, benchmark_path)

left_panel <- bank_summary |>
  mutate(bank_label = factor(bank_label, levels = rev(bank_label))) |>
  ggplot(aes(x = mean_tone, y = bank_label, color = bank, xmin = ci_low, xmax = ci_high)) +
  geom_vline(xintercept = 0, color = "grey75", linetype = "dashed") +
  geom_errorbarh(height = 0, linewidth = 0.6) +
  geom_point(size = 2.8) +
  scale_color_manual(values = bank_colors_text, guide = "none") +
  labs(
    x = "Article-level tone score",
    y = NULL,
    title = "Pool Means"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    plot.title = element_text(face = "bold")
  )

right_panel <- article_scores |>
  ggplot(aes(x = tone_score, color = bank, fill = bank)) +
  geom_vline(xintercept = 0, color = "grey75", linetype = "dashed") +
  geom_density(alpha = 0.18, linewidth = 0.9, adjust = 1.1) +
  scale_color_manual(values = bank_colors_text, labels = bank_labels_text) +
  scale_fill_manual(values = bank_colors_text, labels = bank_labels_text) +
  labs(
    x = "Article-level tone score",
    y = "Density",
    title = "Score Distributions",
    color = NULL,
    fill = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

plot_out <- left_panel + right_panel +
  plot_layout(widths = c(1, 1.4), guides = "collect") +
  plot_annotation(
    title = "Content Validity of the Final Article Pools",
    subtitle = str_wrap(
      "Bing lexicon tone scores computed from all 89 finalized plain-text readings. As external background, Chen and Han's embedding-based benchmark reports UK/US outlets at -0.62 and China Daily at 0.60 on a different scale; those values are informative but not directly comparable to the lexicon scores shown here.",
      width = 115
    ),
    theme = theme(
      plot.title = element_text(size = 17, face = "bold"),
      plot.subtitle = element_text(size = 10.5)
    )
  )

ggsave(
  filename = figure_path,
  plot = plot_out,
  width = 12,
  height = 5.8,
  units = "in"
)

cat("Saved figure to:", figure_path, "\n")
cat("Saved article-level scores to:", scores_path, "\n")
cat("Saved summary to:", summary_path, "\n")
cat("Saved Chen-Han benchmarks to:", benchmark_path, "\n")
