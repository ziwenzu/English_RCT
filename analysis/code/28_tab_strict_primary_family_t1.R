source(file.path("code", "_table_helpers.R"))

set.seed(20260323)

participant <- prepare_participant()
endline <- participant |> filter(recruited == 1, complete_endline == 1)
n_perm <- 1000L

strict_specs <- main_outcome_map()

permute_within_block <- function(arm, block_id) {
  ave(
    arm,
    block_id,
    FUN = function(x) sample(x, length(x), replace = FALSE)
  )
}

ri_results <- pmap_dfr(
  strict_specs,
  function(outcome, baseline, label) {
    dat <- endline |>
      select(all_of(c(outcome, baseline)), arm, block_id) |>
      mutate(
        arm = as.integer(arm),
        block_id = as.integer(block_id)
      ) |>
      filter(!is.na(.data[[outcome]]), !is.na(.data[[baseline]]), !is.na(arm), !is.na(block_id)) |>
      mutate(
        pro_any = as.integer(arm %in% c(1L, 2L)),
        anti_any = as.integer(arm %in% c(3L, 4L)),
        apol = as.integer(arm == 5L)
      )

    obs_mod <- lm(
      as.formula(paste0(outcome, " ~ pro_any + anti_any + apol + ", baseline, " + factor(block_id)")),
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
          as.formula(paste0(outcome, " ~ pro_perm + anti_perm + apol_perm + ", baseline, " + factor(block_id)")),
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
  file.path(tables_dir, "tab_strict_primary_family_t1.tex"),
  "Stricter Inference for the Primary Endline Outcome Family",
  "tab:strict_primary_family_t1",
  align = "llccccc",
  notes = paste0(
    "Entries report pooled ANCOVA estimates relative to the non-China control arm. `RI p' reports studentized randomization-inference p-values from ",
    fmt_int(n_perm),
    " within-block permutations that preserve the realized treatment counts in each randomization block. Holm-adjusted p-values and Benjamini-Hochberg q-values are computed across the full displayed family of tests."
  )
)

message("Wrote tables/tab_strict_primary_family_t1.tex")
