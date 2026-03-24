source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
endline <- participant |>
  filter(recruited == 1, complete_endline == 1)

weekly_slot2 <- read_dta(file.path(root_dir, "data", "weekly_long.dta")) |>
  left_join(
    participant |> select(study_id, block_id),
    by = "study_id"
  ) |>
  mutate(
    arm = as.integer(arm),
    study_id = as.integer(study_id),
    pro_any = as.integer(arm %in% c(1L, 2L)),
    anti_any = as.integer(arm %in% c(3L, 4L)),
    apol = as.integer(arm == 5L),
    arm_label = factor(
      arm,
      levels = 1:6,
      labels = c("pro_low", "pro_high", "anti_low", "anti_high", "apol_china", "control")
    ),
    arm_label = relevel(arm_label, ref = "control")
  ) |>
  filter(slot_wk == 2) |>
  group_by(study_id, arm, arm_label, block_id, pro_any, anti_any, apol) |>
  summarise(
    slot2_read = mean(wk_read_min, na.rm = TRUE),
    slot2_quiz = mean(wk_quiz_score, na.rm = TRUE),
    slot2_cred = mean(wk_rate_cred, na.rm = TRUE),
    slot2_similar = mean(wk_rate_similar, na.rm = TRUE),
    .groups = "drop"
  ) |>
  left_join(
    participant |>
      select(study_id, t0_exam_score, t0_trust_chat, t0_rs_index, t0_nat_index, t0_trust_foreign),
    by = "study_id"
  )

negative_specs <- tribble(
  ~dataset,  ~outcome,          ~label,                                        ~controls,
  "endline", "t1_trust_chat",   "Trust in ChatGPT (endline)",                  list("t0_trust_chat"),
  "slot2",   "slot2_read",      "Slot-2 reading minutes (non-political)",      list(c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign")),
  "slot2",   "slot2_quiz",      "Slot-2 quiz score (non-political)",           list(c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign")),
  "slot2",   "slot2_cred",      "Slot-2 credibility rating (non-political)",   list(c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign")),
  "slot2",   "slot2_similar",   "Slot-2 want-more rating (non-political)",     list(c("t0_exam_score", "t0_rs_index", "t0_nat_index", "t0_trust_foreign"))
)

results <- pmap_dfr(
  negative_specs,
  function(dataset, outcome, label, controls) {
    dat <- if (dataset == "endline") endline else weekly_slot2
    run_pooled_model(
      dat,
      outcome,
      label,
      controls = unlist(controls, use.names = FALSE),
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
  file.path(tables_dir, "tab_negative_controls.tex"),
  "Negative Controls and Cross-Slot Spillovers",
  "tab:negative_controls",
  align = "llcccc",
  notes = "The first outcome is a survey-based negative control: trust in ChatGPT, which should not be directly shifted by the foreign-news treatments. The remaining outcomes aggregate slot-2 weekly performance and reactions, where all experimental arms received the same non-political content. These slot-2 rows therefore function as cross-slot spillover tests rather than pure placebos: significant estimates indicate that treatment changed general receptivity or study engagement beyond the treated political slot. Endline models include the baseline value of trust in ChatGPT and randomization-block fixed effects. Slot-2 models include baseline exam score, baseline regime support, baseline nationalism, baseline trust in foreign media, and randomization-block fixed effects."
)

message("Wrote tables/tab_negative_controls.tex")
