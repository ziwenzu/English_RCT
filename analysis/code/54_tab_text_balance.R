#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(glue)
})

source("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/analysis/code/_text_analysis_helpers.R")

dir.create(tables_dir_text, showWarnings = FALSE, recursive = TRUE)
dir.create(text_balance_dir_text, showWarnings = FALSE, recursive = TRUE)

table_path <- file.path(tables_dir_text, "tab_text_balance.tex")
bank_anova_path <- file.path(text_balance_dir_text, "article_bank_text_balance_anova.csv")
arm_anova_path <- file.path(text_balance_dir_text, "assigned_arm_text_balance_anova.csv")

selected_metrics <- c("word_count", "avg_sentence_length", "avg_word_length", "flesch_kincaid")

fmt_num <- function(x, digits = 2) sprintf(paste0("%.", digits, "f"), x)
fmt_p <- function(p) ifelse(is.na(p), "--", ifelse(p < 0.001, "<0.001", fmt_num(p, 3)))

article_features <- compute_article_text_features()
assignment_df <- simulate_content_assignment_text(article_features)
full_exposure <- summarise_assigned_text_exposure(assignment_df, slot_filter = "all")

bank_summary <- article_features |>
  group_by(bank) |>
  summarise(
    n_units = n(),
    across(all_of(selected_metrics), mean),
    .groups = "drop"
  ) |>
  mutate(label = unname(bank_labels_text[as.character(bank)]))

bank_anova <- lapply(
  selected_metrics,
  function(metric) {
    tibble(
      metric = metric,
      p_value = summary(aov(reformulate("bank", response = metric), data = article_features))[[1]][["Pr(>F)"]][1]
    )
  }
) |>
  bind_rows()

participant_means <- full_exposure$participant_means
arm_summary <- participant_means |>
  group_by(arm_label) |>
  summarise(
    n_units = n(),
    across(all_of(selected_metrics), mean),
    .groups = "drop"
  )

arm_anova <- lapply(
  selected_metrics,
  function(metric) {
    tibble(
      metric = metric,
      p_value = summary(aov(reformulate("arm_label", response = metric), data = participant_means))[[1]][["Pr(>F)"]][1]
    )
  }
) |>
  bind_rows()

write.csv(bank_anova, bank_anova_path, row.names = FALSE)
write.csv(arm_anova, arm_anova_path, row.names = FALSE)

make_line <- function(label, n_units, values) {
  glue(
    "{label} & {n_units} & {fmt_num(values[['word_count']], 0)} & {fmt_num(values[['avg_sentence_length']])} & {fmt_num(values[['avg_word_length']])} & {fmt_num(values[['flesch_kincaid']])}\\\\"
  )
}

panel_a <- c(
  "\\addlinespace[0.3em]",
  "\\multicolumn{6}{l}{\\textit{Panel A. Article pools}}\\\\"
)
for (i in seq_len(nrow(bank_summary))) {
  row <- bank_summary[i, ]
  panel_a <- c(
    panel_a,
    make_line(
      row$label,
      row$n_units,
      c(
        word_count = row$word_count,
        avg_sentence_length = row$avg_sentence_length,
        avg_word_length = row$avg_word_length,
        flesch_kincaid = row$flesch_kincaid
      )
    )
  )
}
panel_a <- c(
  panel_a,
  glue(
    "ANOVA $p$-value & -- & {fmt_p(bank_anova$p_value[bank_anova$metric == 'word_count'])} & {fmt_p(bank_anova$p_value[bank_anova$metric == 'avg_sentence_length'])} & {fmt_p(bank_anova$p_value[bank_anova$metric == 'avg_word_length'])} & {fmt_p(bank_anova$p_value[bank_anova$metric == 'flesch_kincaid'])}\\\\"
  )
)

panel_b <- c(
  "\\addlinespace[0.45em]",
  "\\multicolumn{6}{l}{\\textit{Panel B. Average assigned 24-reading bundle by arm}}\\\\"
)
for (i in seq_len(nrow(arm_summary))) {
  row <- arm_summary[i, ]
  panel_b <- c(
    panel_b,
    make_line(
      row$arm_label,
      row$n_units,
      c(
        word_count = row$word_count,
        avg_sentence_length = row$avg_sentence_length,
        avg_word_length = row$avg_word_length,
        flesch_kincaid = row$flesch_kincaid
      )
    )
  )
}
panel_b <- c(
  panel_b,
  glue(
    "ANOVA $p$-value & -- & {fmt_p(arm_anova$p_value[arm_anova$metric == 'word_count'])} & {fmt_p(arm_anova$p_value[arm_anova$metric == 'avg_sentence_length'])} & {fmt_p(arm_anova$p_value[arm_anova$metric == 'avg_word_length'])} & {fmt_p(arm_anova$p_value[arm_anova$metric == 'flesch_kincaid'])}\\\\"
  )
)

lines <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Textual Balance of the Final Reading Materials}",
  "\\label{tab:text_balance}",
  "\\footnotesize",
  "\\begin{tabular}{lccccc}",
  "\\toprule",
  "Group & $N$ & Word count & Words/sentence & Chars/word & Flesch-Kincaid\\\\",
  "\\midrule",
  panel_a,
  panel_b,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\footnotesize",
  "\\item Panel A reports article-level averages by content bank. Panel B reports participant-level averages of the 24 assigned readings using the implemented schedule design and the realized randomized sample. Higher Flesch-Kincaid values indicate more difficult reading material. These diagnostics assess non-substantive textual comparability rather than political valence.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

writeLines(lines, table_path)
cat("Saved table to:", table_path, "\n")
