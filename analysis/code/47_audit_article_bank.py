#!/usr/bin/env python3

from __future__ import annotations

import csv
import json
import re
import subprocess
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path


PROJECT = Path("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT")
TEACHING = PROJECT / "teaching"
ANALYSIS = PROJECT / "analysis"
TEXTS = TEACHING / "article_texts"
OUTDIR = ANALYSIS / "output" / "article_audit"
OUTDIR.mkdir(parents=True, exist_ok=True)
ASSIGNMENT_CSV = OUTDIR / "source_assignments.csv"

BANK_PATH = TEACHING / "materials_master_bank.csv"
MANIFEST_PATH = TEXTS / "_manifest.json"

TODAY = date(2026, 3, 23)
MIN_DATE = date(2016, 3, 23)
MAX_DATE = date(2025, 5, 31)

# Classroom screening targets.
MIN_WORDS = 450
PREFERRED_MIN_WORDS = 600
PREFERRED_MAX_WORDS = 1500
MAX_WORDS = 2000
MIN_SENTENCES = 12
MAX_NOISE_SHARE = 0.35
SALVAGE_NOISE_SHARE = 0.70
MIN_INFO_DENSITY = 0.55


NOISE_LINE_PATTERNS = [
    r"^\s*subscribe\s*$",
    r"^\s*log in\s*$",
    r"^\s*menu\s*$",
    r"^\s*skip to content\s*$",
    r"^\s*share\s*$",
    r"^\s*stay\s*$",
    r"^\s*eat\s*$",
    r"^\s*do\s*$",
    r"^\s*neighborhoods\s*$",
    r"^\s*photos by .+$",
    r"^\s*bytheway@washpost\.com\s*$",
    r"^\s*want to get in touch\?\s*$",
    r"^\s*read more about .+$",
    r"^\s*meet .+$",
    r"^\s*city guide\s*$",
    r"^\s*find this neighborhood\.?\s*$",
    r"^\s*in the action\s*$",
    r"^\s*low-key\s*$",
    r"^\s*the world in brief\s*$",
    r"^\s*weekly edition\s*$",
    r"^\s*current topics\s*$",
    r"^\s*podcasts\s*$",
    r"^\s*video\s*$",
    r"^\s*newsletters\s*$",
    r"^\s*our a-to-zs\s*$",
    r"^\s*purchase licensing.*$",
    r"^\s*opens new tab.*$",
    r"^\s*sign up here\.?\s*$",
    r"^\s*sign up\s*$",
    r"^\s*here\.?\s*$",
    r"^\s*our standards\.?\s*$",
    r"^\s*location\s*$",
    r"^\s*website\s*$",
    r"^\s*email this link\s*$",
    r"^\s*share on facebook\s*$",
    r"^\s*share on twitter\s*$",
    r"^\s*add to your saved stories\s*$",
    r"^\s*view on google maps\s*$",
    r"^\s*follow\s+\w.+$",
    r"^\s*by\s+.+$",
    r"^\s*[a-z0-9_]{4,20}\s*$",
    r"^\s*\[?\d+/\d+\]?\s*$",
    r"^\s*more than\s+\d+\s+years?\s+ago\s*$",
    r"^\s*\d+\s*$",
    r"^\s*[A-Z][a-z]+\s+\d{1,2},\s+\d{4}\s*$",
    r"^\s*this week\s*$",
    r"^\s*past editions\s*$",
    r"^\s*manage account\s*$",
    r"^\s*gift subscriptions\s*$",
    r"^\s*log out\s*$",
    r"^\s*subscribe to the economist\s*$",
    r"^\s*the economist pro\s*$",
    r"^\s*world in brief\s*$",
    r"^\s*world this week\s*$",
    r"^\s*finance & economics\s*$",
    r"^\s*business & economics\s*$",
    r"^\s*science & technology\s*$",
    r"^\s*culture, history & society\s*$",
    r"^\s*graphic detail\s*$",
    r"^\s*special reports\s*$",
    r"^\s*technology quarterly\s*$",
    r"^\s*schools brief\s*$",
    r"^\s*cartoons & games\s*$",
    r"^\s*letters to the editor\s*$",
    r"^\s*big mac index\s*$",
    r"^\s*economic & financial indicators\s*$",
    r"^\s*already have an account\??\s*log in\s*$",
    r"^\s*continue with a free trial\s*$",
    r"^\s*free trial\s*$",
    r"^\s*create account\s*$",
    r"^\s*or create a free account to unlock just this article\s*$",
    r"^\s*get full access to our independent journalism for free\s*$",
    r"^\s*share full article\s*$",
    r"^\s*advertisement\s*$",
    r"^\s*advertisement\s*:\s*\d+\s*sec\s*$",
    r"^\s*image\s*$",
    r"^\s*editors.? picks\s*$",
    r"^\s*view image in fullscreen\s*$",
    r"^\s*watch on\s*$",
    r"^\s*read more\s*$",
    r"^\s*things to see and do:.*$",
    r"^\s*join more than three million bbc.*$",
    r"^\s*if you liked this story.*$",
    r"^\s*the essential list.*$",
    r"^\s*bbc\.com'?s?\s+world'?s table.*$",
    r"^\s*/\s+.+$",
    r"^\s*-\s+[A-Z].+$",
    r"^\s*.+\s-\s+(travel correspondent|museums correspondent|freelance writer)\s*$",
    r"^\s*:focal\(.+$",
    r"^\s*serves\s+\d+.*$",
    r"^\s*get our newsletter!?\s*$",
    r"^\s*prefer the guardian on google\s*$",
    r"^\s*this article is more than \d+ years? old\s*$",
    r"^\s*reporting from .+$",
    r"^\s*\([0-9A-Z.]+\)\s*$",
]

NOISE_SUBSTRINGS = [
    "@context",
    "schema.org",
    "imageobject",
    "contenturl",
    "credittext",
    "mainentityofpage",
    "newsmediaorganization",
    "breadcrumblist",
    "window.sentry",
    "dd_rum",
    "googletagmanager",
    "application/ld+json",
    "static01.nyt.com/images",
    "googlefourbythree",
    "superjumbo",
    "purchase licensing rights",
    "opens new tab",
    "sign up here",
    "our standards",
    "thomson reuters trust principles",
    "are you on telegram",
    "follow world news",
    "follow travel",
    "most read",
    "recommended videos",
    "share on facebook",
    "share on twitter",
    "add to your saved stories",
    "view on google maps",
    "want to get in touch",
    "email bytheway@washpost.com",
    "view image in fullscreen",
    "if you liked this story",
    "join more than three million bbc",
    "the essential list",
    "world's table",
    "watch on",
    "read more",
    "advertisement :",
    "photograph:",
    "skip advertisement",
    "editors’ picks",
    "editors' picks",
]

STOP_AFTER_SUBSTRINGS = [
    "most read",
    "recommended videos",
    "our standards",
    "the thomson reuters trust principles",
    "explore more",
    "this article appeared in",
    "discover stories from this section",
    "explore the edition",
    "ways & means",
    "more from travel:",
    "continue with a free trial",
    "editors’ picks",
    "editors' picks",
    "if you liked this story",
    "join more than three million bbc",
    "the essential list",
    "bbc.com's world's table",
]

def load_rows():
    return list(csv.DictReader(open(BANK_PATH, encoding="utf-8-sig")))


def load_manifest():
    return {row["id"]: row for row in json.load(open(MANIFEST_PATH, encoding="utf-8"))}


def normalize_key(text: str) -> str:
    text = text.replace("’", "'").replace("–", "-").replace("—", "-")
    text = re.sub(r"[^a-z0-9]+", "", text.lower())
    return text


def read_source_text(path: Path) -> str:
    if path.suffix.lower() in {".rtf", ".rtfd"}:
        try:
            out = subprocess.check_output(
                ["textutil", "-convert", "txt", "-stdout", str(path)],
                text=True,
                stderr=subprocess.DEVNULL,
            )
            return out
        except Exception:
            return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def is_placeholder_text(text: str) -> bool:
    lowered = text.lower()
    return "status: fetch_failed" in lowered or lowered.strip() in {"", "fetch_failed"}


def resolve_source_path(article_id: str, title: str) -> tuple[Path | None, str]:
    candidates = []
    id_txt = TEXTS / f"{article_id}.txt"
    for suffix in [".md", ".rtfd", ".rtf", ".txt"]:
        p = TEXTS / f"{article_id}{suffix}"
        if p.exists():
            candidates.append((f"id_{suffix.lstrip('.')}", p))

    normalized_title = normalize_key(title)
    for path in TEXTS.iterdir():
        if path.name.startswith("_") or path.name.startswith("."):
            continue
        if path.suffix.lower() not in {".txt", ".rtf", ".rtfd", ".md"}:
            continue
        if normalize_key(path.stem) == normalized_title:
            candidates.append(("title_match", path))

    best_path = None
    best_method = ""
    best_score = -1
    for method, path in candidates:
        text = read_source_text(path)
        if not text:
            continue
        score = 0
        if not is_placeholder_text(text):
            score += 10
        score += min(word_count(text), 2000) / 2000
        if method == "id_md":
            score += 3
        if method in {"id_rtfd", "id_rtf"}:
            score += 2
        if method == "id_txt":
            score += 1
        if path.suffix.lower() == ".md":
            score += 0.5
        if score > best_score:
            best_score = score
            best_path = path
            best_method = method

    if best_path is None and id_txt.exists():
        return id_txt, "id_txt"
    return best_path, best_method


def infer_source(raw_text: str, path: Path) -> str:
    m = re.search(r"^Source:\s*(.+)$", raw_text, flags=re.I | re.M)
    if m:
        return normalize_line(m.group(1))
    lowered = raw_text.lower()
    if "bbc.com" in lowered or "features correspondent" in lowered:
        return "BBC Travel"
    if "apnews.com/" in lowered:
        return "AP News"
    if "theguardian.com" in lowered or "this article is more than" in lowered:
        return "The Guardian"
    if "smithsonianmag.com" in lowered or "at the smithsonian" in lowered:
        return "Smithsonian"
    if "cnn.com" in lowered or "cnn —" in lowered or "cnn\n" in lowered:
        return "CNN"
    if "nationalgeographic.com" in lowered or "national geographic" in lowered:
        return "National Geographic"
    if "washingtonpost.com" in lowered or "add to your saved stories" in lowered:
        return "The Washington Post"
    if "nytimes.com" in lowered:
        return "The New York Times"
    if "(reuters)" in lowered or "reuters" in lowered:
        return "Reuters"
    return ""


def infer_title(raw_text: str) -> str:
    m = re.search(r"^Title:\s*(.+)$", raw_text, flags=re.I | re.M)
    if m:
        return normalize_line(m.group(1))
    lines = [normalize_line(x) for x in raw_text.splitlines() if normalize_line(x)]
    skip = {
        "city guide", "at the smithsonian", "share", "save", "stay", "neighborhoods", "eat",
        "do", "listen to this story",
    }
    for line in lines[:40]:
        line = re.sub(r"^\s{0,3}#+\s*", "", line).strip()
        if not line:
            continue
        if line.lower() in skip:
            continue
        if line.lower().startswith(("published ", "updated ", "by ", "photograph by", "id:", "url:", "status:", "source:", "title:", "bank:", "topic:", "method:", "words:", "fetched:", "publication date:")):
            continue
        if re.match(r"^\d+\s+min\s+read$", line.lower()):
            continue
        if word_count(line) >= 3:
            return line
    return ""


def extract_pub_date(url: str, article_id: str, raw_text: str = "") -> tuple[date | None, str]:
    head = raw_text[:5000]
    m = re.search(r"publication date:\s*(20\d{2})-(\d{2})-(\d{2})", head, flags=re.I)
    if m:
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3))), "text_iso_header"
    months = {
        "january": 1, "jan": 1,
        "february": 2, "feb": 2,
        "march": 3, "mar": 3,
        "april": 4, "apr": 4,
        "may": 5,
        "june": 6, "jun": 6,
        "july": 7, "jul": 7,
        "august": 8, "aug": 8,
        "september": 9, "sep": 9, "sept": 9,
        "october": 10, "oct": 10,
        "november": 11, "nov": 11,
        "december": 12, "dec": 12,
    }

    patterns = [
        ("text_month_day_year", r"\b(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+(\d{1,2})(?:st|nd|rd|th)?[,]?\s+(20\d{2})\b", "mdy"),
        ("text_day_month_year", r"\b(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+(20\d{2})\b", "dmy"),
        ("text_weekday_day_month_year", r"\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+(20\d{2})\b", "dmy"),
    ]
    for label, pattern, order in patterns:
        m = re.search(pattern, head, flags=re.I)
        if m:
            if order == "mdy":
                month = months[m.group(1).lower()]
                day = int(m.group(2))
                year = int(m.group(3))
            else:
                day = int(m.group(1))
                month = months[m.group(2).lower()]
                year = int(m.group(3))
            return date(year, month, day), label

    # Match YYYY/MM/DD
    m = re.search(r"/(20\d{2})/(0[1-9]|1[0-2])/([0-2]\d|3[01])/", url)
    if m:
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3))), "url_ymd"

    # Match YYYY-MM-DD
    m = re.search(r"(20\d{2})-(0[1-9]|1[0-2])-([0-2]\d|3[01])", url)
    if m:
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3))), "url_dash"

    # Archived Washington Post legacy pages often expose the date directly.
    if article_id == "APOL_012":
        return date(1995, 10, 8), "manual_from_url_bank"

    return None, "missing"


def split_header_body(text: str) -> tuple[str, str]:
    parts = re.split(r"\n=+\n", text, maxsplit=1)
    if len(parts) == 2:
        return parts[0], parts[1]
    lines = text.splitlines()
    if lines and lines[0].startswith("ID:"):
        for i, line in enumerate(lines):
            if not line.strip():
                return "\n".join(lines[:i]), "\n".join(lines[i + 1 :])
    return "", text


def normalize_line(line: str) -> str:
    line = line.replace("\r", "")
    line = re.sub(r"\s+", " ", line)
    return line.strip()


def is_noise_line(line: str) -> bool:
    if not line:
        return False
    lowered = line.lower().strip()
    for pat in NOISE_LINE_PATTERNS:
        if re.match(pat, lowered, flags=re.I):
            return True
    for token in NOISE_SUBSTRINGS:
        if token in lowered:
            return True
    if len(lowered) <= 3:
        return True
    if lowered.startswith("http"):
        return True
    if "status: fetch_failed" in lowered:
        return True
    if re.search(r"^\(?\d{2,4}[-\s]\d{2,4}[-\s]\d{2,4}", lowered):
        return True
    if re.search(r"^[^A-Za-z]*$", line):
        return True
    if re.search(r"^[A-Z][A-Z\s&/-]{3,}$", line):
        return True
    if re.search(r"^\w[\w\s,'’.-]{0,25}$", line) and lowered in {
        "world", "china", "business", "opinion", "culture", "archive 1945"
    }:
        return True
    return False


def clean_body(body: str) -> tuple[str, int, int]:
    body = body.replace("\r", "\n")
    body = body.replace("\u200b", "").replace("\u2028", "\n").replace("\u2029", "\n")
    body = re.sub(r"(?m)^\s{0,3}#+\s*", "", body)
    body = re.sub(r"!\[[^\]]*\]\([^)]+\)", " ", body)
    body = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", body)
    body = re.sub(r"`{1,3}", "", body)
    body = body.replace("**", "").replace("__", "")
    body = re.sub(r"\u00a0", " ", body)
    body = re.sub(r"https?://\S+", " ", body)
    body = re.sub(r"(?is)<details.*?</details>", " ", body)
    body = re.sub(r"(?is)<audio.*?</audio>", " ", body)
    body = re.sub(r"(?is)<script.*?</script>", " ", body)
    body = re.sub(r"(?is)<style.*?</style>", " ", body)
    body = re.sub(r"(?is)<[^>]+>", " ", body)
    body = re.sub(r"(?is)\{.*?@context.*?\}", " ", body)
    body = re.sub(r"(?is)\{.*?mainEntityOfPage.*?\}", " ", body)
    body = re.sub(r"\[阅读简体中文版\]\([^)]+\)\[閱讀繁體中文版\]\([^)]+\)", " ", body)

    raw_lines = [normalize_line(x) for x in body.split("\n")]
    kept_lines = []
    noise_lines = 0
    substantive_lines = 0

    for line in raw_lines:
        if not line:
            continue
        substantive_lines += 1
        lowered = line.lower()
        if any(marker in lowered for marker in STOP_AFTER_SUBSTRINGS):
            noise_lines += 1
            break
        if lowered in {"ingredients", "method", "directions"}:
            noise_lines += 1
            break
        if re.match(r"^step\s+\d+\s*$", lowered):
            noise_lines += 1
            break
        if lowered.endswith(" recipe") or lowered.endswith(" recipe.") or lowered.startswith("recipe"):
            noise_lines += 1
            break
        if is_noise_line(line):
            noise_lines += 1
            continue
        # Remove repeated caption-only lines.
        if re.search(r"photo[s]? by|credit|photograph:", line, flags=re.I):
            noise_lines += 1
            continue
        if re.search(r"^(reporting|editing) by ", lowered):
            noise_lines += 1
            continue
        if re.search(r"^item \d+ of \d+", lowered):
            noise_lines += 1
            continue
        if re.search(r"^\-+\s*$", lowered):
            noise_lines += 1
            continue
        if re.search(r"^\(?video:|^\(?photo:|^\(?graphic:", lowered):
            noise_lines += 1
            continue
        if re.search(r"^\d+\s+min read$", lowered):
            noise_lines += 1
            continue
        if lowered.startswith("by ") or lowered.startswith("photograph by"):
            noise_lines += 1
            continue
        if lowered.startswith("- "):
            noise_lines += 1
            continue
        if lowered.startswith("/ "):
            noise_lines += 1
            continue
        if " read more" in lowered:
            noise_lines += 1
            continue
        if "view image in fullscreen" in lowered:
            noise_lines += 1
            continue
        if "advertisement :" in lowered:
            noise_lines += 1
            continue
        if "watch on" == lowered:
            noise_lines += 1
            continue
        if "world's table" in lowered:
            noise_lines += 1
            break
        if "join more than three million bbc" in lowered:
            noise_lines += 1
            break
        if "if you liked this story" in lowered:
            noise_lines += 1
            break
        if "prefer the guardian on google" in lowered:
            noise_lines += 1
            continue
        if "get our newsletter" in lowered:
            noise_lines += 1
            continue
        if "features correspondent" in lowered or "senior china correspondent" in lowered:
            noise_lines += 1
            continue
        if re.match(r"^a local[’']?s travel guide to .+$", lowered):
            noise_lines += 1
            continue
        kept_lines.append(line)

    # Reuters pages often start with image captions; when a dateline exists, cut to it.
    reuters_start = None
    for i, line in enumerate(kept_lines):
        if re.search(r"^[A-Z][A-Z .'-]+,\s+[A-Z][a-z]+ \d{1,2}\s+\(Reuters\)\s+-", line):
            reuters_start = i
            break
    if reuters_start is not None:
        kept_lines = kept_lines[reuters_start:]

    # Strip remaining leading title/date/menu/caption clutter until the first substantive paragraph.
    started = False
    content_lines = []
    for line in kept_lines:
        if not started:
            sentence_like = re.search(r"[.!?]['”\"]?$", line) and not line.endswith(")")
            if word_count(line) >= 12 and sentence_like:
                started = True
            elif word_count(line) >= 18 and not line.endswith(")"):
                started = True
        if started:
            content_lines.append(line)

    if content_lines:
        kept_lines = content_lines

    deduped_lines = []
    prev_key = ""
    for line in kept_lines:
        key = normalize_key(line)
        if key and key == prev_key:
            continue
        deduped_lines.append(line)
        prev_key = key

    while deduped_lines:
        tail = deduped_lines[-1].strip()
        lowered = tail.lower()
        if not tail:
            deduped_lines.pop()
            continue
        if re.search(r"(alamy|getty|ap photo|reuters|xinhua|imaginechina|afp)(/|$)", lowered):
            deduped_lines.pop()
            continue
        if word_count(tail) <= 4 and not re.search(r"[.!?]['”\"]?\s*$", tail):
            deduped_lines.pop()
            continue
        break

    cleaned = "\n\n".join(x for x in deduped_lines if x)
    cleaned = re.sub(r"\n{2,}", "\n\n", cleaned)
    cleaned = re.sub(r"[ \t]+", " ", cleaned).strip()
    return cleaned, noise_lines, substantive_lines


def trim_to_word_limit(text: str, target_words: int = PREFERRED_MAX_WORDS) -> tuple[str, int]:
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    kept = []
    total = 0
    for para in paragraphs:
        w = word_count(para)
        if kept and total + w > target_words:
            break
        kept.append(para)
        total += w
    if not kept:
        return text, 0
    while kept:
        tail = kept[-1].strip()
        if not tail:
            kept.pop()
            continue
        if word_count(tail) <= 8 and not re.search(r"[.!?]['”\"]?\s*$", tail):
            kept.pop()
            continue
        if word_count(tail) <= 12 and re.fullmatch(r"[A-Z0-9][A-Za-z0-9\s,'’:/&()\-]+", tail):
            kept.pop()
            continue
        if not re.search(r"[.!?]['”\"]?\s*$", tail) and word_count(tail) <= 18:
            kept.pop()
            continue
        break
    if not kept:
        return text, 0
    return "\n\n".join(kept).strip(), 1 if len(kept) < len(paragraphs) else 0


def word_count(text: str) -> int:
    return len(re.findall(r"\b[\w'-]+\b", text))


def sentence_count(text: str) -> int:
    parts = re.split(r"(?<=[.!?])\s+", text.strip())
    parts = [p for p in parts if word_count(p) >= 3]
    return len(parts)


def info_density(text: str) -> float:
    words = re.findall(r"\b[\w'-]+\b", text.lower())
    if not words:
        return 0.0
    stop = {
        "the", "a", "an", "and", "or", "of", "to", "in", "on", "for", "with",
        "is", "are", "was", "were", "be", "been", "being", "that", "this",
        "it", "as", "at", "by", "from", "but", "if", "they", "their", "you",
        "we", "he", "she", "his", "her", "its", "them", "about", "into", "than",
        "after", "before", "over", "under", "more", "most", "some", "many",
    }
    content = [w for w in words if w not in stop and len(w) > 2]
    return len(content) / max(len(words), 1)


def likely_truncated(text: str) -> bool:
    if not text:
        return True
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    while lines and len(lines[-1].split()) <= 12 and not re.search(r"[.!?]['”\"]?\s*$", lines[-1]):
        lines.pop()
    if not lines:
        return True
    tail = "\n".join(lines)[-160:]
    if re.search(r"[A-Za-z]{1,4}$", tail) and not re.search(r"[.!?]['”\"]?\s*$", tail):
        return True
    if tail.count("{") + tail.count("}") > 0:
        return True
    if "mainEntityOfPage" in tail or '"@context"' in tail:
        return True
    return False


def keep_decision(pub_date, cleaned_words, sentences, noise_share, density, truncated):
    reasons = []
    if pub_date is not None and pub_date < MIN_DATE:
        reasons.append("too_old")
    if pub_date is not None and pub_date > MAX_DATE:
        reasons.append("published_after_experiment_start")
    if cleaned_words < MIN_WORDS:
        reasons.append("too_short")
    if cleaned_words > MAX_WORDS:
        reasons.append("too_long")
    if sentences < MIN_SENTENCES:
        reasons.append("too_few_sentences")
    if noise_share > MAX_NOISE_SHARE:
        reasons.append("too_noisy")
    if density < MIN_INFO_DENSITY:
        reasons.append("low_information_density")
    if truncated:
        reasons.append("truncated_or_broken")

    if reasons:
        salvage_ok = (
            "too_old" not in reasons and
            "published_after_experiment_start" not in reasons and
            "truncated_or_broken" not in reasons and
            "low_information_density" not in reasons and
            cleaned_words >= MIN_WORDS and
            sentences >= MIN_SENTENCES and
            noise_share <= SALVAGE_NOISE_SHARE
        )
        if salvage_ok:
            return "salvage_with_trim", ";".join(reasons)
        return "replace", ";".join(reasons)

    if cleaned_words < PREFERRED_MIN_WORDS or cleaned_words > PREFERRED_MAX_WORDS:
        return "salvage_with_trim", "outside_preferred_length_band"

    return "keep", ""


def main():
    rows = load_rows()
    manifest = load_manifest()

    audit_rows = []
    assignments = []
    for row in rows:
        article_id = row["id"]
        source_path, source_method = resolve_source_path(article_id, row["title"])
        raw_text = read_source_text(source_path) if source_path else ""
        inferred_title = infer_title(raw_text) if raw_text else ""
        inferred_source = infer_source(raw_text, source_path) if source_path else ""
        _, body = split_header_body(raw_text)
        cleaned, noise_lines, total_lines = clean_body(body)
        trimmed_for_classroom = 0
        if word_count(cleaned) > MAX_WORDS:
            cleaned, trimmed_for_classroom = trim_to_word_limit(cleaned, target_words=PREFERRED_MAX_WORDS)

        pub_date, date_source = extract_pub_date(row["url"], article_id, raw_text=raw_text)
        cleaned_words = word_count(cleaned)
        raw_words = word_count(body)
        sentences = sentence_count(cleaned)
        density = info_density(cleaned)
        noise_share = noise_lines / max(total_lines, 1)
        truncated = likely_truncated(cleaned)
        decision, reasons = keep_decision(
            pub_date=pub_date,
            cleaned_words=cleaned_words,
            sentences=sentences,
            noise_share=noise_share,
            density=density,
            truncated=truncated,
        )

        effective_title = inferred_title or row["title"]
        effective_source = inferred_source or row["source"]
        effective_url = row["url"] if row["url"] and normalize_key(effective_title) == normalize_key(row["title"]) else ""

        audit_rows.append({
            "id": article_id,
            "bank": row["bank"],
            "source": effective_source,
            "title": effective_title,
            "url": effective_url,
            "manifest_status": manifest.get(article_id, {}).get("status", "missing"),
            "method": manifest.get(article_id, {}).get("method", ""),
            "source_path": str(source_path) if source_path else "",
            "source_resolution": source_method,
            "pub_date": pub_date.isoformat() if pub_date else "",
            "date_source": date_source,
            "raw_words": raw_words,
            "cleaned_words": cleaned_words,
            "sentences": sentences,
            "noise_share": round(noise_share, 4),
            "info_density": round(density, 4),
            "truncated": int(truncated),
            "trimmed_for_classroom": trimmed_for_classroom,
            "decision": decision,
            "reasons": reasons,
            "cleaned_preview": cleaned[:600],
        })

        assignments.append({
            "id": article_id,
            "bank": row["bank"],
            "source_file": source_path.name if source_path else "",
            "source_resolution": source_method,
            "effective_source": effective_source,
            "effective_title": effective_title,
            "pub_date": pub_date.isoformat() if pub_date else "",
            "decision": decision,
        })

    with open(ASSIGNMENT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(assignments[0].keys()))
        writer.writeheader()
        writer.writerows(assignments)

    audit_csv = OUTDIR / "article_bank_audit.csv"
    with open(audit_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(audit_rows[0].keys()))
        writer.writeheader()
        writer.writerows(audit_rows)

    kept = [r for r in audit_rows if r["decision"] in {"keep", "salvage_with_trim"}]
    dropped = [r for r in audit_rows if r["decision"] == "replace"]
    unverified_date = [r for r in kept if not r["pub_date"]]

    keep_by_bank = Counter(r["bank"] for r in kept)
    total_by_bank = Counter(r["bank"] for r in audit_rows)

    target_by_bank = {
        "PRO": 24,
        "ANTI": 24,
        "NONCHINA_CONTROL": 24,
        "APOL_CHINA": 17,
    }

    shortages = []
    for bank, target in target_by_bank.items():
        kept_n = keep_by_bank.get(bank, 0)
        shortages.append({
            "bank": bank,
            "target_n": target,
            "kept_n": kept_n,
            "need_replacements": max(target - kept_n, 0),
        })

    shortage_csv = OUTDIR / "article_bank_shortages.csv"
    with open(shortage_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(shortages[0].keys()))
        writer.writeheader()
        writer.writerows(shortages)

    reason_counts = Counter()
    reasons_by_bank = defaultdict(Counter)
    for row in dropped:
        for reason in row["reasons"].split(";"):
            if not reason:
                continue
            reason_counts[reason] += 1
            reasons_by_bank[row["bank"]][reason] += 1

    summary_md = OUTDIR / "article_bank_screening_summary.md"
    with open(summary_md, "w", encoding="utf-8") as f:
        f.write("# Article Bank Screening Summary\n\n")
        f.write(f"Screening date: {TODAY.isoformat()}\n\n")
        f.write("## Rules\n\n")
        f.write(f"- Publication date must be on or after {MIN_DATE.isoformat()}.\n")
        f.write(f"- Publication date must be on or before {MAX_DATE.isoformat()} so that no article post-dates the June 2025 experiment launch.\n")
        f.write(f"- Cleaned word count must be at least {MIN_WORDS}; preferred band is {PREFERRED_MIN_WORDS}-{PREFERRED_MAX_WORDS}; hard maximum is {MAX_WORDS}.\n")
        f.write(f"- Cleaned text must contain at least {MIN_SENTENCES} usable sentences.\n")
        f.write(f"- Noise-line share must be <= {MAX_NOISE_SHARE:.2f}.\n")
        f.write(f"- Information-density heuristic must be >= {MIN_INFO_DENSITY:.2f}.\n")
        f.write("- Text cannot look truncated or obviously broken.\n")
        f.write("- Dates are treated as disqualifying when an explicit pre-2016 or post-launch publication date can be identified.\n")
        f.write("- Articles with missing publication dates are listed separately for manual verification.\n\n")

        f.write("## Kept by Bank\n\n")
        for bank in ["PRO", "ANTI", "APOL_CHINA", "NONCHINA_CONTROL"]:
            strict_keep = sum(r["bank"] == bank and r["decision"] == "keep" for r in audit_rows)
            salvage = sum(r["bank"] == bank and r["decision"] == "salvage_with_trim" for r in audit_rows)
            f.write(f"- {bank}: {strict_keep} keep, {salvage} salvage_with_trim, {total_by_bank.get(bank, 0)} total\n")
        f.write("\n## Date Verification Needed\n\n")
        f.write(f"- {len(unverified_date)} kept/salvage articles still have missing publication dates and should be manually verified before final classroom use.\n")
        for row in unverified_date:
            f.write(f"- {row['id']} ({row['bank']}, {row['source']}): {row['title']}\n")
        f.write("\n## Replacement Needs\n\n")
        for row in shortages:
            f.write(f"- {row['bank']}: need {row['need_replacements']} replacements\n")

        f.write("\n## Main Drop Reasons\n\n")
        for reason, count in reason_counts.most_common():
            f.write(f"- {reason}: {count}\n")

        f.write("\n## Dropped Articles\n\n")
        for row in dropped:
            f.write(
                f"- {row['id']} ({row['bank']}, {row['source']}): {row['title']} [{row['reasons']}]\n"
            )

    print("Saved", audit_csv)
    print("Saved", shortage_csv)
    print("Saved", summary_md)
    print("Kept by bank:", dict(keep_by_bank))
    print("Reasons:", dict(reason_counts))


if __name__ == "__main__":
    main()
