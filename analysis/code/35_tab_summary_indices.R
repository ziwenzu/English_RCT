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
    legitimacy_t2 = build_crosswave_index(
      participant,
      c("t2_rs_index", "t2_cen_index", "t2_trust_state", "t2_trust_comm", "t2_trust_soc"),
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

endline <- participant |>
  filter(recruited == 1, complete_endline == 1)
followup <- participant |>
  filter(recruited == 1, complete_followup == 1)

results <- bind_rows(
  run_pooled_model(
    endline,
    "legitimacy_t1",
    "Legitimacy index (endline)",
    controls = "legitimacy_t0",
    vcov = "HC2"
  ),
  run_pooled_model(
    followup,
    "legitimacy_t2",
    "Legitimacy index (follow-up)",
    controls = "legitimacy_t0",
    vcov = "HC2"
  ),
  run_pooled_model(
    endline,
    "receptivity_t1",
    "Foreign media receptivity/demand index (endline)",
    controls = c("t0_trust_foreign", "t0_exam_score", "t0_news_foreign_30d", "t0_freq_foreign", "t0_rs_index", "t0_nat_index"),
    vcov = "HC2"
  ),
  run_pooled_model(
    endline,
    "backlash_t1",
    "Identity backlash index (endline)",
    controls = "backlash_t0",
    vcov = "HC2"
  )
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
  file.path(tables_dir, "tab_summary_indices.tex"),
  "Summary Indices for Legitimacy, Receptivity, and Identity Backlash",
  "tab:summary_indices",
  align = "llcccc",
  notes = "The endline and follow-up legitimacy index averages standardized regime support, censorship support, trust in state media, trust in the Communist Party, and trust in society, with each follow-up component standardized using the randomized sample's baseline distribution. The endline identity-backlash index averages standardized nationalism, nationalism bias, and the reverse of trust in foreign media, again standardized on the randomized sample's baseline distribution. The endline foreign-media receptivity and demand index averages standardized trust in foreign media, mean weekly credibility, mean weekly demand for similar content, willingness to pay, and the WTP purchase indicator, standardized on the endline control group's distribution. Legitimacy and backlash models include the corresponding baseline index and randomization-block fixed effects. The receptivity/demand model includes baseline trust in foreign media, exam score, foreign-news exposure, foreign-news frequency, baseline regime support, baseline nationalism, and randomization-block fixed effects."
)

message("Wrote tables/tab_summary_indices.tex")
