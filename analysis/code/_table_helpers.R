suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(readr)
  library(sandwich)
  library(lmtest)
  library(tidyr)
  library(purrr)
})

root_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
tables_dir <- file.path(root_dir, "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

tex_escape <- function(x) {
  x <- ifelse(is.na(x), "", as.character(x))
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([%&_#$])", "\\\\\\1", x, perl = TRUE)
  x
}

fmt_num <- function(x, digits = 3) {
  ifelse(is.na(x), "", sprintf(paste0("%.", digits, "f"), x))
}

fmt_int <- function(x) {
  ifelse(is.na(x), "", formatC(x, format = "d", big.mark = ","))
}

fmt_p <- function(x) {
  ifelse(
    is.na(x),
    "",
    ifelse(x < 0.001, "<0.001", sprintf("%.3f", x))
  )
}

sig_stars <- function(p) {
  ifelse(
    is.na(p), "",
    ifelse(p < 0.001, "***",
      ifelse(p < 0.01, "**",
        ifelse(p < 0.05, "*",
          ifelse(p < 0.1, "+", "")
        )
      )
    )
  )
}

write_latex_df <- function(df, file, caption, label, align = NULL, notes = NULL) {
  df[] <- lapply(df, function(x) ifelse(is.na(x), "", as.character(x)))
  if (is.null(align)) {
    align <- paste0("l", paste(rep("c", ncol(df) - 1), collapse = ""))
  }

  header <- paste(tex_escape(names(df)), collapse = " & ")
  rows <- apply(df, 1, function(row) paste(tex_escape(row), collapse = " & "))

  lines <- c(
    "\\begin{table}[H]",
    "\\centering",
    paste0("\\caption{", caption, "}"),
    paste0("\\label{", label, "}"),
    "\\footnotesize",
    "\\begin{threeparttable}",
    paste0("\\begin{tabular}{", align, "}"),
    "\\toprule",
    paste0(header, " \\\\"),
    "\\midrule",
    paste0(rows, " \\\\"),
    "\\bottomrule",
    "\\end{tabular}"
  )

  if (!is.null(notes)) {
    lines <- c(
      lines,
      "\\begin{tablenotes}[flushleft]",
      "\\footnotesize",
      paste0("\\item ", notes),
      "\\end{tablenotes}"
    )
  }

  lines <- c(lines, "\\end{threeparttable}", "\\end{table}")
  write_lines(lines, file)
}

write_latex_reg_table <- function(results, file, caption, label, notes,
                                  term_order = NULL, outcome_order = NULL) {
  if (is.null(term_order)) {
    term_order <- unique(results$term)
  }
  if (is.null(outcome_order)) {
    outcome_order <- unique(results$outcome_label)
  }

  lines <- c(
    "\\begin{table}[H]",
    "\\centering",
    paste0("\\caption{", caption, "}"),
    paste0("\\label{", label, "}"),
    "\\footnotesize",
    "\\begin{threeparttable}",
    paste0("\\begin{tabular}{l", paste(rep("c", length(outcome_order)), collapse = ""), "}"),
    "\\toprule",
    paste0(paste(c("", tex_escape(outcome_order)), collapse = " & "), " \\\\"),
    "\\midrule"
  )

  for (term in term_order) {
    sub <- results |> filter(term == !!term)

    coef_cells <- c(
      term,
      sapply(outcome_order, function(outcome_name) {
        row <- sub |> filter(outcome_label == !!outcome_name)
        if (nrow(row) == 0) "" else paste0(fmt_num(row$estimate, 3), sig_stars(row$p.value))
      })
    )

    se_cells <- c(
      "",
      sapply(outcome_order, function(outcome_name) {
        row <- sub |> filter(outcome_label == !!outcome_name)
        if (nrow(row) == 0) "" else paste0("(", fmt_num(row$std.error, 3), ")")
      })
    )

    lines <- c(
      lines,
      paste0(paste(tex_escape(coef_cells), collapse = " & "), " \\\\"),
      paste0(paste(tex_escape(se_cells), collapse = " & "), " \\\\"),
      "\\addlinespace"
    )
  }

  summary_rows <- rbind(
    c(
      "Control mean",
      sapply(outcome_order, function(outcome_name) {
        row <- results |> filter(outcome_label == !!outcome_name) |> slice(1)
        fmt_num(row$control_mean, 3)
      })
    ),
    c(
      "Observations",
      sapply(outcome_order, function(outcome_name) {
        row <- results |> filter(outcome_label == !!outcome_name) |> slice(1)
        fmt_int(row$n)
      })
    ),
    c("Lagged dependent variable", rep("Yes", length(outcome_order))),
    c("Block fixed effects", rep("Yes", length(outcome_order))),
    c("HC2 standard errors", rep("Yes", length(outcome_order)))
  )

  lines <- c(
    lines,
    "\\midrule",
    apply(summary_rows, 1, function(row) paste0(paste(tex_escape(row), collapse = " & "), " \\\\")),
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}[flushleft]",
    "\\footnotesize",
    paste0("\\item ", notes),
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{table}"
  )

  write_lines(lines, file)
}

hc2_vcov <- function(model) {
  sandwich::vcovHC(model, type = "HC2")
}

tidy_hc2 <- function(model) {
  vc <- hc2_vcov(model)
  ct <- lmtest::coeftest(model, vcov. = vc)
  tibble(
    term = rownames(ct),
    estimate = unname(ct[, 1]),
    std.error = unname(ct[, 2]),
    statistic = unname(ct[, 3]),
    p.value = unname(ct[, 4])
  ) |>
    mutate(
      conf.low = estimate - 1.96 * std.error,
      conf.high = estimate + 1.96 * std.error
    )
}

tidy_with_vcov <- function(model, vcov_matrix) {
  ct <- lmtest::coeftest(model, vcov. = vcov_matrix)
  tibble(
    term = rownames(ct),
    estimate = unname(ct[, 1]),
    std.error = unname(ct[, 2]),
    statistic = unname(ct[, 3]),
    p.value = unname(ct[, 4])
  ) |>
    mutate(
      conf.low = estimate - 1.96 * std.error,
      conf.high = estimate + 1.96 * std.error
    )
}

cluster_vcov <- function(model, cluster) {
  sandwich::vcovCL(model, cluster = cluster, type = "HC2")
}

linear_contrast <- function(model, contrast, label, outcome_label, control_mean, n_obs) {
  beta <- coef(model)
  vc <- hc2_vcov(model)
  common <- intersect(names(beta), names(contrast))
  cvec <- rep(0, length(beta))
  names(cvec) <- names(beta)
  cvec[common] <- contrast[common]
  estimate <- sum(cvec * beta)
  std.error <- sqrt(as.numeric(t(cvec) %*% vc %*% cvec))
  statistic <- estimate / std.error
  p.value <- 2 * pnorm(abs(statistic), lower.tail = FALSE)
  tibble(
    outcome_label = outcome_label,
    term = label,
    estimate = estimate,
    std.error = std.error,
    p.value = p.value,
    conf.low = estimate - 1.96 * std.error,
    conf.high = estimate + 1.96 * std.error,
    control_mean = control_mean,
    n = n_obs
  )
}

joint_arm_pvalue <- function(data, outcome) {
  full_mod <- lm(as.formula(paste0(outcome, " ~ arm_label + factor(block_id)")), data = data)
  rest_mod <- lm(as.formula(paste0(outcome, " ~ factor(block_id)")), data = data)
  test <- lmtest::waldtest(full_mod, rest_mod, vcov = hc2_vcov(full_mod), test = "Chisq")
  unname(test$`Pr(>Chisq)`[2])
}

z_from_ref <- function(x, ref) {
  (x - mean(ref, na.rm = TRUE)) / sd(ref, na.rm = TRUE)
}

mode_stat <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA)
  }
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

trim_probabilities <- function(p, lower = 0.05, upper = 0.95) {
  pmin(pmax(p, lower), upper)
}

normalize_weights <- function(w) {
  w / mean(w, na.rm = TRUE)
}

default_weighting_covariates <- function() {
  c(
    "t0_att_pass",
    "t0_straightline_flag",
    "t0_abroad_plan",
    "t0_news_foreign_30d",
    "t0_freq_foreign",
    "t0_trust_foreign",
    "t0_rs_index",
    "t0_nat_index",
    "t0_cen_index",
    "t0_therm_gap",
    "t0_exam_score",
    "t0_female"
  )
}

add_imputed_covariates <- function(data, vars) {
  dat <- data
  terms <- character()

  for (var in vars) {
    miss_name <- paste0(var, "_miss")
    imp_name <- paste0(var, "_imp")
    x <- dat[[var]]

    dat[[miss_name]] <- as.integer(is.na(x))

    if (is.numeric(x) || is.integer(x)) {
      fill_value <- stats::median(x, na.rm = TRUE)
      if (!is.finite(fill_value)) {
        fill_value <- 0
      }
    } else {
      fill_value <- mode_stat(x)
    }

    x[is.na(x)] <- fill_value
    dat[[imp_name]] <- x
    terms <- c(terms, imp_name)

    if (any(dat[[miss_name]] == 1, na.rm = TRUE)) {
      terms <- c(terms, miss_name)
    }
  }

  list(data = dat, terms = terms)
}

build_standardized_index <- function(data, component_map, ref_data = data) {
  component_names <- names(component_map)
  component_signs <- as.numeric(component_map)

  component_matrix <- map2(
    component_names,
    component_signs,
    function(var, sgn) {
      sgn * z_from_ref(data[[var]], ref_data[[var]])
    }
  ) |>
    do.call(what = cbind)

  index <- rowMeans(component_matrix, na.rm = TRUE)
  index[apply(is.na(component_matrix), 1, all)] <- NA_real_
  index
}

build_crosswave_index <- function(data, data_vars, ref_data, ref_vars = data_vars, signs = rep(1, length(data_vars))) {
  component_matrix <- map2(
    seq_along(data_vars),
    signs,
    function(i, sgn) {
      sgn * z_from_ref(data[[data_vars[i]]], ref_data[[ref_vars[i]]])
    }
  ) |>
    do.call(what = cbind)

  index <- rowMeans(component_matrix, na.rm = TRUE)
  index[apply(is.na(component_matrix), 1, all)] <- NA_real_
  index
}

group_mean_difference <- function(data, var, group, label, group1 = 1, group0 = 0) {
  dat <- data |>
    select(all_of(c(var, group))) |>
    filter(!is.na(.data[[var]]), !is.na(.data[[group]]))

  mod <- lm(as.formula(paste0(var, " ~ ", group)), data = dat)
  term_name <- group

  est <- tidy_hc2(mod) |>
    filter(term == term_name) |>
    slice(1)

  tibble(
    variable = label,
    mean_group1 = mean(dat[[var]][dat[[group]] == group1], na.rm = TRUE),
    mean_group0 = mean(dat[[var]][dat[[group]] == group0], na.rm = TRUE),
    diff = est$estimate,
    std.error = est$std.error,
    p.value = est$p.value,
    n = nrow(dat)
  )
}

add_investment_index <- function(data, ref_data = NULL) {
  if (is.null(ref_data)) {
    ref_data <- data
  }

  ref_comply_rate <- ifelse(ref_data$w_n_slots > 0, ref_data$w_n_comply / ref_data$w_n_slots, NA_real_)
  ref_read_per_slot <- ifelse(ref_data$w_n_slots > 0, ref_data$w_sum_read_min / ref_data$w_n_slots, NA_real_)
  ref_vid_per_slot <- ifelse(ref_data$w_n_slots > 0, ref_data$w_sum_vid_min / ref_data$w_n_slots, NA_real_)

  data |>
    mutate(
      comply_rate = if_else(w_n_slots > 0, w_n_comply / w_n_slots, NA_real_),
      read_per_slot = if_else(w_n_slots > 0, w_sum_read_min / w_n_slots, NA_real_),
      vid_per_slot = if_else(w_n_slots > 0, w_sum_vid_min / w_n_slots, NA_real_),
      invest_last_week_z = z_from_ref(last_week_active, ref_data$last_week_active),
      invest_comply_rate_z = z_from_ref(comply_rate, ref_comply_rate),
      invest_read_per_slot_z = z_from_ref(read_per_slot, ref_read_per_slot),
      invest_vid_per_slot_z = z_from_ref(vid_per_slot, ref_vid_per_slot),
      invest_quiz_z = z_from_ref(w_mean_quiz, ref_data$w_mean_quiz),
      investment_z = rowMeans(
        cbind(
          invest_last_week_z,
          invest_comply_rate_z,
          invest_read_per_slot_z,
          invest_vid_per_slot_z,
          invest_quiz_z
        ),
        na.rm = TRUE
      )
    )
}

prepare_participant <- function(include_moderators = FALSE) {
  participant <- read_dta(file.path(root_dir, "data", "participant.dta")) |>
    mutate(
      arm = as.integer(arm),
      block_id = as.integer(block_id),
      recruited = as.integer(recruited),
      complete_endline = as.integer(complete_endline),
      complete_followup = as.integer(complete_followup),
      arm_label = factor(
        arm,
        levels = 1:6,
        labels = c("pro_low", "pro_high", "anti_low", "anti_high", "apol_china", "control")
      ),
      arm_label = relevel(arm_label, ref = "control"),
      pro_any = as.integer(arm %in% c(1L, 2L)),
      anti_any = as.integer(arm %in% c(3L, 4L)),
      apol = as.integer(arm == 5L)
    )

  if (!include_moderators) {
    return(participant)
  }

  participant <- participant |>
    mutate(
      foreign_platform_count = t0_plat_fb + t0_plat_tw + t0_plat_yt + t0_plat_ig
    )

  randomized <- participant |> filter(recruited == 1)

  participant |>
    mutate(
      nat0_z = z_from_ref(t0_nat_index, randomized$t0_nat_index),
      rs0_z = z_from_ref(t0_rs_index, randomized$t0_rs_index),
      foreign_news30_z = z_from_ref(t0_news_foreign_30d, randomized$t0_news_foreign_30d),
      foreign_freq_z = z_from_ref(t0_freq_foreign, randomized$t0_freq_foreign),
      foreign_platform_z = z_from_ref(foreign_platform_count, randomized$foreign_platform_count),
      foreign_exp_index = rowMeans(cbind(foreign_news30_z, foreign_freq_z, foreign_platform_z), na.rm = TRUE),
      foreign_exp_z = z_from_ref(foreign_exp_index, foreign_exp_index[recruited == 1])
    )
}

main_outcome_map <- function() {
  tibble(
    outcome = c("t1_rs_index", "t1_cen_index", "t1_nat_index", "t1_therm_gap", "t1_trust_foreign"),
    baseline = c("t0_rs_index", "t0_cen_index", "t0_nat_index", "t0_therm_gap", "t0_trust_foreign"),
    label = c("Regime support", "Censorship support", "Nationalism", "China-West thermometer gap", "Trust in foreign media")
  )
}

t2_outcome_map <- function() {
  tibble(
    outcome = c("t2_rs_index", "t2_cen_index", "t2_nat_index", "t2_therm_gap", "t2_trust_foreign"),
    baseline = c("t0_rs_index", "t0_cen_index", "t0_nat_index", "t0_therm_gap", "t0_trust_foreign"),
    label = c("Regime support", "Censorship support", "Nationalism", "China-West thermometer gap", "Trust in foreign media")
  )
}

het_outcome_map <- function() {
  tibble(
    outcome = c("t1_rs_index", "t1_cen_index", "t1_nat_index", "t1_trust_foreign"),
    baseline = c("t0_rs_index", "t0_cen_index", "t0_nat_index", "t0_trust_foreign"),
    label = c("Regime support", "Censorship support", "Nationalism", "Trust in foreign media")
  )
}

run_arm_ancova <- function(data, outcome, baseline, label) {
  dat <- data |>
    select(all_of(c(outcome, baseline)), arm_label, block_id) |>
    filter(!is.na(.data[[outcome]]), !is.na(.data[[baseline]]), !is.na(arm_label), !is.na(block_id))
  mod <- lm(as.formula(paste0(outcome, " ~ arm_label + ", baseline, " + factor(block_id)")), data = dat)
  ctrl_mean <- dat |> filter(arm_label == "control") |> summarise(m = mean(.data[[outcome]], na.rm = TRUE)) |> pull(m)
  tidy_hc2(mod) |>
    filter(grepl("^arm_label", term)) |>
    mutate(outcome_label = label, control_mean = ctrl_mean, n = nrow(dat))
}

run_planned_contrasts <- function(data, outcome, baseline, label) {
  dat <- data |>
    select(all_of(c(outcome, baseline)), arm_label, block_id) |>
    filter(!is.na(.data[[outcome]]), !is.na(.data[[baseline]]), !is.na(arm_label), !is.na(block_id))
  mod <- lm(as.formula(paste0(outcome, " ~ arm_label + ", baseline, " + factor(block_id)")), data = dat)
  ctrl_mean <- dat |> filter(arm_label == "control") |> summarise(m = mean(.data[[outcome]], na.rm = TRUE)) |> pull(m)
  bind_rows(
    linear_contrast(mod, c("arm_labelpro_high" = 1, "arm_labelpro_low" = -1), "Pro high - Pro low", label, ctrl_mean, nrow(dat)),
    linear_contrast(mod, c("arm_labelanti_high" = 1, "arm_labelanti_low" = -1), "Anti high - Anti low", label, ctrl_mean, nrow(dat))
  )
}

run_pooled_ancova <- function(data, outcome, baseline, label) {
  dat <- data |>
    select(all_of(c(outcome, baseline)), pro_any, anti_any, apol, block_id, arm_label) |>
    filter(!is.na(.data[[outcome]]), !is.na(.data[[baseline]]), !is.na(block_id))
  mod <- lm(as.formula(paste0(outcome, " ~ pro_any + anti_any + apol + ", baseline, " + factor(block_id)")), data = dat)
  ctrl_mean <- dat |> filter(arm_label == "control") |> summarise(m = mean(.data[[outcome]], na.rm = TRUE)) |> pull(m)
  tidy_hc2(mod) |>
    filter(term %in% c("pro_any", "anti_any", "apol")) |>
    mutate(outcome_label = label, control_mean = ctrl_mean, n = nrow(dat))
}

run_pooled_model <- function(data, outcome, label, controls = NULL, weights = NULL, vcov = c("HC2", "HC3")) {
  vcov <- match.arg(vcov)
  rhs <- c("pro_any", "anti_any", "apol", controls, "factor(block_id)")
  dat <- data |>
    filter(!is.na(.data[[outcome]]), !is.na(arm_label), !is.na(block_id))

  if (!is.null(controls)) {
    for (cc in controls) {
      dat <- dat |> filter(!is.na(.data[[cc]]))
    }
  }

  form <- reformulate(rhs, response = outcome)
  mod <- if (is.null(weights)) {
    lm(form, data = dat)
  } else {
    lm(form, data = dat, weights = weights)
  }

  vc <- sandwich::vcovHC(mod, type = vcov)
  ctrl_mean <- dat |> filter(arm_label == "control") |> summarise(m = mean(.data[[outcome]], na.rm = TRUE)) |> pull(m)

  tidy_with_vcov(mod, vc) |>
    filter(term %in% c("pro_any", "anti_any", "apol")) |>
    mutate(outcome_label = label, control_mean = ctrl_mean, n = nrow(dat))
}

run_het_model <- function(data, outcome, baseline, outcome_label, moderator, mod_label) {
  dat <- data |>
    select(all_of(c(outcome, baseline, moderator)), pro_any, anti_any, apol, block_id, arm) |>
    filter(!is.na(.data[[outcome]]), !is.na(.data[[baseline]]), !is.na(.data[[moderator]]), !is.na(block_id))
  mod <- lm(
    as.formula(
      paste0(
        outcome, " ~ pro_any + anti_any + apol + ", moderator,
        " + pro_any:", moderator,
        " + anti_any:", moderator,
        " + apol:", moderator,
        " + ", baseline,
        " + factor(block_id)"
      )
    ),
    data = dat
  )
  ctrl_mean <- dat |> filter(arm == 6) |> summarise(m = mean(.data[[outcome]], na.rm = TRUE)) |> pull(m)
  tidy_hc2(mod) |>
    filter(term %in% c("pro_any", "anti_any", "apol", moderator, paste0("pro_any:", moderator), paste0("anti_any:", moderator), paste0("apol:", moderator))) |>
    mutate(outcome_label = outcome_label, moderator = moderator, moderator_label = mod_label, control_mean = ctrl_mean, n = nrow(dat))
}
