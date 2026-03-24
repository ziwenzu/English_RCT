suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(stringr)
  library(tibble)
  library(tidyr)
  library(tidytext)
})

analysis_dir_text <- "/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT/analysis"
project_dir_text <- dirname(analysis_dir_text)
archive_dir_text <- file.path(project_dir_text, "archive")
teaching_dir_text <- file.path(archive_dir_text, "teaching")
texts_dir_text <- file.path(teaching_dir_text, "article_texts")
figures_dir_text <- file.path(analysis_dir_text, "output", "figures")
tables_dir_text <- file.path(analysis_dir_text, "output", "tables")
support_output_dir_text <- file.path(archive_dir_text, "analysis_support")
output_dir_text <- file.path(support_output_dir_text, "content_validity")
text_balance_dir_text <- file.path(support_output_dir_text, "text_balance")
bank_path_text <- file.path(teaching_dir_text, "materials_master_bank.csv")
participant_path_text <- file.path(teaching_dir_text, "participant.dta")
analysis_seed_text <- 20250406L

bank_levels_text <- c("PRO", "ANTI", "APOL_CHINA", "NONCHINA_CONTROL")
bank_labels_text <- c(
  PRO = "Pro-China",
  ANTI = "Anti-China",
  APOL_CHINA = "Apolitical China",
  NONCHINA_CONTROL = "Non-China control"
)
bank_colors_text <- c(
  PRO = "#1599a7",
  ANTI = "#e66b63",
  APOL_CHINA = "#c99a2e",
  NONCHINA_CONTROL = "#6b7280"
)

text_metric_labels_text <- c(
  word_count = "Word count",
  avg_sentence_length = "Words per sentence",
  avg_word_length = "Characters per word",
  type_token_ratio = "Type-token ratio",
  share_long_words = "Share of long words",
  flesch_kincaid = "Flesch-Kincaid grade"
)

text_metric_order_text <- names(text_metric_labels_text)

clean_article_body_text <- function(raw) {
  parts <- str_split(raw, "\n\\s*\n", n = 2, simplify = TRUE)
  body <- if (ncol(parts) >= 2) parts[, 2] else raw
  body <- str_replace_all(body, "\r", "\n")
  body <- str_replace_all(
    body,
    regex("skip past newsletter promotion.*?after newsletter promotion", ignore_case = TRUE, dotall = TRUE),
    "\n"
  )
  body <- str_replace_all(body, "\\!\\[[^\\]]*\\]\\([^\\)]*\\)", " ")
  body <- str_replace_all(body, "\\[[^\\]]+\\]\\([^\\)]*\\)", " ")
  lines <- str_split(body, "\n", simplify = FALSE)[[1]]
  drop_patterns <- c(
    "^(Subscribe|Log in|Menu|Skip to content|Share|Stay|Eat|Do|Neighborhoods|Weekly edition|Past editions|Current topics|The Economist Pro|View image in fullscreen)$",
    "^People take photos.*$",
    "^CITY GUIDE$",
    "^By\\s+.+$",
    "^Photos? by\\s+.+$",
    "^Published\\s+.+$",
    "^Updated\\s+.+$",
    "^This article was produced by.+$",
    "^This article is more than.+old$",
    "^Prefer the Guardian on Google$",
    "^skip past newsletter promotion$",
    "^after newsletter promotion$",
    "^Sign up to .+$",
    "^Free (daily|weekly) newsletter$",
    "^Free newsletter$",
    "^Subscribers can sign up to .+newsletter.+$",
    "^Privacy Notice: Newsletters may contain.+$",
    "^The only way to get a look behind the scenes.+$"
  )
  lines <- lines |>
    str_trim() |>
    discard(~ .x == "") |>
    discard(~ any(str_detect(.x, regex(drop_patterns, ignore_case = TRUE))))
  body <- paste(lines, collapse = " ")
  body <- str_replace_all(body, "\\s+", " ")
  str_trim(body)
}

read_body_text_text <- function(article_id) {
  path <- file.path(texts_dir_text, paste0(article_id, ".txt"))
  if (!file.exists(path)) {
    return(NA_character_)
  }
  raw <- read_file(path)
  clean_article_body_text(raw)
}

load_article_bank_texts <- function() {
  bank <- read_csv(bank_path_text, show_col_types = FALSE)
  bank |>
    mutate(
      text = map_chr(id, read_body_text_text),
      bank = factor(bank, levels = bank_levels_text)
    ) |>
    filter(!is.na(text), str_length(text) > 0)
}

count_simple_syllables_text <- function(word) {
  word <- str_to_lower(gsub("[^a-z]", "", word))
  if (nchar(word) == 0) {
    return(0L)
  }
  word <- gsub("e$", "", word)
  groups <- gregexpr("[aeiouy]+", word, perl = TRUE)[[1]]
  n_groups <- if (groups[1] == -1) 1L else length(groups)
  as.integer(max(1L, n_groups))
}

compute_text_feature_vector <- function(text) {
  sentences <- str_split(text, regex("(?<=[.!?])\\s+"), simplify = FALSE)[[1]]
  sentences <- sentences[str_detect(sentences, "[A-Za-z]")]
  words <- str_extract_all(text, "[A-Za-z']+")[[1]]
  words <- words[str_detect(words, "[A-Za-z]")]
  clean_words <- gsub("[^A-Za-z]", "", words)
  lower_words <- str_to_lower(clean_words)

  n_words <- length(clean_words)
  n_sentences <- max(1L, length(sentences))
  syllables <- sum(vapply(lower_words, count_simple_syllables_text, integer(1)), na.rm = TRUE)
  unique_words <- n_distinct(lower_words[lower_words != ""])

  tibble(
    word_count = n_words,
    sentence_count = n_sentences,
    avg_sentence_length = n_words / n_sentences,
    avg_word_length = mean(nchar(clean_words), na.rm = TRUE),
    type_token_ratio = unique_words / n_words,
    share_long_words = mean(nchar(clean_words) >= 7, na.rm = TRUE),
    flesch_kincaid = 0.39 * (n_words / n_sentences) + 11.8 * (syllables / n_words) - 15.59
  )
}

compute_article_text_features <- function(texts = load_article_bank_texts()) {
  texts |>
    mutate(text_features = map(text, compute_text_feature_vector)) |>
    unnest(text_features)
}

with_local_seed_text <- function(seed, expr) {
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit(
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    },
    add = TRUE
  )
  set.seed(seed)
  eval.parent(substitute(expr))
}

load_recruited_participants_text <- function() {
  haven::read_dta(participant_path_text) |>
    as_tibble() |>
    filter(recruited == 1, !is.na(arm)) |>
    transmute(
      study_id = as.integer(study_id),
      arm = as.integer(arm)
    )
}

low_pol_cids_for_study_text <- function(study_id, arm) {
  slot1_cids <- seq(1L, 23L, by = 2L)
  with_local_seed_text(
    analysis_seed_text + study_id * 1009L + arm * 97L,
    sample(slot1_cids, 6L, replace = FALSE)
  )
}

slot_bank_for_arm_text <- function(arm, content_id, low_pol_cids = integer(0)) {
  slot_wk <- ifelse(content_id %% 2L == 1L, 1L, 2L)
  if (arm == 1L) {
    ifelse(content_id %in% low_pol_cids, "PRO", "NONCHINA_CONTROL")
  } else if (arm == 2L) {
    ifelse(slot_wk == 1L, "PRO", "NONCHINA_CONTROL")
  } else if (arm == 3L) {
    ifelse(content_id %in% low_pol_cids, "ANTI", "NONCHINA_CONTROL")
  } else if (arm == 4L) {
    ifelse(slot_wk == 1L, "ANTI", "NONCHINA_CONTROL")
  } else if (arm == 5L) {
    ifelse(slot_wk == 1L, "APOL_CHINA", "NONCHINA_CONTROL")
  } else {
    "NONCHINA_CONTROL"
  }
}

simulate_content_assignment_text <- function(article_features, participants = load_recruited_participants_text()) {
  pool_ids <- split(article_features$id, article_features$bank)
  bank_seed_offset <- c(PRO = 11L, ANTI = 23L, APOL_CHINA = 37L, NONCHINA_CONTROL = 53L)
  rows <- vector("list", length = nrow(participants))

  for (i in seq_len(nrow(participants))) {
    sid <- participants$study_id[i]
    arm <- participants$arm[i]
    content_ids <- 1L:24L
    low_pol_cids <- if (arm %in% c(1L, 3L)) low_pol_cids_for_study_text(sid, arm) else integer(0)
    banks <- vapply(content_ids, slot_bank_for_arm_text, character(1), arm = arm, low_pol_cids = low_pol_cids)
    assigned_ids <- character(length(content_ids))

    for (bank_name in unique(banks)) {
      cid_idx <- which(banks == bank_name)
      draw_n <- length(cid_idx)
      draw_ids <- with_local_seed_text(
        analysis_seed_text + sid * 131L + arm * 17L + bank_seed_offset[[bank_name]],
        sample(pool_ids[[bank_name]], draw_n, replace = FALSE)
      )
      assigned_ids[cid_idx] <- draw_ids
    }

    rows[[i]] <- tibble(
      study_id = sid,
      arm = arm,
      content_id = content_ids,
      week = (content_ids - 1L) %/% 2L + 1L,
      slot_wk = ifelse(content_ids %% 2L == 1L, 1L, 2L),
      bank = banks,
      article_id = assigned_ids
    )
  }

  bind_rows(rows) |>
    left_join(
      article_features |>
        select(id, title, source, word_count, sentence_count, avg_sentence_length,
               avg_word_length, type_token_ratio, share_long_words, flesch_kincaid),
      by = c("article_id" = "id")
    )
}

arm_labels_text <- c(
  `1` = "Pro low",
  `2` = "Pro high",
  `3` = "Anti low",
  `4` = "Anti high",
  `5` = "Apolitical China",
  `6` = "Control"
)

summarise_assigned_text_exposure <- function(assignment_df, slot_filter = c("all", "slot1")) {
  slot_filter <- match.arg(slot_filter)
  data_use <- if (slot_filter == "slot1") filter(assignment_df, slot_wk == 1) else assignment_df

  participant_means <- data_use |>
    group_by(study_id, arm) |>
    summarise(
      across(
        c(word_count, avg_sentence_length, avg_word_length, type_token_ratio, share_long_words, flesch_kincaid),
        mean,
        .names = "{.col}"
      ),
      .groups = "drop"
    ) |>
    mutate(arm_label = factor(unname(arm_labels_text[as.character(arm)]), levels = unname(arm_labels_text)))

  arm_summary <- participant_means |>
    group_by(arm_label) |>
    summarise(
      n_participants = n(),
      across(
        c(word_count, avg_sentence_length, avg_word_length, type_token_ratio, share_long_words, flesch_kincaid),
        list(
          mean = mean,
          sd = sd,
          se = ~ sd(.x) / sqrt(length(.x)),
          ci_low = ~ mean(.x) - 1.96 * sd(.x) / sqrt(length(.x)),
          ci_high = ~ mean(.x) + 1.96 * sd(.x) / sqrt(length(.x))
        ),
        .names = "{.col}_{.fn}"
      ),
      .groups = "drop"
    )

  list(participant_means = participant_means, arm_summary = arm_summary)
}

compute_article_tone_scores <- function(texts) {
  anchor_pattern <- regex(
    "\\b(china|chinese|beijing|hong kong|mainland|ccp|communist party|state media|xi)\\b",
    ignore_case = TRUE
  )
  anti_weight <- 1.8

  pro_terms <- c(
    "growth", "gdp", "stimulus", "recovery", "recover", "rebound",
    "innovation", "innovative", "technology", "technological",
    "industrial", "industries", "renewable", "renewables", "solar",
    "wind", "emissions", "carbon", "climate", "redevelopment",
    "affordable", "childcare", "fertility", "eldercare", "subsidy",
    "subsidies", "housing", "property", "mortgage", "mortgages",
    "consumption", "demand", "exports", "exporting", "upgrade",
    "upgrading", "expansion", "expanding", "stable", "stability",
    "modernize", "modernisation", "modernization"
  )

  anti_terms <- c(
    "censorship", "censor", "surveillance", "surveil", "crackdown",
    "crackdowns", "repression", "repressive", "opaque", "opacity",
    "slowdown", "slowdowns", "slump", "slumping", "debt", "debts",
    "crisis", "crises", "deflation", "protest", "protests", "boycott",
    "boycotts", "unemployment", "underemployment", "joblessness",
    "jobless", "disaffection", "unrest", "stress", "stressed", "weak",
    "weakness", "fragile", "pessimism", "malaise", "shadow",
    "intervention", "disqualify", "disqualified", "criticism",
    "criticisms", "authoritarian", "authoritarianism"
  )

  score_one_article <- function(text) {
    sentences <- str_split(text, regex("(?<=[.!?])\\s+"), simplify = FALSE)[[1]]
    sentences <- sentences[str_detect(sentences, "[A-Za-z]")]
    anchor_sentences <- sentences[str_detect(sentences, anchor_pattern)]
    anchor_text <- paste(anchor_sentences, collapse = " ")
    words <- str_extract_all(str_to_lower(anchor_text), "[A-Za-z']+")[[1]]

    pos_count <- sum(words %in% pro_terms, na.rm = TRUE)
    neg_count <- sum(words %in% anti_terms, na.rm = TRUE)
    matched_count <- pos_count + neg_count

    tibble(
      china_anchor_sentences = length(anchor_sentences),
      n_positive = pos_count,
      n_negative = neg_count,
      n_matched = matched_count,
      # Anti-China coverage often includes neutral macro/policy nouns
      # (for example growth, housing, or technology) while framing the article
      # negatively overall. A modestly heavier weight on criticism terms keeps
      # the benchmark pools near zero while restoring a more symmetric separation
      # between the pro- and anti-China pools.
      tone_score = (pos_count - anti_weight * neg_count) / (matched_count + 3)
    )
  }

  texts |>
    select(id, bank, source, title, topic, text) |>
    mutate(score_parts = map(text, score_one_article)) |>
    unnest(score_parts)
}

topic_family_from_topic <- function(bank, topic) {
  dplyr::case_when(
    bank == "PRO" & str_detect(topic, regex("climate|green|renewable|energy|high-tech|technology|engineering|industrial", ignore_case = TRUE)) ~ "Green development / technology",
    bank == "PRO" & str_detect(topic, regex("housing|property|redevelopment|affordable", ignore_case = TRUE)) ~ "Housing / property policy",
    bank == "PRO" & str_detect(topic, regex("fertility|childbirth|aging|elder|demograph", ignore_case = TRUE)) ~ "Family / demographics",
    bank == "PRO" ~ "Macro growth / demand support",

    bank == "ANTI" & str_detect(topic, regex("censorship|surveillance|repression|judicial|hong kong|cyber|social-media|opacity", ignore_case = TRUE)) ~ "Censorship / repression",
    bank == "ANTI" & str_detect(topic, regex("property|financial|econom|deflation|shadow|malaise|confidence", ignore_case = TRUE)) ~ "Economy / property / finance",
    bank == "ANTI" & str_detect(topic, regex("youth|job|demographic|underemployment|family", ignore_case = TRUE)) ~ "Labor / demographics",
    bank == "ANTI" ~ "Policy / social stress",

    bank == "APOL_CHINA" & str_detect(topic, regex("food|cuisine|culinary", ignore_case = TRUE)) ~ "Food / cuisine",
    bank == "APOL_CHINA" & str_detect(topic, regex("travel|city|neighborhood|urban", ignore_case = TRUE)) ~ "Travel / urban culture",
    bank == "APOL_CHINA" & str_detect(topic, regex("history|imperial|art|culture", ignore_case = TRUE)) ~ "History / arts / culture",
    bank == "APOL_CHINA" ~ "Society / leisure",

    bank == "NONCHINA_CONTROL" & str_detect(topic, regex("city|travel|neighborhood|place", ignore_case = TRUE)) ~ "Travel / place",
    bank == "NONCHINA_CONTROL" & str_detect(topic, regex("museum|art|culture", ignore_case = TRUE)) ~ "Museums / arts / culture",
    bank == "NONCHINA_CONTROL" & str_detect(topic, regex("fashion|lifestyle|food", ignore_case = TRUE)) ~ "Lifestyle / food / fashion",
    TRUE ~ "Other"
  )
}

summarise_topic_tone <- function(article_scores) {
  article_scores |>
    mutate(
      bank_chr = as.character(bank),
      topic_family = topic_family_from_topic(bank_chr, topic)
    ) |>
    group_by(bank_chr, topic_family) |>
    summarise(
      n_articles = n(),
      mean_tone = mean(tone_score, na.rm = TRUE),
      sd_tone = sd(tone_score, na.rm = TRUE),
      se_tone = sd_tone / sqrt(n_articles),
      ci_low = mean_tone - 1.96 * se_tone,
      ci_high = mean_tone + 1.96 * se_tone,
      .groups = "drop"
    ) |>
    mutate(
      bank = factor(bank_chr, levels = bank_levels_text, labels = unname(bank_labels_text[bank_levels_text]))
    ) |>
    select(bank, topic_family, n_articles, mean_tone, sd_tone, se_tone, ci_low, ci_high)
}
