source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
randomized <- participant |> filter(recruited == 1)

balance_vars <- c(
  "blk_gender",
  "blk_region",
  "blk_eng_hi",
  "blk_nat_hi",
  "t0_female",
  "t0_exam_score",
  "t0_nat_index",
  "t0_rs_index",
  "t0_cen_index",
  "t0_trust_foreign",
  "t0_news_foreign_30d"
)

balance_table <- lapply(balance_vars, function(v) {
  dat <- randomized |>
    select(all_of(v), arm_label, block_id) |>
    filter(!is.na(.data[[v]]), !is.na(arm_label), !is.na(block_id))

  means <- dat |>
    group_by(arm_label) |>
    summarise(mean = mean(.data[[v]], na.rm = TRUE), .groups = "drop") |>
    pivot_wider(names_from = arm_label, values_from = mean)

  tibble(variable = v, n = nrow(dat), joint_p = joint_arm_pvalue(dat, v)) |>
    bind_cols(means)
}) |>
  bind_rows()

balance_latex <- balance_table |>
  transmute(
    Variable = dplyr::recode(
      variable,
      "blk_gender" = "Block gender",
      "blk_region" = "Block region",
      "blk_eng_hi" = "Block English proficiency",
      "blk_nat_hi" = "Block nationalism",
      "t0_female" = "Female",
      "t0_exam_score" = "Baseline exam score",
      "t0_nat_index" = "Baseline nationalism",
      "t0_rs_index" = "Baseline regime support",
      "t0_cen_index" = "Baseline censorship support",
      "t0_trust_foreign" = "Baseline trust in foreign media",
      "t0_news_foreign_30d" = "Baseline foreign news exposure"
    ),
    Control = fmt_num(control, 3),
    `Pro low` = fmt_num(pro_low, 3),
    `Pro high` = fmt_num(pro_high, 3),
    `Anti low` = fmt_num(anti_low, 3),
    `Anti high` = fmt_num(anti_high, 3),
    Apolitical = fmt_num(apol_china, 3),
    `Joint p` = fmt_p(joint_p),
    N = fmt_int(n)
  )

write_latex_df(
  balance_latex,
  file.path(tables_dir, "tab_balance.tex"),
  "Baseline Balance Across Treatment Arms",
  "tab:balance",
  align = "lcccccccc",
  notes = "Entries are group means in the randomized sample. The final column reports the heteroskedasticity-robust joint p-value from a regression of each baseline covariate on treatment-arm indicators with block fixed effects."
)

message("Wrote tables/tab_balance.tex")
