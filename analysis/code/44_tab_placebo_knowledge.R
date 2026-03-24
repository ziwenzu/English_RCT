source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant() |>
  mutate(
    t1_placebo_prop2 = (t1_kq11 + t1_kq12) / 2,
    t2_placebo_prop2 = (t2_kq11 + t2_kq12) / 2
  )

knowledge_specs <- tribble(
  ~sample,      ~outcome,            ~label,
  "endline",    "t1_know_prop10",    "Content knowledge (endline)",
  "endline",    "t1_placebo_prop2",  "Placebo knowledge items (endline)",
  "followup",   "t2_know_prop10",    "Content knowledge (follow-up)",
  "followup",   "t2_placebo_prop2",  "Placebo knowledge items (follow-up)"
)

results <- pmap_dfr(
  knowledge_specs,
  function(sample, outcome, label) {
    dat <- if (sample == "endline") {
      participant |> filter(recruited == 1, complete_endline == 1)
    } else {
      participant |> filter(recruited == 1, complete_followup == 1)
    }

    run_pooled_model(
      dat,
      outcome,
      label,
      controls = c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign"),
      vcov = "HC2"
    )
  }
) |>
  mutate(
    Contrast = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China"
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
  file.path(tables_dir, "tab_placebo_knowledge.tex"),
  "Content Knowledge Versus Placebo Knowledge Items",
  "tab:placebo_knowledge",
  align = "llcccc",
  notes = "The content-knowledge outcomes use the 10 treatment-relevant quiz items; the placebo outcomes use the two pre-registered placebo items (`kq11' and `kq12'), averaged to lie on a 0-1 scale. Because no baseline knowledge battery was administered, models control for baseline exam score, baseline regime support, baseline nationalism, baseline trust in foreign media, and randomization-block fixed effects. Null effects on the placebo rows provide the cleanest available approximation to the registered placebo-knowledge test."
)

message("Wrote tables/tab_placebo_knowledge.tex")
