source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
endline <- participant |>
  filter(recruited == 1, complete_endline == 1) |>
  mutate(
    positive_bid = as.integer(t1_wtp_bid > 0),
    draw10_c = (t1_wtp_draw - mean(t1_wtp_draw, na.rm = TRUE)) / 10
  )

controls <- c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")

run_simple_metric <- function(data, outcome, label, extra_controls = NULL) {
  run_pooled_model(
    data,
    outcome,
    label,
    controls = c(controls, extra_controls),
    vcov = "HC2"
  )
}

price_slope_results <- {
  dat <- endline |>
    select(t1_wtp_buy, draw10_c, all_of(controls), pro_any, anti_any, apol, block_id) |>
    filter(
      !is.na(t1_wtp_buy),
      !is.na(draw10_c),
      !is.na(block_id),
      if_all(all_of(controls), ~ !is.na(.x))
    )

  mod <- lm(
    t1_wtp_buy ~ pro_any + anti_any + apol + draw10_c +
      pro_any:draw10_c + anti_any:draw10_c + apol:draw10_c +
      t0_rs_index + t0_nat_index + t0_trust_foreign + t0_exam_score +
      factor(block_id),
    data = dat
  )

  tidy_hc2(mod) |>
    filter(term %in% c("pro_any:draw10_c", "anti_any:draw10_c", "apol:draw10_c")) |>
    mutate(
      outcome_label = "Price-slope difference in buy model (pp per 10 RMB)",
      term = dplyr::recode(
        term,
        "pro_any:draw10_c" = "pro_any",
        "anti_any:draw10_c" = "anti_any",
        "apol:draw10_c" = "apol"
      ),
      n = nrow(dat)
    )
}

results <- bind_rows(
  run_simple_metric(endline, "positive_bid", "Any positive bid"),
  run_simple_metric(endline, "t1_wtp_bid", "WTP bid / consumer surplus (RMB)"),
  run_simple_metric(
    endline |> filter(positive_bid == 1),
    "t1_wtp_bid",
    "WTP bid among positive bidders (RMB)"
  ),
  run_simple_metric(
    endline,
    "t1_wtp_buy",
    "Buy indicator at mean randomized price",
    extra_controls = "draw10_c"
  ),
  price_slope_results
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
  file.path(tables_dir, "tab_wtp_decomposition.tex"),
  "WTP Decomposition: Extensive Margin, Intensive Margin, and Price Sensitivity",
  "tab:wtp_decomposition",
  align = "llcccc",
  notes = "Entries report pooled treatment contrasts relative to the non-China control arm among endline respondents. `WTP bid / consumer surplus' is the incentive-compatible BDM bid and therefore equals the individual's reservation value for access to the foreign-news outlet. `Buy indicator at mean randomized price' estimates treatment effects on purchase at the sample-mean BDM draw; the draw is centered and rescaled in 10-RMB units. The final rows report treatment differences in the price slope of purchase probabilities from a buy-equation that interacts treatment indicators with the centered BDM draw. All models include randomization-block fixed effects and baseline covariates for regime support, nationalism, trust in foreign media, and exam performance."
)

message("Wrote tables/tab_wtp_decomposition.tex")
