source(file.path("code", "_table_helpers.R"))

suppressPackageStartupMessages({
  library(ggplot2)
})

figures_dir <- file.path(root_dir, "output", "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

paper_theme <- function() {
  theme_minimal(base_family = "serif", base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      legend.position = "bottom",
      legend.title = element_blank(),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold"),
      axis.title = element_text(face = "bold")
    )
}

save_figure <- function(plot, stem, width = 8, height = 5) {
  ggsave(
    filename = file.path(figures_dir, paste0(stem, ".pdf")),
    plot = plot,
    width = width,
    height = height
  )
}

marginal_effect_grid <- function(model, moderator, outcome_label, treat_map, grid) {
  beta <- coef(model)
  vc <- hc2_vcov(model)

  map_dfr(names(treat_map), function(term_name) {
    interaction_name <- paste0(term_name, ":", moderator)
    if (!(interaction_name %in% names(beta))) {
      stop(paste("Missing interaction term:", interaction_name))
    }

    tibble(z = grid) |>
      rowwise() |>
      mutate(
        estimate = beta[[term_name]] + z * beta[[interaction_name]],
        std.error = sqrt(
          vc[term_name, term_name] +
            (z^2) * vc[interaction_name, interaction_name] +
            2 * z * vc[term_name, interaction_name]
        ),
        conf.low = estimate - 1.96 * std.error,
        conf.high = estimate + 1.96 * std.error,
        treatment = treat_map[[term_name]],
        outcome = outcome_label
      ) |>
      ungroup()
  })
}

fit_het_model_for_figure <- function(data, outcome, baseline, moderator) {
  dat <- data |>
    select(all_of(c(outcome, baseline, moderator)), pro_any, anti_any, apol, block_id) |>
    filter(
      !is.na(.data[[outcome]]),
      !is.na(.data[[baseline]]),
      !is.na(.data[[moderator]]),
      !is.na(block_id)
    )

  lm(
    as.formula(
      paste0(
        outcome,
        " ~ pro_any + anti_any + apol + ", moderator,
        " + pro_any:", moderator,
        " + anti_any:", moderator,
        " + apol:", moderator,
        " + ", baseline,
        " + factor(block_id)"
      )
    ),
    data = dat
  )
}
