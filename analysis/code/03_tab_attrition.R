source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()
randomized <- participant |> filter(recruited == 1)

attrition_rates <- randomized |>
  group_by(arm_label) |>
  summarise(
    n = n(),
    endline_rate = mean(complete_endline == 1, na.rm = TRUE),
    followup_rate = mean(complete_followup == 1, na.rm = TRUE),
    mean_last_week_active = mean(last_week_active, na.rm = TRUE),
    .groups = "drop"
  )

attrition_tests <- tibble(
  outcome = c("complete_endline", "complete_followup"),
  joint_p = c(
    joint_arm_pvalue(randomized |> filter(!is.na(complete_endline), !is.na(block_id), !is.na(arm_label)), "complete_endline"),
    joint_arm_pvalue(randomized |> filter(!is.na(complete_followup), !is.na(block_id), !is.na(arm_label)), "complete_followup")
  )
)

attrition_latex <- attrition_rates |>
  transmute(
    Arm = dplyr::recode(
      arm_label,
      "control" = "Control",
      "pro_low" = "Pro-China, low dose",
      "pro_high" = "Pro-China, high dose",
      "anti_low" = "Anti-China, low dose",
      "anti_high" = "Anti-China, high dose",
      "apol_china" = "Apolitical China"
    ),
    N = fmt_int(n),
    `Endline rate` = fmt_num(endline_rate, 3),
    `Follow-up rate` = fmt_num(followup_rate, 3),
    `Mean last active week` = fmt_num(mean_last_week_active, 3)
  )

write_latex_df(
  attrition_latex,
  file.path(tables_dir, "tab_attrition.tex"),
  "Attrition by Treatment Arm",
  "tab:attrition",
  align = "lcccc",
  notes = paste0(
    "Rates are calculated within the randomized sample. The joint p-value for differential endline attrition is ",
    fmt_p(attrition_tests$joint_p[attrition_tests$outcome == "complete_endline"]),
    "; the corresponding follow-up p-value is ",
    fmt_p(attrition_tests$joint_p[attrition_tests$outcome == "complete_followup"]),
    "."
  )
)

message("Wrote tables/tab_attrition.tex")
