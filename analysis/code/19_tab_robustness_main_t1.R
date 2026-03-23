source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
randomized <- participant |> filter(recruited == 1)
endline <- randomized |> filter(complete_endline == 1)

ipw_mod <- glm(
  complete_endline ~ t0_rs_index + t0_nat_index + t0_trust_foreign + t0_exam_score + factor(block_id),
  data = randomized,
  family = binomial()
)

endline <- endline |>
  mutate(ipw = 1 / pmax(predict(ipw_mod, newdata = endline, type = "response"), 0.05))

robust_specs <- tribble(
  ~spec,                  ~extra_controls,                              ~weights, ~vcov, ~include_baseline,
  "Block FE only",        list(character(0)),                           NA,       "HC2",  FALSE,
  "Baseline ANCOVA",      list(character(0)),                           NA,       "HC2",  TRUE,
  "ANCOVA + controls",    list(c("t0_nat_index", "t0_exam_score")),     NA,       "HC2",  TRUE,
  "IPW ANCOVA",           list(character(0)),                           "ipw",    "HC2",  TRUE
)

outcome_specs <- tribble(
  ~outcome,           ~label,                    ~baseline,            ~add_controls,
  "t1_rs_index",      "Regime support",          "t0_rs_index",        list("t0_trust_foreign"),
  "t1_trust_foreign", "Trust in foreign media",  "t0_trust_foreign",   list("t0_rs_index")
)

results <- pmap_dfr(
  robust_specs,
  function(spec, extra_controls, weights, vcov, include_baseline) {
    pmap_dfr(
      outcome_specs,
      \(outcome, label, baseline, add_controls) {
        dat <- endline
        w <- if (is.na(weights)) NULL else dat[[weights]]
        controls_vec <- c(
          if (include_baseline) baseline else character(0),
          unlist(extra_controls, use.names = FALSE),
          unlist(add_controls, use.names = FALSE)
        ) |>
          unique()

        if (length(controls_vec) == 0) {
          controls_vec <- NULL
        }

        run_pooled_model(dat, outcome, label, controls = controls_vec, weights = w, vcov = vcov) |>
          mutate(spec = spec)
      }
    )
  }
) |>
  mutate(
    term = dplyr::recode(
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
    Specification = spec,
    Outcome = outcome_label,
    Contrast = term,
    Estimate,
    `Std. Error`,
    `p-value`,
    N
  ) |>
  arrange(Outcome, Contrast, Specification)

write_latex_df(
  results,
  file.path(tables_dir, "tab_robustness_main_t1.tex"),
  "Robustness of Main Endline Effects",
  "tab:robustness_main_t1",
  align = "lllcccc",
  notes = "Entries report pooled treatment contrasts relative to the non-China control arm under alternative specifications. `Block FE only` includes only treatment indicators and randomization-block fixed effects. `Baseline ANCOVA` adds the outcome-specific lagged dependent variable. `ANCOVA + controls` adds baseline nationalism, baseline exam score, and the other pre-treatment attitudinal index alongside the outcome-specific lagged dependent variable. `IPW ANCOVA` reweights endline respondents by the inverse predicted probability of completing the endline survey."
)

message("Wrote tables/tab_robustness_main_t1.tex")
