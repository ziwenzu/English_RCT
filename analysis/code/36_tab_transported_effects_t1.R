source(file.path("code", "_table_helpers.R"))

build_crosswave_index <- function(data, data_vars, ref_data, ref_vars = data_vars, signs = rep(1, length(data_vars))) {
  component_matrix <- map2(
    seq_along(data_vars),
    signs,
    function(i, sgn) {
      sgn * z_from_ref(data[[data_vars[i]]], ref_data[[ref_vars[i]]])
    }
  ) |>
    do.call(what = cbind)

  index <- rowMeans(component_matrix, na.rm = TRUE)
  index[apply(is.na(component_matrix), 1, all)] <- NA_real_
  index
}

fit_weighted_pooled <- function(data, outcome, label, controls, weight_var) {
  dat <- data |>
    select(all_of(c(outcome, controls, weight_var)), pro_any, anti_any, apol, block_id) |>
    filter(!is.na(.data[[outcome]]), !is.na(block_id), !is.na(.data[[weight_var]]))

  for (cc in controls) {
    dat <- dat |> filter(!is.na(.data[[cc]]))
  }

  mod <- lm(
    reformulate(c("pro_any", "anti_any", "apol", controls, "factor(block_id)"), response = outcome),
    data = dat,
    weights = dat[[weight_var]]
  )

  tidy_with_vcov(mod, sandwich::vcovHC(mod, type = "HC2")) |>
    filter(term %in% c("pro_any", "anti_any", "apol")) |>
    mutate(outcome_label = label)
}

participant <- prepare_participant()
randomized <- participant |>
  filter(recruited == 1)
control_endline <- randomized |>
  filter(complete_endline == 1, arm == 6)

participant <- participant |>
  mutate(
    legitimacy_t0 = build_crosswave_index(
      participant,
      c("t0_rs_index", "t0_cen_index", "t0_trust_state", "t0_trust_comm", "t0_trust_soc"),
      randomized,
      c("t0_rs_index", "t0_cen_index", "t0_trust_state", "t0_trust_comm", "t0_trust_soc")
    ),
    legitimacy_t1 = build_crosswave_index(
      participant,
      c("t1_rs_index", "t1_cen_index", "t1_trust_state", "t1_trust_comm", "t1_trust_soc"),
      randomized,
      c("t0_rs_index", "t0_cen_index", "t0_trust_state", "t0_trust_comm", "t0_trust_soc")
    ),
    backlash_t0 = build_crosswave_index(
      participant,
      c("t0_nat_index", "t0_nat_bias", "t0_trust_foreign"),
      randomized,
      c("t0_nat_index", "t0_nat_bias", "t0_trust_foreign"),
      signs = c(1, 1, -1)
    ),
    backlash_t1 = build_crosswave_index(
      participant,
      c("t1_nat_index", "t1_nat_bias", "t1_trust_foreign"),
      randomized,
      c("t0_nat_index", "t0_nat_bias", "t0_trust_foreign"),
      signs = c(1, 1, -1)
    ),
    receptivity_t1 = build_crosswave_index(
      participant,
      c("t1_trust_foreign", "w_mean_cred", "w_mean_similar", "t1_wtp_bid", "t1_wtp_buy"),
      control_endline,
      c("t1_trust_foreign", "w_mean_cred", "w_mean_similar", "t1_wtp_bid", "t1_wtp_buy")
    )
  )

weight_covars <- default_weighting_covariates()

select_design <- add_imputed_covariates(participant, weight_covars)
participant_weighted <- select_design$data

recruit_model <- glm(
  reformulate(select_design$terms, response = "recruited"),
  data = participant_weighted,
  family = binomial()
)

participant_weighted <- participant_weighted |>
  mutate(
    p_recruited = trim_probabilities(predict(recruit_model, type = "response"))
  )

endline_design <- add_imputed_covariates(
  participant_weighted |> filter(recruited == 1),
  weight_covars
)
recruited_weighted <- endline_design$data

endline_model <- glm(
  reformulate(
    c("pro_any", "anti_any", "apol", endline_design$terms, "factor(block_id)"),
    response = "complete_endline"
  ),
  data = recruited_weighted,
  family = binomial()
)

recruited_weighted <- recruited_weighted |>
  mutate(
    p_endline = trim_probabilities(predict(endline_model, type = "response")),
    transported_weight = normalize_weights((1 / p_recruited) * (1 / p_endline))
  )

endline <- participant |>
  filter(recruited == 1, complete_endline == 1)
endline_transport <- recruited_weighted |>
  filter(complete_endline == 1)

specs <- tribble(
  ~outcome,           ~label,                                            ~controls,
  "legitimacy_t1",    "Legitimacy index (endline)",                      list("legitimacy_t0"),
  "receptivity_t1",   "Foreign media receptivity/demand index (endline)", list(c("t0_trust_foreign", "t0_exam_score", "t0_news_foreign_30d", "t0_freq_foreign", "t0_rs_index", "t0_nat_index")),
  "backlash_t1",      "Identity backlash index (endline)",               list("backlash_t0")
)

internal_results <- pmap_dfr(
  specs,
  function(outcome, label, controls) {
    run_pooled_model(
      endline,
      outcome,
      label,
      controls = unlist(controls, use.names = FALSE),
      vcov = "HC2"
    )
  }
) |>
  select(outcome_label, term, estimate, p.value) |>
  rename(internal_est = estimate, internal_p = p.value)

transported_results <- pmap_dfr(
  specs,
  function(outcome, label, controls) {
    fit_weighted_pooled(
      endline_transport,
      outcome,
      label,
      controls = unlist(controls, use.names = FALSE),
      weight_var = "transported_weight"
    )
  }
) |>
  select(outcome_label, term, estimate, p.value) |>
  rename(transported_est = estimate, transported_p = p.value)

results <- internal_results |>
  left_join(transported_results, by = c("outcome_label", "term")) |>
  mutate(
    Contrast = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China"
    ),
    `Internal ITT` = paste0(fmt_num(internal_est, 3), sig_stars(internal_p)),
    `Transported ITT` = paste0(fmt_num(transported_est, 3), sig_stars(transported_p))
  ) |>
  transmute(
    Outcome = outcome_label,
    Contrast,
    `Internal ITT`,
    `Transported ITT`
  ) |>
  arrange(Outcome, Contrast)

write_latex_df(
  results,
  file.path(tables_dir, "tab_transported_effects_t1.tex"),
  "Transported Endline Effects Reweighted to the Baseline Frame",
  "tab:transported_effects_t1",
  align = "llcc",
  notes = "Entries compare the internal endline ITT estimates from the randomized study sample with transported estimates reweighted to the baseline respondent frame. Transport weights combine the inverse predicted probability of entering the randomized sample and the inverse predicted probability of completing the endline survey, both estimated from baseline observables; probabilities are trimmed to [0.05, 0.95] and the final weights are normalized to have mean one among endline respondents. Transporting beyond the randomized sample relies on selection-on-observables and is therefore descriptive rather than design-based."
)

message("Wrote tables/tab_transported_effects_t1.tex")
