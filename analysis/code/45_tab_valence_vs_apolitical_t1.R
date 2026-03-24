source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant() |>
  filter(recruited == 1, complete_endline == 1, arm %in% 1:5)

pairwise_vs_apol <- function(data, outcome, baseline, label) {
  dat <- data |>
    select(all_of(c(outcome, baseline)), pro_any, anti_any, block_id) |>
    filter(!is.na(.data[[outcome]]), !is.na(.data[[baseline]]), !is.na(block_id))

  mod <- lm(
    as.formula(paste0(outcome, " ~ pro_any + anti_any + ", baseline, " + factor(block_id)")),
    data = dat
  )

  tidy_hc2(mod) |>
    filter(term %in% c("pro_any", "anti_any")) |>
    mutate(outcome_label = label, n = nrow(dat))
}

results <- pmap_dfr(
  main_outcome_map(),
  function(outcome, baseline, label) {
    pairwise_vs_apol(participant, outcome, baseline, label)
  }
) |>
  mutate(
    Contrast = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China vs Apolitical",
      "anti_any" = "Pooled Anti-China vs Apolitical"
    ),
    Estimate = paste0(fmt_num(estimate, 3), sig_stars(p.value)),
    `Std. Error` = fmt_num(std.error, 3),
    `p-value` = fmt_p(p.value),
    N = fmt_int(n)
  ) |>
  transmute(
    Outcome = outcome_label,
    Contrast,
    Estimate,
    `Std. Error`,
    `p-value`,
    N
  ) |>
  arrange(Outcome, Contrast)

write_latex_df(
  results,
  file.path(tables_dir, "tab_valence_vs_apolitical_t1.tex"),
  "Endline Valence Contrasts Relative to Apolitical China Content",
  "tab:valence_vs_apolitical_t1",
  align = "llcccc",
  notes = "Entries report pooled Pro-China and pooled Anti-China contrasts relative to the apolitical-China arm, estimated on the five non-control arms only. All specifications include the baseline value of the dependent variable and randomization-block fixed effects. This table is designed to map as closely as possible to the registered valence comparisons that used apolitical content as the neutral benchmark."
)

message("Wrote tables/tab_valence_vs_apolitical_t1.tex")
