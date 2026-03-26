#!/usr/bin/env python3

from __future__ import annotations

import csv
import math
import re
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from scipy import stats


PROJECT = Path("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT")
ANALYSIS_BANK = PROJECT / "analysis" / "data" / "materials_master_bank.csv"
TEACHING_BANK = PROJECT / "archive" / "teaching" / "materials_master_bank.csv"
ARTICLE_TEXT = PROJECT / "archive" / "teaching" / "article_texts" / "CTRL_021.txt"
TEXT_BALANCE_DIR = PROJECT / "archive" / "analysis_support" / "text_balance"
CONTENT_VALIDITY_DIR = PROJECT / "archive" / "analysis_support" / "content_validity"
TABLE_DIRS = [PROJECT / "writing" / "tables"]
FIGURE_DIRS = [PROJECT / "writing" / "figures", PROJECT / "analysis" / "output" / "figures"]
OUTPUT_TABLE_DIR = PROJECT / "analysis" / "output" / "tables"

REPLACEMENT_ID = "CTRL_021"
REPLACEMENT_META = {
    "source": "The Economist",
    "title": "The lessons from the brazen heist at the Louvre",
    "url": "https://www.economist.com/culture/2025/10/21/the-lessons-from-the-brazen-heist-at-the-louvre",
    "topic": "museum security and cultural institutions",
    "source_ok": "yes",
    "china_focus_ok": "no",
    "valence_ok": "yes",
    "taboo_screen_ok": "yes",
    "format_ok": "yes",
    "final_status": "screened_blocked_source_rescreen",
    "notes": "Replaced in March 2026 with a blocked-source Economist control article used to document the module-construction workflow.",
}

BANK_ORDER = ["PRO", "ANTI", "APOL_CHINA", "NONCHINA_CONTROL"]
BANK_LABELS = {
    "PRO": "Pro-China",
    "ANTI": "Anti-China",
    "APOL_CHINA": "Apolitical China",
    "NONCHINA_CONTROL": "Non-China control",
}
ARM_LABELS = {
    1: "Pro low",
    2: "Pro high",
    3: "Anti low",
    4: "Anti high",
    5: "Apolitical China",
    6: "Control",
}
METRICS = ["word_count", "avg_sentence_length", "avg_word_length", "flesch_kincaid"]


def parse_article_body(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    marker = "============================================================"
    if marker not in text:
        raise RuntimeError(f"Missing separator in {path}")
    return text.split(marker, 1)[1].strip()


def tokenize(text: str) -> list[str]:
    return re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?", text)


def split_sentences(text: str) -> list[str]:
    squashed = re.sub(r"\s+", " ", text.strip())
    pieces = re.split(r"(?<=[.!?])\s+", squashed)
    return [piece for piece in pieces if re.search(r"[A-Za-z]", piece)]


def syllables(word: str) -> int:
    lowered = re.sub(r"[^a-z]", "", word.lower())
    if not lowered:
        return 0
    groups = re.findall(r"[aeiouy]+", lowered)
    count = len(groups)
    if lowered.endswith("e") and not lowered.endswith(("le", "ye")) and count > 1:
        count -= 1
    if lowered.endswith("le") and len(lowered) > 2 and lowered[-3] not in "aeiouy":
        count += 1
    return max(1, count)


def text_features(text: str) -> dict[str, float]:
    words = tokenize(text)
    sentences = split_sentences(text)
    if not words or not sentences:
        raise RuntimeError("Text must contain at least one word and one sentence.")
    word_count = len(words)
    sentence_count = len(sentences)
    avg_sentence_length = word_count / sentence_count
    avg_word_length = sum(len(word) for word in words) / word_count
    type_token_ratio = len({word.lower() for word in words}) / word_count
    share_long_words = sum(len(word) >= 7 for word in words) / word_count
    syllables_per_word = sum(syllables(word) for word in words) / word_count
    flesch_kincaid = 0.39 * avg_sentence_length + 11.8 * syllables_per_word - 15.59
    return {
        "word_count": float(word_count),
        "sentence_count": float(sentence_count),
        "avg_sentence_length": avg_sentence_length,
        "avg_word_length": avg_word_length,
        "type_token_ratio": type_token_ratio,
        "share_long_words": share_long_words,
        "flesch_kincaid": flesch_kincaid,
    }


def mean_ci(series: pd.Series) -> tuple[float, float, float, float, float]:
    series = series.dropna().astype(float)
    n = len(series)
    mean = series.mean()
    sd = series.std(ddof=1) if n > 1 else 0.0
    se = sd / math.sqrt(n) if n else math.nan
    ci = 1.96 * se if n else math.nan
    return mean, sd, se, mean - ci, mean + ci


def fmt_word(value: float) -> str:
    return f"{int(round(value)):,}"


def fmt_num(value: float) -> str:
    return f"{value:.2f}"


def fmt_p(value: float) -> str:
    if pd.isna(value):
        return "--"
    if value < 0.001:
        return "<0.001"
    return f"{value:.3f}"


def tex_escape(text: str) -> str:
    replacements = {
        "\\": r"\textbackslash{}",
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def update_bank_csv(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    mask = df["id"] == REPLACEMENT_ID
    for key, value in REPLACEMENT_META.items():
        df.loc[mask, key] = value
    df.to_csv(path, index=False)
    return df


def rewrite_article_text(body: str, features: dict[str, float]) -> None:
    lines = [
        f"ID: {REPLACEMENT_ID}",
        "Bank: NONCHINA_CONTROL",
        f"Source: {REPLACEMENT_META['source']}",
        f"Title: {REPLACEMENT_META['title']}",
        f"URL: {REPLACEMENT_META['url']}",
        f"Topic: {REPLACEMENT_META['topic']}",
        "Method: manual_adaptation_for_module_example",
        f"Words: {int(round(features['word_count']))}",
        "Fetched: 2026-03-25T12:00:00",
        "Adapted: 2026-03-25T12:00:00",
        "Adaptation: paraphrased classroom module based on the source article; no verbatim reproduction of copyrighted text",
        "============================================================",
        "",
        body.strip(),
        "",
    ]
    ARTICLE_TEXT.write_text("\n".join(lines), encoding="utf-8")


def refresh_text_balance_support(bank_df: pd.DataFrame, features: dict[str, float]) -> tuple[pd.DataFrame, pd.DataFrame]:
    article_features_path = TEXT_BALANCE_DIR / "article_text_features.csv"
    article_df = pd.read_csv(article_features_path)
    mask = article_df["id"] == REPLACEMENT_ID
    article_df.loc[mask, "source"] = REPLACEMENT_META["source"]
    article_df.loc[mask, "title"] = REPLACEMENT_META["title"]
    article_df.loc[mask, "url"] = REPLACEMENT_META["url"]
    article_df.loc[mask, "topic"] = REPLACEMENT_META["topic"]
    article_df.loc[mask, "notes"] = REPLACEMENT_META["notes"]
    article_df.loc[mask, "text"] = parse_article_body(ARTICLE_TEXT)
    for key, value in features.items():
        article_df.loc[mask, key] = value
    article_df.to_csv(article_features_path, index=False)

    summary_rows = []
    for bank in BANK_ORDER:
        sub = article_df.loc[article_df["bank"] == bank].copy()
        row = {"bank": bank, "n_articles": int(len(sub))}
        for metric in ["word_count", "avg_sentence_length", "avg_word_length", "flesch_kincaid"]:
            mean, sd, se, ci_low, ci_high = mean_ci(sub[metric])
            row[f"{metric}_mean"] = mean
            row[f"{metric}_sd"] = sd
            row[f"{metric}_se"] = se
            row[f"{metric}_ci_low"] = ci_low
            row[f"{metric}_ci_high"] = ci_high
        summary_rows.append(row)
    article_summary = pd.DataFrame(summary_rows)
    article_summary.to_csv(TEXT_BALANCE_DIR / "article_bank_text_balance_summary.csv", index=False)

    article_anova_rows = []
    for metric in METRICS:
        groups = [article_df.loc[article_df["bank"] == bank, metric].astype(float) for bank in BANK_ORDER]
        p_value = stats.f_oneway(*groups).pvalue
        article_anova_rows.append({"metric": metric, "p_value": p_value})
    pd.DataFrame(article_anova_rows).to_csv(TEXT_BALANCE_DIR / "article_bank_text_balance_anova.csv", index=False)

    assignment_path = TEXT_BALANCE_DIR / "simulated_content_assignment_text_balance.csv"
    assignment_df = pd.read_csv(assignment_path)
    mask = assignment_df["article_id"] == REPLACEMENT_ID
    assignment_df.loc[mask, "title"] = REPLACEMENT_META["title"]
    assignment_df.loc[mask, "source"] = REPLACEMENT_META["source"]
    for key in ["word_count", "sentence_count", "avg_sentence_length", "avg_word_length", "type_token_ratio", "share_long_words", "flesch_kincaid"]:
        assignment_df.loc[mask, key] = features[key]
    assignment_df.to_csv(assignment_path, index=False)

    participant_all = (
        assignment_df.groupby(["study_id", "arm"], as_index=False)[
            ["word_count", "avg_sentence_length", "avg_word_length", "type_token_ratio", "share_long_words", "flesch_kincaid"]
        ]
        .mean()
    )
    participant_all["arm_label"] = participant_all["arm"].map(ARM_LABELS)
    participant_all.to_csv(TEXT_BALANCE_DIR / "participant_text_balance_all.csv", index=False)

    participant_slot1 = (
        assignment_df.loc[assignment_df["slot_wk"] == 1]
        .groupby(["study_id", "arm"], as_index=False)[
            ["word_count", "avg_sentence_length", "avg_word_length", "type_token_ratio", "share_long_words", "flesch_kincaid"]
        ]
        .mean()
    )
    participant_slot1["arm_label"] = participant_slot1["arm"].map(ARM_LABELS)
    participant_slot1.to_csv(TEXT_BALANCE_DIR / "participant_text_balance_slot1.csv", index=False)

    for participant_df, out_path in [
        (participant_all, TEXT_BALANCE_DIR / "assigned_arm_text_balance_all.csv"),
        (participant_slot1, TEXT_BALANCE_DIR / "assigned_arm_text_balance_slot1.csv"),
    ]:
        rows = []
        for arm in sorted(ARM_LABELS):
            sub = participant_df.loc[participant_df["arm"] == arm].copy()
            row = {"arm_label": ARM_LABELS[arm], "n_participants": int(len(sub))}
            for metric in ["word_count", "avg_sentence_length", "avg_word_length", "type_token_ratio", "share_long_words", "flesch_kincaid"]:
                mean, sd, se, ci_low, ci_high = mean_ci(sub[metric])
                row[f"{metric}_mean"] = mean
                row[f"{metric}_sd"] = sd
                row[f"{metric}_se"] = se
                row[f"{metric}_ci_low"] = ci_low
                row[f"{metric}_ci_high"] = ci_high
            rows.append(row)
        pd.DataFrame(rows).to_csv(out_path, index=False)

    assigned_anova_rows = []
    for metric in METRICS:
        groups = [participant_all.loc[participant_all["arm"] == arm, metric].astype(float) for arm in sorted(ARM_LABELS)]
        p_value = stats.f_oneway(*groups).pvalue
        assigned_anova_rows.append({"metric": metric, "p_value": p_value})
    pd.DataFrame(assigned_anova_rows).to_csv(TEXT_BALANCE_DIR / "assigned_arm_text_balance_anova.csv", index=False)

    return article_summary, pd.read_csv(TEXT_BALANCE_DIR / "assigned_arm_text_balance_all.csv")


def refresh_content_validity_support(features_text: str) -> None:
    tone_scores_path = CONTENT_VALIDITY_DIR / "article_tone_scores.csv"
    tone_df = pd.read_csv(tone_scores_path)
    mask = tone_df["id"] == REPLACEMENT_ID
    tone_df.loc[mask, "source"] = REPLACEMENT_META["source"]
    tone_df.loc[mask, "title"] = REPLACEMENT_META["title"]
    tone_df.loc[mask, "topic"] = REPLACEMENT_META["topic"]
    tone_df.loc[mask, "text"] = features_text
    tone_df.loc[mask, "china_anchor_sentences"] = 0
    tone_df.loc[mask, "n_positive"] = 0
    tone_df.loc[mask, "n_negative"] = 0
    tone_df.loc[mask, "n_matched"] = 0
    tone_df.loc[mask, "tone_score"] = 0.0
    tone_df.to_csv(tone_scores_path, index=False)

    rows = []
    for bank in BANK_ORDER:
        sub = tone_df.loc[tone_df["bank"] == bank, "tone_score"].astype(float)
        mean, sd, se, ci_low, ci_high = mean_ci(sub)
        rows.append(
            {
                "bank": bank,
                "n_articles": int(len(sub)),
                "mean_tone": mean,
                "sd_tone": sd,
                "se_tone": se,
                "ci_low": ci_low,
                "ci_high": ci_high,
                "bank_label": f"{BANK_LABELS[bank]} (n={len(sub)})",
            }
        )
    pd.DataFrame(rows).to_csv(CONTENT_VALIDITY_DIR / "article_tone_summary.csv", index=False)


def write_material_bank_table(bank_df: pd.DataFrame) -> None:
    pivot = (
        bank_df.assign(bank_label=bank_df["bank"].map(BANK_LABELS))
        .pivot_table(index="source", columns="bank_label", values="id", aggfunc="count", fill_value=0)
        .reset_index()
    )
    for col in ["Pro-China", "Anti-China", "Apolitical China", "Non-China control"]:
        if col not in pivot.columns:
            pivot[col] = 0
    pivot = pivot[["source", "Pro-China", "Anti-China", "Apolitical China", "Non-China control"]]
    pivot["Total"] = pivot[["Pro-China", "Anti-China", "Apolitical China", "Non-China control"]].sum(axis=1)
    pivot = pivot.sort_values("source")

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Composition of the Final Reading-Materials Bank}",
        r"\label{tab:material_bank_summary}",
        r"\footnotesize",
        r"\begin{threeparttable}",
        r"\begin{tabular}{lccccc}",
        r"\toprule",
        r"Source & Pro-China & Anti-China & Apolitical China & Non-China control & Total \\",
        r"\midrule",
    ]
    for _, row in pivot.iterrows():
        lines.append(
            f"{tex_escape(row['source'])} & {int(row['Pro-China'])} & {int(row['Anti-China'])} & "
            f"{int(row['Apolitical China'])} & {int(row['Non-China control'])} & {int(row['Total'])} \\\\"
        )
    totals = bank_df["bank"].value_counts()
    lines += [
        r"\midrule",
        f"Total & {int(totals.get('PRO', 0))} & {int(totals.get('ANTI', 0))} & {int(totals.get('APOL_CHINA', 0))} & {int(totals.get('NONCHINA_CONTROL', 0))} & {len(bank_df)} \\\\",
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{tablenotes}[flushleft]",
        r"\footnotesize",
        r"\item Note: Entries report the composition of the finalized article bank used to build the treatment modules. All sources are outlets censored in mainland China during the study period. The four content pools correspond to the implemented experimental groups.",
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
        "",
    ]
    for table_dir in TABLE_DIRS + [OUTPUT_TABLE_DIR]:
        table_dir.mkdir(parents=True, exist_ok=True)
        (table_dir / "tab_material_bank_summary.tex").write_text("\n".join(lines), encoding="utf-8")


def write_text_balance_table(article_summary: pd.DataFrame, assigned_summary: pd.DataFrame) -> None:
    article_anova = pd.read_csv(TEXT_BALANCE_DIR / "article_bank_text_balance_anova.csv").set_index("metric")["p_value"].to_dict()
    assigned_anova = pd.read_csv(TEXT_BALANCE_DIR / "assigned_arm_text_balance_anova.csv").set_index("metric")["p_value"].to_dict()

    article_summary = article_summary.set_index("bank").loc[BANK_ORDER].reset_index()
    assigned_summary = assigned_summary.set_index("arm_label").loc[list(ARM_LABELS.values())].reset_index()

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\begin{threeparttable}",
        r"\caption{Textual Balance of the Final Reading Materials}",
        r"\label{tab:text_balance}",
        r"\footnotesize",
        r"\begin{tabular}{lccccc}",
        r"\toprule",
        r"Group & $N$ & Word count & Words/sentence & Chars/word & Flesch-Kincaid\\",
        r"\midrule",
        r"\addlinespace[0.3em]",
        r"\multicolumn{6}{l}{\textit{Panel A. Article pools}}\\",
    ]
    for _, row in article_summary.iterrows():
        lines.append(
            f"{BANK_LABELS[row['bank']]} & {int(row['n_articles'])} & {fmt_word(row['word_count_mean'])} & "
            f"{fmt_num(row['avg_sentence_length_mean'])} & {fmt_num(row['avg_word_length_mean'])} & "
            f"{fmt_num(row['flesch_kincaid_mean'])}\\\\"
        )
    lines.append(
        f"ANOVA $p$-value & -- & {fmt_p(article_anova['word_count'])} & {fmt_p(article_anova['avg_sentence_length'])} & "
        f"{fmt_p(article_anova['avg_word_length'])} & {fmt_p(article_anova['flesch_kincaid'])}\\\\"
    )
    lines += [
        r"\addlinespace[0.45em]",
        r"\multicolumn{6}{l}{\textit{Panel B. Average assigned 24-reading bundle by group}}\\",
    ]
    for _, row in assigned_summary.iterrows():
        lines.append(
            f"{row['arm_label']} & {int(row['n_participants'])} & {fmt_word(row['word_count_mean'])} & "
            f"{fmt_num(row['avg_sentence_length_mean'])} & {fmt_num(row['avg_word_length_mean'])} & "
            f"{fmt_num(row['flesch_kincaid_mean'])}\\\\"
        )
    lines += [
        f"ANOVA $p$-value & -- & {fmt_p(assigned_anova['word_count'])} & {fmt_p(assigned_anova['avg_sentence_length'])} & {fmt_p(assigned_anova['avg_word_length'])} & {fmt_p(assigned_anova['flesch_kincaid'])}\\\\",
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{tablenotes}",
        r"\footnotesize",
        r"\item Note: Panel A reports article-level averages by content bank. Panel B reports participant-level averages of the 24 assigned readings using the implemented schedule design and the realized randomized sample. Higher Flesch-Kincaid values indicate more difficult reading material. These diagnostics assess non-substantive textual comparability rather than political valence.",
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
        "",
    ]
    for table_dir in TABLE_DIRS + [OUTPUT_TABLE_DIR]:
        table_dir.mkdir(parents=True, exist_ok=True)
        (table_dir / "tab_text_balance.tex").write_text("\n".join(lines), encoding="utf-8")


def write_article_inventory(bank_df: pd.DataFrame) -> None:
    grouped = []
    for bank in BANK_ORDER:
        grouped.append((BANK_LABELS[bank], bank_df.loc[bank_df["bank"] == bank].sort_values("id")))

    lines = [
        r"\begingroup",
        r"\scriptsize",
        r"\setlength{\LTleft}{0pt}",
        r"\setlength{\LTright}{0pt}",
        r"\begin{longtable}{@{}p{1.5cm}p{2.6cm}p{9.8cm}@{}}",
        r"\caption{Finalized Article Inventory}",
        r"\label{tab:article_inventory}\\",
        r"\toprule",
        r"ID & Source & Original article title \\",
        r"\midrule",
        r"\endfirsthead",
        r"\caption[]{Finalized Article Inventory (continued)}\\",
        r"\toprule",
        r"ID & Source & Original article title \\",
        r"\midrule",
        r"\endhead",
        r"\bottomrule",
        r"\endfoot",
    ]
    for label, sub in grouped:
        lines.append(rf"\multicolumn{{3}}{{l}}{{\textit{{{tex_escape(label)}}}}}\\")
        for _, row in sub.iterrows():
            lines.append(
                f"{row['id'].replace('_', r'\_')} & {tex_escape(row['source'])} & {tex_escape(row['title'])} \\\\"
            )
        lines.append(r"\addlinespace")
    if lines[-1] == r"\addlinespace":
        lines.pop()
    lines += [r"\end{longtable}", r"\endgroup", ""]
    for table_dir in TABLE_DIRS + [OUTPUT_TABLE_DIR]:
        table_dir.mkdir(parents=True, exist_ok=True)
        (table_dir / "tab_article_inventory.tex").write_text("\n".join(lines), encoding="utf-8")


def plot_text_balance(article_summary: pd.DataFrame, assigned_summary: pd.DataFrame) -> None:
    plt.rcParams.update({"font.size": 10})

    bank_plot = article_summary.set_index("bank").loc[BANK_ORDER].reset_index()
    fig, axes = plt.subplots(1, 2, figsize=(10, 4.2))
    x = range(len(bank_plot))
    axes[0].bar(x, bank_plot["word_count_mean"], color="#8a9a5b")
    axes[0].set_xticks(list(x), [BANK_LABELS[b] for b in bank_plot["bank"]], rotation=20, ha="right")
    axes[0].set_ylabel("Mean word count")
    axes[0].set_title("Article-pool length")
    axes[1].bar(x, bank_plot["flesch_kincaid_mean"], color="#3f6c8a")
    axes[1].set_xticks(list(x), [BANK_LABELS[b] for b in bank_plot["bank"]], rotation=20, ha="right")
    axes[1].set_ylabel("Flesch-Kincaid grade")
    axes[1].set_title("Article-pool readability")
    fig.tight_layout()
    for figure_dir in FIGURE_DIRS:
        figure_dir.mkdir(parents=True, exist_ok=True)
        fig.savefig(figure_dir / "fig_text_balance_article_bank.pdf")
    plt.close(fig)

    arm_plot = assigned_summary.set_index("arm_label").loc[list(ARM_LABELS.values())].reset_index()
    fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.2))
    x = range(len(arm_plot))
    axes[0].bar(x, arm_plot["word_count_mean"], color="#8a9a5b")
    axes[0].set_xticks(list(x), arm_plot["arm_label"], rotation=20, ha="right")
    axes[0].set_ylabel("Mean word count")
    axes[0].set_title("Assigned 24-reading bundle length")
    axes[1].bar(x, arm_plot["flesch_kincaid_mean"], color="#3f6c8a")
    axes[1].set_xticks(list(x), arm_plot["arm_label"], rotation=20, ha="right")
    axes[1].set_ylabel("Flesch-Kincaid grade")
    axes[1].set_title("Assigned 24-reading bundle readability")
    fig.tight_layout()
    for figure_dir in FIGURE_DIRS:
        figure_dir.mkdir(parents=True, exist_ok=True)
        fig.savefig(figure_dir / "fig_text_balance_assigned_arms.pdf")
    plt.close(fig)


def main() -> None:
    body = parse_article_body(ARTICLE_TEXT)
    features = text_features(body)
    rewrite_article_text(body, features)

    analysis_bank = update_bank_csv(ANALYSIS_BANK)
    update_bank_csv(TEACHING_BANK)

    article_summary, assigned_summary = refresh_text_balance_support(analysis_bank, features)
    refresh_content_validity_support(body)
    write_material_bank_table(analysis_bank)
    write_text_balance_table(article_summary, assigned_summary)
    write_article_inventory(analysis_bank)
    plot_text_balance(article_summary, assigned_summary)

    print("Updated control article metadata and refreshed materials diagnostics.")
    print(f"Replacement features: {features}")


if __name__ == "__main__":
    main()
