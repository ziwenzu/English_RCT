source(file.path("code", "_table_helpers.R"))

set.seed(20260323)

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

n_perm <- 1000L

permute_within_block <- function(arm, block_id) {
  ave(
    arm,
    block_id,
    FUN = function(x) sample(x, length(x), replace = FALSE)
  )
}

strict_specs <- tribble(
  ~sample,      ~outcome,           ~baseline,          ~label,                                              ~controls,
  "endline",    "legitimacy_t1",    "legitimacy_t0",    "Legitimacy index (endline)",                       list("legitimacy_t0"),
  "followup",   "legitimacy_t2",    "legitimacy_t0",    "Legitimacy index (follow-up)",                     list("legitimacy_t0"),
  "endline",    "receptivity_t1",   NA_character_,      "Foreign media receptivity/demand index (endline)", list(c("t0_trust_foreign", "t0_exam_score", "t0_news_foreign_30d", "t0_freq_foreign", "t0_rs_index", "t0_nat_index")),
  "endline",    "backlash_t1",      "backlash_t0",      "Identity backlash index (endline)",                list("backlash_t0")
)

ri_results <- pmap_dfr(
  strict_specs,
  function(sample, outcome, baseline, label, controls) {
    controls <- unlist(controls, use.names = FALSE)

    dat <- participant |>
      filter(recruited == 1) |>
      filter(if (sample == "endline") complete_endline == 1 else complete_followup == 1) |>
      select(all_of(c(outcome, controls)), arm, block_id) |>
      mutate(
        arm = as.integer(arm),
        block_id = as.integer(block_id)
      ) |>
      filter(!is.na(.data[[outcome]]), !is.na(arm), !is.na(block_id))

    for (cc in controls) {
      dat <- dat |> filter(!is.na(.data[[cc]]))
    }

    dat <- dat |>
      mutate(
        pro_any = as.integer(arm %in% c(1L, 2L)),
        anti_any = as.integer(arm %in% c(3L, 4L)),
        apol = as.integer(arm == 5L)
      )

    obs_mod <- lm(
      reformulate(c("pro_any", "anti_any", "apol", controls, "factor(block_id)"), response = outcome),
      data = dat
    )
    obs_tidy <- tidy_hc2(obs_mod) |>
      filter(term %in% c("pro_any", "anti_any", "apol")) |>
      mutate(outcome_label = label)

    perm_stats <- replicate(
      n_perm,
      {
        arm_perm <- permute_within_block(dat$arm, dat$block_id)
        dat_perm <- dat |>
          mutate(
            pro_perm = as.integer(arm_perm %in% c(1L, 2L)),
            anti_perm = as.integer(arm_perm %in% c(3L, 4L)),
            apol_perm = as.integer(arm_perm == 5L)
          )

        perm_mod <- lm(
          reformulate(c("pro_perm", "anti_perm", "apol_perm", controls, "factor(block_id)"), response = outcome),
          data = dat_perm
        )

        tidy_hc2(perm_mod) |>
          filter(term %in% c("pro_perm", "anti_perm", "apol_perm")) |>
          mutate(term = dplyr::recode(term, "pro_perm" = "pro_any", "anti_perm" = "anti_any", "apol_perm" = "apol")) |>
          select(term, statistic)
      },
      simplify = FALSE
    )

    perm_dist <- bind_rows(perm_stats, .id = "draw")

    obs_tidy |>
      rowwise() |>
      mutate(
        ri_p = mean(abs(perm_dist$statistic[perm_dist$term == term]) >= abs(statistic))
      ) |>
      ungroup()
  }
) |>
  mutate(
    Contrast = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "apol" = "Apolitical China"
    ),
    holm_p = p.adjust(p.value, method = "holm"),
    bh_q = p.adjust(p.value, method = "BH"),
    Estimate = paste0(fmt_num(estimate, 3), sig_stars(p.value)),
    `HC2 p` = fmt_p(p.value),
    `RI p` = fmt_p(ri_p),
    `Holm p` = fmt_p(holm_p),
    `BH q` = fmt_p(bh_q)
  ) |>
  transmute(
    Outcome = outcome_label,
    Contrast,
    Estimate,
    `HC2 p`,
    `RI p`,
    `Holm p`,
    `BH q`
  ) |>
  arrange(Outcome, Contrast)

write_latex_df(
  ri_results,
  file.path(tables_dir, "tab_summary_indices_strict.tex"),
  "Stricter Inference for Summary Indices",
  "tab:summary_indices_strict",
  align = "llccccc",
  notes = paste0(
    "Entries report pooled ANCOVA estimates relative to the non-China control arm for the summary indices. `RI p' reports studentized randomization-inference p-values from ",
    fmt_int(n_perm),
    " within-block permutations that preserve the realized treatment counts in each randomization block. Holm-adjusted p-values and Benjamini-Hochberg q-values are computed across the full displayed family of tests."
  )
)

message("Wrote tables/tab_summary_indices_strict.tex")
