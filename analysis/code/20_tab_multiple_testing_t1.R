source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
endline <- participant |> filter(recruited == 1, complete_endline == 1)

results <- pmap_dfr(
  main_outcome_map(),
  \(outcome, baseline, label) run_pooled_ancova(endline, outcome, baseline, label)
) |>
  mutate(
    contrast = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China"
    ),
    holm_p = p.adjust(p.value, method = "holm")
  ) |>
  mutate(
    bh_q = p.adjust(p.value, method = "BH"),
    Estimate = paste0(fmt_num(estimate, 3), sig_stars(p.value)),
    `Raw p` = fmt_p(p.value),
    `Holm p` = fmt_p(holm_p),
    `BH q` = fmt_p(bh_q)
  ) |>
  transmute(
    Outcome = outcome_label,
    Contrast = contrast,
    Estimate,
    `Raw p`,
    `Holm p`,
    `BH q`
  ) |>
  arrange(Outcome, Contrast)

write_latex_df(
  results,
  file.path(tables_dir, "tab_multiple_testing_t1.tex"),
  "Multiple-Testing Adjustments for Pooled Endline Effects",
  "tab:multiple_testing_t1",
  align = "llcccc",
  notes = "Raw p-values come from the pooled ANCOVA models. Holm-adjusted p-values are computed across the full displayed family of primary pooled endline contrasts. Benjamini-Hochberg q-values are computed across the same displayed family of tests."
)

message("Wrote tables/tab_multiple_testing_t1.tex")
