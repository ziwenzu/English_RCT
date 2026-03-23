source(file.path("code", "_table_helpers.R"))

participant <- prepare_participant()

sample_flow <- tibble(
  Stage = c(
    "Completed baseline survey",
    "Randomized (recruited)",
    "Completed endline survey",
    "Completed follow-up survey"
  ),
  N = fmt_int(c(
    nrow(participant),
    sum(participant$recruited == 1, na.rm = TRUE),
    sum(participant$complete_endline == 1, na.rm = TRUE),
    sum(participant$complete_followup == 1, na.rm = TRUE)
  ))
)

write_latex_df(
  sample_flow,
  file.path(tables_dir, "tab_sample_flow.tex"),
  "Sample Flow",
  "tab:sample_flow",
  align = "lc",
  notes = "This table reports the realized sample flow from the baseline frame to the randomized, endline, and follow-up samples."
)

message("Wrote tables/tab_sample_flow.tex")
