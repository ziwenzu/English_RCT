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

figure_path <- file.path(figures_dir_text, "fig_text_balance_article_bank.pdf")
article_metrics_path <- file.path(text_balance_dir_text, "article_text_features.csv")
bank_summary_path <- file.path(text_balance_dir_text, "article_bank_text_balance_summary.csv")
anova_path <- file.path(text_balance_dir_text, "article_bank_text_balance_anova.csv")

selected_metrics <- c("word_count", "avg_sentence_length", "avg_word_length", "flesch_kincaid")

article_features <- compute_article_text_features()

bank_summary <- article_features |>
  group_by(bank) |>
  summarise(
    n_articles = n(),
    across(
      all_of(selected_metrics),
      list(
        mean = mean,
        sd = sd,
        se = ~ sd(.x) / sqrt(length(.x)),
        ci_low = ~ mean(.x) - 1.96 * sd(.x) / sqrt(length(.x)),
        ci_high = ~ mean(.x) + 1.96 * sd(.x) / sqrt(length(.x))
      ),
      .names = "{.col}_{.fn}"
    ),
    .groups = "drop"
  )

anova_results <- lapply(
  selected_metrics,
  function(metric) {
    model <- aov(reformulate("bank", response = metric), data = article_features)
    tibble(
      metric = metric,
      p_value = summary(model)[[1]][["Pr(>F)"]][1]
    )
  }
) |>
  bind_rows() |>
  mutate(metric_label = unname(text_metric_labels_text[metric]))

plot_long <- bank_summary |>
  transmute(
    bank,
    n_articles,
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
    cols = -c(bank, n_articles),
    names_to = c("metric", ".value"),
    names_pattern = "(.+)_(mean|ci_low|ci_high)"
  ) |>
  mutate(
    bank_label = factor(
      paste0(unname(bank_labels_text[as.character(bank)]), " (n=", n_articles, ")"),
      levels = paste0(unname(bank_labels_text[bank_levels_text]), " (n=", bank_summary$n_articles[match(bank_levels_text, bank_summary$bank)], ")")
    ),
    metric_label = factor(unname(text_metric_labels_text[metric]), levels = unname(text_metric_labels_text[selected_metrics]))
  )

dist_long <- article_features |>
  select(bank, all_of(selected_metrics)) |>
  pivot_longer(cols = all_of(selected_metrics), names_to = "metric", values_to = "value") |>
  mutate(
    bank_label = factor(unname(bank_labels_text[as.character(bank)]), levels = unname(bank_labels_text[bank_levels_text])),
    metric_label = factor(unname(text_metric_labels_text[metric]), levels = unname(text_metric_labels_text[selected_metrics]))
  )

left_panel <- ggplot(plot_long, aes(x = mean, y = bank_label, color = bank, xmin = ci_low, xmax = ci_high)) +
  geom_errorbarh(height = 0, linewidth = 0.55) +
  geom_point(size = 2.4) +
  facet_wrap(~ metric_label, scales = "free_x", ncol = 2) +
  scale_color_manual(values = bank_colors_text, guide = "none") +
  labs(
    x = NULL,
    y = NULL,
    title = "Pool Means and 95% CIs"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold")
  )

right_panel <- ggplot(dist_long, aes(x = value, y = bank_label, fill = bank)) +
  geom_boxplot(width = 0.6, alpha = 0.75, outlier.size = 1.1) +
  facet_wrap(~ metric_label, scales = "free_x", ncol = 2) +
  scale_fill_manual(values = bank_colors_text, guide = "none") +
  labs(
    x = NULL,
    y = NULL,
    title = "Article-Level Distributions"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold")
  )

plot_out <- left_panel + right_panel +
  plot_layout(widths = c(1, 1)) +
  plot_annotation(
    title = "Textual Balance Across the Final Article Pools",
    subtitle = "Diagnostics use cleaned plain-text readings and compare non-substantive textual properties rather than political valence. Metrics are article-level word count, sentence length, word length, and Flesch-Kincaid grade.",
    theme = theme(
      plot.title = element_text(size = 17, face = "bold"),
      plot.subtitle = element_text(size = 10.5)
    )
  )

write_csv(article_features, article_metrics_path)
write_csv(bank_summary, bank_summary_path)
write_csv(anova_results, anova_path)

ggsave(
  filename = figure_path,
  plot = plot_out,
  width = 13,
  height = 8.5,
  units = "in"
)

cat("Saved figure to:", figure_path, "\n")
cat("Saved article metrics to:", article_metrics_path, "\n")
cat("Saved bank summary to:", bank_summary_path, "\n")
cat("Saved ANOVA results to:", anova_path, "\n")
