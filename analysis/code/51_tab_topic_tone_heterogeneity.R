#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(glue)
  library(readr)
})

source("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/analysis/code/_text_analysis_helpers.R")

dir.create(tables_dir_text, showWarnings = FALSE, recursive = TRUE)
table_path <- file.path(tables_dir_text, "tab_topic_tone_heterogeneity.tex")

fmt_num <- function(x, digits = 3) sprintf(paste0("%.", digits, "f"), x)
fmt_cell <- function(x, digits = 3) ifelse(is.na(x), "--", fmt_num(x, digits))

texts <- load_article_bank_texts()
article_scores <- compute_article_tone_scores(texts)
topic_summary <- summarise_topic_tone(article_scores) |>
  arrange(bank, desc(mean_tone))

body_lines <- c()
current_bank <- NULL

for (i in seq_len(nrow(topic_summary))) {
  row <- topic_summary[i, ]
  if (!identical(as.character(row$bank), current_bank)) {
    current_bank <- as.character(row$bank)
    body_lines <- c(body_lines, glue("\\addlinespace[0.35em]\n\\multicolumn{{5}}{{l}}{{\\textit{{{current_bank}}}}}\\\\"))
  }
    body_lines <- c(
    body_lines,
    glue(
      "{row$topic_family} & {row$n_articles} & {fmt_cell(row$mean_tone)} & {fmt_cell(row$ci_low)} & {fmt_cell(row$ci_high)}\\\\"
    )
  )
}

lines <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Article-Level Tone Heterogeneity by Topic Family}",
  "\\label{tab:topic_tone_heterogeneity}",
  "\\footnotesize",
  "\\begin{tabular}{lcccc}",
  "\\toprule",
  "Topic family & $N$ & Mean tone & 95\\% CI low & 95\\% CI high\\\\",
  "\\midrule",
  body_lines,
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{tablenotes}",
  "\\footnotesize",
  "\\item Entries report article-level China-valence scores aggregated to broad topic families within each content pool. Scores are computed from China-anchored sentences only, using a domain-specific contrast between pro-China policy terms and anti-China criticism terms. Criticism terms receive a modestly heavier weight so that anti-China political framing is not mechanically diluted by neutral policy nouns. Higher values indicate more positively valenced China-directed framing. Topic families are constructed from the finalized materials-bank topic labels.",
  "\\end{tablenotes}",
  "\\end{threeparttable}",
  "\\end{table}"
)

writeLines(lines, table_path)
cat("Saved table to:", table_path, "\n")
