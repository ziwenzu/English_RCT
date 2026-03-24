source(file.path("code", "_figure_helpers.R"))

participant <- prepare_participant()
recruited <- participant |> filter(recruited == 1)
endline <- recruited |> filter(complete_endline == 1)
followup <- recruited |> filter(complete_followup == 1)

mechanism_specs <- tribble(
  ~stage,                ~sample,    ~outcome,            ~label,                      ~controls,
  "Weekly engagement",   "recruited","w_n_comply",        "Compliant slots",           list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Weekly engagement",   "recruited","w_sum_read_min",    "Total reading minutes",     list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Weekly acceptance",   "recruited","w_mean_cred",       "Mean credibility rating",   list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Weekly acceptance",   "recruited","w_mean_similar",    "Mean want-more rating",     list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Immediate demand",    "endline",  "t1_wtp_bid",        "WTP bid (RMB)",             list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score")),
  "Immediate demand",    "endline",  "t1_wtp_buy",        "WTP buy indicator",         list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score", "t1_wtp_draw")),
  "Post-study demand",   "followup", "t2_digest_signup",  "Digest signup",             list(c("t0_rs_index", "t0_nat_index", "t0_trust_foreign", "t0_exam_score"))
)

plot_data <- pmap_dfr(
  mechanism_specs,
  function(stage, sample, outcome, label, controls) {
    dat <- switch(
      sample,
      recruited = recruited,
      endline = endline,
      followup = followup
    )

    clean_dat <- dat |>
      filter(!is.na(.data[[outcome]]), !is.na(block_id), !is.na(arm_label))

    for (cc in unlist(controls, use.names = FALSE)) {
      clean_dat <- clean_dat |> filter(!is.na(.data[[cc]]))
    }

    mod <- lm(
      reformulate(c("pro_any", "anti_any", "apol", unlist(controls, use.names = FALSE), "factor(block_id)"), response = outcome),
      data = clean_dat
    )

    ctrl_sd <- clean_dat |>
      filter(arm_label == "control") |>
      summarise(s = sd(.data[[outcome]], na.rm = TRUE)) |>
      pull(s)

    tidy_hc2(mod) |>
      filter(term %in% c("pro_any", "anti_any")) |>
      mutate(
        stage = stage,
        outcome_label = label,
        contrast = dplyr::recode(
          term,
          "pro_any" = "Pooled Pro-China",
          "anti_any" = "Pooled Anti-China"
        ),
        std_estimate = estimate / ctrl_sd,
        std_low = conf.low / ctrl_sd,
        std_high = conf.high / ctrl_sd
      ) |>
      select(stage, outcome_label, contrast, std_estimate, std_low, std_high)
  }
) |>
  mutate(
    stage = factor(stage, levels = c("Weekly engagement", "Weekly acceptance", "Immediate demand", "Post-study demand")),
    outcome_label = factor(
      outcome_label,
      levels = c(
        "Compliant slots",
        "Total reading minutes",
        "Mean credibility rating",
        "Mean want-more rating",
        "WTP bid (RMB)",
        "WTP buy indicator",
        "Digest signup"
      )
    )
  )

fig <- ggplot(plot_data, aes(x = std_estimate, y = outcome_label, color = contrast)) +
  geom_vline(xintercept = 0, linewidth = 0.4, linetype = "dashed", color = "#777777") +
  geom_errorbarh(aes(xmin = std_low, xmax = std_high), height = 0.18, linewidth = 0.5, position = position_dodge(width = 0.5)) +
  geom_point(size = 2.1, position = position_dodge(width = 0.5)) +
  facet_grid(stage ~ ., scales = "free_y", space = "free_y") +
  scale_color_manual(values = c("Pooled Pro-China" = "#0B6E4F", "Pooled Anti-China" = "#8B1E3F")) +
  labs(
    x = "Standardized treatment effect (control-group SD units)",
    y = NULL,
    color = NULL,
    title = "Mechanism Chain from Weekly Acceptance to Continued Demand"
  ) +
  paper_theme() +
  theme(
    strip.text.y = element_text(face = "bold"),
    legend.position = "top",
    panel.spacing.y = unit(0.9, "lines")
  )

save_figure(fig, "fig_mechanism_chain")

message("Wrote figures/fig_mechanism_chain.pdf")
