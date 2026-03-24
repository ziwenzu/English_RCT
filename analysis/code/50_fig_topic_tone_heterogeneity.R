#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(stringr)
  library(tidytext)
})

source("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/analysis/code/_text_analysis_helpers.R")

figure_path <- file.path(figures_dir_text, "fig_topic_tone_heterogeneity.pdf")
summary_path <- file.path(output_dir_text, "topic_tone_summary.csv")

texts <- load_article_bank_texts()
article_scores <- compute_article_tone_scores(texts)
topic_summary <- summarise_topic_tone(article_scores)

write_csv(topic_summary, summary_path)

plot_data <- topic_summary |>
  mutate(
    topic_label = paste0(topic_family, " (n=", n_articles, ")"),
    topic_label = reorder_within(topic_label, mean_tone, bank)
  )

plot_out <- ggplot(
  plot_data,
  aes(x = mean_tone, y = topic_label, color = bank)
) +
  geom_vline(xintercept = 0, color = "grey80", linetype = "dashed") +
  geom_errorbarh(
    data = subset(plot_data, !is.na(ci_low) & !is.na(ci_high)),
    aes(xmin = ci_low, xmax = ci_high),
    height = 0,
    linewidth = 0.55
  ) +
  geom_point(size = 2.4) +
  facet_wrap(~ bank, scales = "free_y", ncol = 2) +
  scale_y_reordered() +
  scale_color_manual(
    values = c(
      "Pro-China" = unname(bank_colors_text["PRO"]),
      "Anti-China" = unname(bank_colors_text["ANTI"]),
      "Apolitical China" = unname(bank_colors_text["APOL_CHINA"]),
      "Non-China control" = unname(bank_colors_text["NONCHINA_CONTROL"])
    ),
    guide = "none"
  ) +
  labs(
    x = "Mean article-level China-valence score",
    y = NULL,
    title = "Article-Level China-Valence Heterogeneity by Topic Family",
    subtitle = "Within each pool, directed China-valence varies systematically by substantive topic as well as by overall treatment label; criticism terms receive a modestly heavier weight to keep pro and anti pools comparably separated."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold", size = 17),
    plot.subtitle = element_text(size = 10.5)
  )

ggsave(
  filename = figure_path,
  plot = plot_out,
  width = 12.5,
  height = 8.5,
  units = "in"
)

cat("Saved figure to:", figure_path, "\n")
cat("Saved topic summary to:", summary_path, "\n")
