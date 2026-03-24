#!/usr/bin/env python3

from __future__ import annotations

import csv
import re
from pathlib import Path


PROJECT = Path("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT")
ANALYSIS = PROJECT / "analysis"
TEACHING = PROJECT / "teaching"
TEXTS = TEACHING / "article_texts"
CLEANED = ANALYSIS / "output" / "article_audit" / "cleaned_texts"
AUDIT_CSV = ANALYSIS / "output" / "article_audit" / "article_bank_audit.csv"
BANK_CSV = TEACHING / "materials_master_bank.csv"
TMPDIR = TEACHING / "_article_texts_tmp"

KEEP_DECISIONS = {"keep", "salvage_with_trim"}


def strip_markdown(text: str) -> str:
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = text.replace("**", "").replace("__", "")
    text = text.replace("*", "")
    return text.strip()


def is_noise_line(line: str) -> bool:
    lowered = line.lower().strip()
    if not lowered:
        return False

    exact = {
        "more like this:",
        "watch on",
        "read more",
        "share",
        "save",
        "image",
        "location",
        "website",
        "green space" if False else None,
    }
    exact = {x for x in exact if x is not None}
    if lowered in exact:
        return True

    patterns = [
        r"^view image in fullscreen$",
        r"^advertisement\s*:?\s*\d*\s*sec?$",
        r"^join more than three million bbc.*$",
        r"^if you liked this story.*$",
        r"^bbc\.com'?s?\s+world'?s table.*$",
        r"^the essential list.*$",
        r"^by [a-z].+$",
        r"^serves \d+.*$",
        r"^step \d+\s*$",
        r"^ingredients$",
        r"^method$",
        r"^directions$",
        r"^things to see and do:.*$",
        r"^a local[’']?s travel guide to .+$",
        r"^.+ - (travel correspondent|museums correspondent|freelance writer)\s*$",
        r"^:?focal\(.+$",
        r"^/ .+$",
        r"^[•\-]\s+.+$",
        r"^[A-Z][a-z]{2,8}\.? \d{1,2}, \d{4}$",
    ]
    for pat in patterns:
        if re.match(pat, lowered, flags=re.I):
            return True
    if "jump to recipe" in lowered:
        return True

    if re.search(r"(alamy|getty|ap photo|reuters|xinhua|imaginechina|afp)", lowered):
        return True
    if "photograph:" in lowered:
        return True
    if ":// " in lowered or "http://" in lowered or "https://" in lowered:
        return True
    return False


def clean_body(body: str) -> str:
    lines = [strip_markdown(x) for x in body.splitlines()]
    kept: list[str] = []
    for line in lines:
        line = re.sub(r"\s+", " ", line).strip()
        if not line:
            if kept and kept[-1] != "":
                kept.append("")
            continue
        if is_noise_line(line):
            continue
        kept.append(line)

    # Trim noisy tail lines that are short, name-like, or caption-like.
    while kept:
        tail = kept[-1].strip()
        lowered = tail.lower()
        if tail == "":
            kept.pop()
            continue
        if re.search(r"(alamy|getty|ap photo|reuters|xinhua|imaginechina|afp)", lowered):
            kept.pop()
            continue
        if re.match(r"^[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3}$", tail) and len(tail.split()) <= 4:
            kept.pop()
            continue
        if tail.lower().endswith(" recipe"):
            kept.pop()
            continue
        if len(tail.split()) <= 6 and not re.search(r"[.!?]['”\"]?$", tail):
            kept.pop()
            continue
        break

    text = "\n".join(kept)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return text


def parse_cleaned(path: Path) -> tuple[dict[str, str], str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    header: dict[str, str] = {}
    body_start = 0
    for i, line in enumerate(lines):
        if line.startswith("===="):
            body_start = i + 1
            break
        if ":" in line:
            key, value = line.split(":", 1)
            header[key.strip()] = value.strip()
    body = "\n".join(lines[body_start:]).strip()
    return header, body


def suspicious_title(text: str) -> bool:
    lowered = text.lower().strip()
    return (
        not lowered or
        lowered.startswith("publication date:") or
        lowered.startswith("source file:") or
        "http://" in lowered or
        "https://" in lowered or
        len(lowered.split()) < 3
    )


def suspicious_source(text: str) -> bool:
    lowered = text.lower().strip()
    return not lowered or lowered.startswith("publication date:")


def main() -> None:
    with open(AUDIT_CSV, encoding="utf-8") as f:
        audit_rows = list(csv.DictReader(f))
    with open(BANK_CSV, encoding="utf-8-sig") as f:
        bank_rows = {row["id"]: row for row in csv.DictReader(f)}

    keep_ids = {row["id"] for row in audit_rows if row["decision"] in KEEP_DECISIONS}
    if TMPDIR.exists():
        for path in sorted(TMPDIR.rglob("*"), reverse=True):
            if path.is_file():
                path.unlink()
            elif path.is_dir():
                path.rmdir()
    TMPDIR.mkdir(parents=True, exist_ok=True)

    written = 0
    for row in audit_rows:
        article_id = row["id"]
        if article_id not in keep_ids:
            continue
        cleaned_path = CLEANED / f"{article_id}.cleaned.txt"
        if not cleaned_path.exists():
            continue
        header, body = parse_cleaned(cleaned_path)
        final_body = clean_body(body)
        if not final_body:
            continue
        bank_row = bank_rows.get(article_id, {})
        title = strip_markdown(header.get("Title", row["title"]))
        source = strip_markdown(header.get("Source", row["source"]))
        if suspicious_title(title):
            title = bank_row.get("title", row["title"])
        if suspicious_source(source):
            source = bank_row.get("source", row["source"])
        pub_date = header.get("Publication date", row.get("pub_date", "UNKNOWN")).strip() or "UNKNOWN"
        bank = header.get("Bank", row["bank"])

        final_text = "\n".join(
            [
                f"ID: {article_id}",
                f"Bank: {bank}",
                f"Source: {source}",
                f"Title: {title}",
                f"Publication date: {pub_date}",
                "",
                final_body,
                "",
            ]
        )
        (TMPDIR / f"{article_id}.txt").write_text(final_text, encoding="utf-8")
        written += 1

    expected = len(keep_ids)
    if written < expected:
        raise RuntimeError(f"Only wrote {written} of {expected} expected canonical txt files; aborting replacement.")

    # Remove all old article source files except the manifest. We rebuild the canonical folder from scratch.
    for path in TEXTS.iterdir():
        if path.name == "_manifest.json" or path.name.startswith("."):
            continue
        if path.is_dir():
            for child in sorted(path.rglob("*"), reverse=True):
                if child.is_file():
                    child.unlink()
                elif child.is_dir():
                    child.rmdir()
            path.rmdir()
            continue
        path.unlink()

    for path in TMPDIR.iterdir():
        path.replace(TEXTS / path.name)
    TMPDIR.rmdir()

    print(f"Wrote {written} canonical txt files to {TEXTS}")


if __name__ == "__main__":
    main()
