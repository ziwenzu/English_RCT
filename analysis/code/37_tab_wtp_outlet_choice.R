source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
endline <- participant |>
  filter(recruited == 1, complete_endline == 1) |>
  mutate(
    no_purchase = as.integer(t1_wtp_buy == 0),
    buy_nyt = as.integer(t1_wtp_buy == 1 & t1_wtp_outlet == 1),
    buy_economist = as.integer(t1_wtp_buy == 1 & t1_wtp_outlet == 2),
    buy_wsj = as.integer(t1_wtp_buy == 1 & t1_wtp_outlet == 3),
    buy_wp = as.integer(t1_wtp_buy == 1 & t1_wtp_outlet == 4),
    share_nyt = as.integer(t1_wtp_outlet == 1),
    share_economist = as.integer(t1_wtp_outlet == 2),
    share_wsj = as.integer(t1_wtp_outlet == 3),
    share_wp = as.integer(t1_wtp_outlet == 4),
    draw10_c = (t1_wtp_draw - mean(t1_wtp_draw, na.rm = TRUE)) / 10
  )

controls <- c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")

extensive_specs <- tribble(
  ~outcome,          ~label,
  "no_purchase",     "No purchase",
  "buy_nyt",         "Buy New York Times",
  "buy_economist",   "Buy Economist",
  "buy_wsj",         "Buy Wall Street Journal",
  "buy_wp",          "Buy Washington Post"
)

conditional_specs <- tribble(
  ~outcome,            ~label,
  "share_nyt",         "Buyer share: New York Times",
  "share_economist",   "Buyer share: Economist",
  "share_wsj",         "Buyer share: Wall Street Journal",
  "share_wp",          "Buyer share: Washington Post"
)

extensive_results <- pmap_dfr(
  extensive_specs,
  function(outcome, label) {
    run_pooled_model(
      endline,
      outcome,
      label,
      controls = c(controls, "draw10_c"),
      vcov = "HC2"
    )
  }
)

conditional_results <- pmap_dfr(
  conditional_specs,
  function(outcome, label) {
    run_pooled_model(
      endline |> filter(t1_wtp_buy == 1),
      outcome,
      label,
      controls = c(controls, "draw10_c"),
      vcov = "HC2"
    )
  }
)

results <- bind_rows(extensive_results, conditional_results) |>
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
  file.path(tables_dir, "tab_wtp_outlet_choice.tex"),
  "WTP Outlet Choice: Extensive Margin Versus Outlet Composition",
  "tab:wtp_outlet_choice",
  align = "llcccc",
  notes = "The first five outcomes are mutually exclusive demand states among all endline respondents: not purchasing, purchasing New York Times, purchasing Economist, purchasing Wall Street Journal, or purchasing Washington Post. These rows identify whether treatment changes the probability of buying at all versus the probability of buying each outlet. The final four rows are descriptive conditional-share comparisons estimated among buyers only, included to show whether outlet composition shifts inside the buyer pool. All models include randomization-block fixed effects, baseline covariates for regime support, nationalism, trust in foreign media, and exam performance. Extensive-margin rows additionally condition on the centered randomized BDM draw; the buyer-share rows also include the centered draw for precision, but because they condition on post-treatment purchase they should be interpreted descriptively rather than as causal ITT estimates."
)

message("Wrote tables/tab_wtp_outlet_choice.tex")
