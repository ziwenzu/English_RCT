source(file.path("code", "_table_helpers.R"))

slot1_acceptance <- read_dta(file.path(root_dir, "data", "weekly_long.dta")) |>
  mutate(
    study_id = as.integer(study_id),
    arm = as.integer(arm)
  ) |>
  filter(slot_wk == 1) |>
  group_by(study_id, arm) |>
  summarise(
    slot1_mean_cred = mean(wk_rate_cred, na.rm = TRUE),
    slot1_mean_interest = mean(wk_rate_interest, na.rm = TRUE),
    .groups = "drop"
  )

participant <- prepare_participant() |>
  left_join(slot1_acceptance, by = c("study_id", "arm")) |>
  filter(recruited == 1, complete_endline == 1, arm %in% 1:5)

participant <- participant |>
  mutate(
    cred_slot1_z = z_from_ref(slot1_mean_cred, slot1_mean_cred[arm %in% 1:5])
  )

cred_specs <- het_outcome_map()

results <- pmap_dfr(
  cred_specs,
  function(outcome, baseline, label) {
    dat <- participant |>
      select(all_of(c(outcome, baseline, "cred_slot1_z")), pro_any, anti_any, block_id) |>
      filter(
        !is.na(.data[[outcome]]),
        !is.na(.data[[baseline]]),
        !is.na(cred_slot1_z),
        !is.na(block_id)
      )

    mod <- lm(
      as.formula(
        paste0(
          outcome,
          " ~ pro_any + anti_any + cred_slot1_z + ",
          "pro_any:cred_slot1_z + anti_any:cred_slot1_z + ",
          baseline,
          " + factor(block_id)"
        )
      ),
      data = dat
    )

    ctrl_mean <- participant |>
      filter(arm == 5) |>
      summarise(m = mean(.data[[outcome]], na.rm = TRUE)) |>
      pull(m)

    tidy_hc2(mod) |>
      filter(term %in% c("pro_any", "anti_any", "cred_slot1_z", "pro_any:cred_slot1_z", "anti_any:cred_slot1_z")) |>
      mutate(outcome_label = label, control_mean = ctrl_mean, n = nrow(dat))
  }
) |>
  mutate(
    term = dplyr::recode(
      term,
      "pro_any" = "Pooled Pro-China",
      "anti_any" = "Pooled Anti-China",
      "cred_slot1_z" = "Assigned-content credibility (z)",
      "pro_any:cred_slot1_z" = "Pro x credibility",
      "anti_any:cred_slot1_z" = "Anti x credibility"
    )
  )

write_latex_reg_table(
  results,
  file.path(tables_dir, "tab_credibility_moderation_t1.tex"),
  "Exploratory Credibility Moderation Relative to Apolitical Content",
  "tab:credibility_moderation_t1",
  notes = "Each column reports an endline ANCOVA specification estimated on the pooled Pro-China, pooled Anti-China, and apolitical-China arms only, so that the apolitical-China arm is the omitted reference category. `Assigned-content credibility' is the participant's mean slot-1 credibility rating over assigned weekly materials, standardized within the non-control endline sample. Because credibility is post-treatment, these interactions should be interpreted as exploratory robustness checks rather than purely causal moderators.",
  term_order = c(
    "Pooled Pro-China",
    "Pooled Anti-China",
    "Assigned-content credibility (z)",
    "Pro x credibility",
    "Anti x credibility"
  ),
  outcome_order = cred_specs$label
)

message("Wrote tables/tab_credibility_moderation_t1.tex")
