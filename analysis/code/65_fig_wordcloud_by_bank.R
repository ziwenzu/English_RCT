#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(ggwordcloud)
  library(readr)
  library(stringr)
  library(tidytext)
})

source("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/analysis/code/_text_analysis_helpers.R")

figure_path <- file.path(figures_dir_text, "fig_wordcloud_by_bank.pdf")
terms_path <- file.path(output_dir_text, "wordcloud_terms_by_bank.csv")

texts <- load_article_bank_texts() |>
  select(id, bank, text)

custom_stopwords <- tibble(
  word = c(
    stop_words$word,
    "china", "chinese", "beijing", "hong", "kong", "mainland",
    "said", "say", "says", "would", "could", "also", "still",
    "one", "two", "three", "first", "second", "new", "year",
    "years", "day", "days", "week", "weeks", "month", "months",
    "people", "many", "much", "may", "might", "make", "made",
    "used", "using", "use", "according", "told", "including",
    "around", "across", "within", "without", "among", "since",
    "however", "meanwhile", "whose", "where", "when", "while"
  )
) |>
  distinct()

term_data <- texts |>
  unnest_tokens(word, text) |>
  filter(str_detect(word, "^[a-z]+$"), nchar(word) >= 4) |>
  anti_join(custom_stopwords, by = "word") |>
  count(bank, id, word, name = "n_article") |>
  group_by(bank, word) |>
  summarise(
    n = sum(n_article),
    n_articles = n_distinct(id),
    .groups = "drop"
  ) |>
  filter(n_articles >= 2) |>
  bind_tf_idf(word, bank, n) |>
  group_by(bank) |>
  arrange(desc(tf_idf), desc(n), .by_group = TRUE) |>
  slice_head(n = 70) |>
  ungroup() |>
  mutate(
    bank_label = factor(
      unname(bank_labels_text[as.character(bank)]),
      levels = unname(bank_labels_text[bank_levels_text])
    ),
    color = unname(bank_colors_text[as.character(bank)])
  )

write_csv(term_data, terms_path)

plot_out <- ggplot(
  term_data,
  aes(
    label = word,
    size = tf_idf,
    color = bank,
    label_content = word
  )
) +
  geom_text_wordcloud_area(
    rm_outside = TRUE,
    shape = "square",
    eccentricity = 0.15,
    grid_size = 6,
    family = "Helvetica"
  ) +
  facet_wrap(~ bank_label, ncol = 2) +
  scale_size_area(max_size = 18) +
  scale_color_manual(values = bank_colors_text, guide = "none") +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid = element_blank(),
    strip.text = element_text(face = "bold", size = 12),
    plot.title = element_text(face = "bold", size = 17),
    plot.subtitle = element_text(size = 10.5)
  ) +
  labs(
    title = "Word Clouds of the Final Article Pools",
    subtitle = str_wrap(
      "Words are ranked within each pool by bank-level tf-idf rather than raw frequency, after removing standard stopwords and common China/news filler terms. Larger words are more distinctive of that pool's article set.",
      width = 115
    )
  )

ggsave(
  filename = figure_path,
  plot = plot_out,
  width = 12,
  height = 9,
  units = "in"
)

cat("Saved figure to:", figure_path, "\n")
cat("Saved term data to:", terms_path, "\n")
