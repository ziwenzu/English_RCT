#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(haven)
  library(jsonlite)
  library(patchwork)
  library(readr)
  library(stringr)
  library(tibble)
  library(tidyr)
  library(tidytext)
  library(purrr)
})

analysis_dir <- "/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/analysis"
project_dir <- dirname(analysis_dir)
teaching_dir <- file.path(project_dir, "teaching")
texts_dir <- file.path(teaching_dir, "article_texts")
figures_dir <- file.path(analysis_dir, "figures")
output_dir <- file.path(analysis_dir, "output", "content_validity")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

bank_path <- file.path(teaching_dir, "materials_master_bank.csv")
manifest_path <- file.path(texts_dir, "_manifest.json")
chenhan_path <- file.path(project_dir, "3-replication-package", "data", "analysis data", "work_data.dta")

figure_path <- file.path(figures_dir, "fig_content_validity_tone.pdf")
scores_path <- file.path(output_dir, "article_tone_scores.csv")
summary_path <- file.path(output_dir, "article_tone_summary.csv")
benchmark_path <- file.path(output_dir, "chen_han_benchmarks.csv")

bank_levels <- c("PRO", "ANTI", "APOL_CHINA", "NONCHINA_CONTROL")
bank_labels <- c(
  PRO = "Pro-China",
  ANTI = "Anti-China",
  APOL_CHINA = "Apolitical China",
  NONCHINA_CONTROL = "Non-China control"
)
bank_colors <- c(
  PRO = "#1599a7",
  ANTI = "#e66b63",
  APOL_CHINA = "#c99a2e",
  NONCHINA_CONTROL = "#6b7280"
)

read_body_text <- function(article_id) {
  path <- file.path(texts_dir, paste0(article_id, ".txt"))
  if (!file.exists(path)) {
    return(NA_character_)
  }
  raw <- read_file(path)
  parts <- str_split(raw, "\n=+\n", n = 2, simplify = TRUE)
  body <- if (ncol(parts) >= 2) parts[, 2] else raw
  body <- str_replace_all(body, "\r", "\n")
  body <- str_replace_all(body, "\\!\\[[^\\]]*\\]\\([^\\)]*\\)", " ")
  body <- str_replace_all(body, "\\[[^\\]]+\\]\\([^\\)]*\\)", " ")
  body <- str_replace_all(body, "(?m)^(Subscribe|Log in|Menu|Skip to content|Share|Stay|Eat|Do|Neighborhoods|Weekly edition|Past editions|Current topics|The Economist Pro)$", " ")
  body <- str_replace_all(body, "(?m)^People take photos.*$", " ")
  body <- str_replace_all(body, "(?m)^CITY GUIDE$", " ")
  body <- str_replace_all(body, "(?m)^By\\s+.+$", " ")
  body <- str_replace_all(body, "(?m)^Photos by\\s+.+$", " ")
  body <- str_replace_all(body, "\\s+", " ")
  str_trim(body)
}

manifest <- fromJSON(manifest_path, flatten = TRUE) |>
  as_tibble()

bank <- read_csv(bank_path, show_col_types = FALSE)

texts <- manifest |>
  filter(status == "ok") |>
  select(id, words, method) |>
  inner_join(bank, by = "id") |>
  mutate(
    text = map_chr(id, read_body_text),
    bank = factor(bank, levels = bank_levels)
  ) |>
  filter(!is.na(text), str_length(text) > 0)

bing <- get_sentiments("bing")

article_scores <- texts |>
  select(id, bank, source, title, method, text) |>
  unnest_tokens(word, text) |>
  inner_join(bing, by = "word") |>
  group_by(id, bank, source, title, method) |>
  summarise(
    n_matched = n(),
    n_positive = sum(sentiment == "positive", na.rm = TRUE),
    n_negative = sum(sentiment == "negative", na.rm = TRUE),
    tone_score = (n_positive - n_negative) / n_matched,
    .groups = "drop"
  )

article_scores <- texts |>
  select(id, bank, source, title, method) |>
  left_join(article_scores, by = c("id", "bank", "source", "title", "method")) |>
  mutate(
    n_matched = coalesce(n_matched, 0L),
    n_positive = coalesce(n_positive, 0L),
    n_negative = coalesce(n_negative, 0L),
    tone_score = coalesce(tone_score, 0)
  )

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
    bank_label = paste0(unname(bank_labels[as.character(bank)]), " (n=", n_articles, ")")
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
  mutate(bank_label = factor(bank_label, levels = bank_label)) |>
  ggplot(aes(x = mean_tone, y = bank_label, color = bank, xmin = ci_low, xmax = ci_high)) +
  geom_vline(xintercept = 0, color = "grey75", linetype = "dashed") +
  geom_errorbarh(height = 0, linewidth = 0.6) +
  geom_point(size = 2.8) +
  scale_color_manual(values = bank_colors, guide = "none") +
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
  scale_color_manual(values = bank_colors, labels = bank_labels) +
  scale_fill_manual(values = bank_colors, labels = bank_labels) +
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
    title = "Content Validity of the Article Pools",
    subtitle = str_wrap(
      "Bing lexicon tone scores from 76 locally archived full texts. In Chen and Han's embedding-based benchmark, UK/US outlets average -0.62 and China Daily averages 0.60; those values are reported here as qualitative background, not as a same-scale comparison.",
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
