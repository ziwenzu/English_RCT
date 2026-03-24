#!/usr/bin/env python3
"""
fetch_articles.py

Try to download as many full texts as possible for the teaching article bank.

Fetch order:
  1. direct HTML fetch + text extraction
  2. r.jina.ai proxy fallback
  3. Wayback "available" snapshot
  4. Wayback CDX search over multiple snapshots

Outputs:
  - article_texts/{id}.txt
  - article_texts/_manifest.json
  - article_texts/_fetch_failures.csv
"""

from __future__ import annotations

import csv
import html
import json
import os
import re
import time
from datetime import datetime
from typing import Iterable, Optional
from urllib.parse import quote

import requests
import trafilatura
from bs4 import BeautifulSoup
from readability import Document


BASE = os.path.dirname(os.path.abspath(__file__))
BANK = os.path.join(BASE, "materials_master_bank.csv")
OUTDIR = os.path.join(BASE, "article_texts")
os.makedirs(OUTDIR, exist_ok=True)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}

MIN_WORDS = 150
TIMEOUT = 30
PAUSE_SEC = 1.2

BLOCK_PATTERNS = [
    "just a moment",
    "please enable js",
    "please enable javascript",
    "disable any ad blocker",
    "performing security verification",
    "security service to protect against malicious bots",
    "captcha",
    "access denied",
    "page not found",
    "target url returned error 403",
    "target url returned error 401",
]

SESSION = requests.Session()
SESSION.headers.update(HEADERS)


def normalize_text(text: str) -> str:
    text = html.unescape(text or "")
    text = text.replace("\r", "\n")

    # Strip r.jina metadata block if present.
    if "Markdown Content:" in text:
        text = text.split("Markdown Content:", 1)[1]
    text = re.sub(r"^Title:\s.*?$", "", text, flags=re.M)
    text = re.sub(r"^URL Source:\s.*?$", "", text, flags=re.M)
    text = re.sub(r"^Published Time:\s.*?$", "", text, flags=re.M)
    text = re.sub(r"^Warning:\s.*?$", "", text, flags=re.M)

    # Basic markdown cleanup.
    text = re.sub(r"!\[[^\]]*\]\([^)]+\)", " ", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"`{1,3}", "", text)
    text = re.sub(r"^[#>*\-\s]+", "", text, flags=re.M)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip()


def word_count(text: str) -> int:
    return len(re.findall(r"\b[\w'-]+\b", text or ""))


def looks_blocked(text: str) -> bool:
    lowered = (text or "").lower()
    return any(pat in lowered for pat in BLOCK_PATTERNS)


def looks_good(text: Optional[str]) -> bool:
    if not text:
        return False
    cleaned = normalize_text(text)
    return word_count(cleaned) >= MIN_WORDS and not looks_blocked(cleaned)


def iter_json_objects(obj) -> Iterable[dict]:
    if isinstance(obj, dict):
        yield obj
        for value in obj.values():
            yield from iter_json_objects(value)
    elif isinstance(obj, list):
        for item in obj:
            yield from iter_json_objects(item)


def extract_from_jsonld(soup: BeautifulSoup) -> Optional[str]:
    candidates = []
    for node in soup.find_all("script", attrs={"type": "application/ld+json"}):
        raw = node.get_text(" ", strip=True)
        if not raw:
            continue
        try:
            parsed = json.loads(raw)
        except Exception:
            continue
        for obj in iter_json_objects(parsed):
            for key in ("articleBody", "text", "description"):
                value = obj.get(key)
                if isinstance(value, str) and word_count(value) >= MIN_WORDS:
                    candidates.append(value)
    if not candidates:
        return None
    return max(candidates, key=word_count)


def extract_from_selectors(soup: BeautifulSoup) -> Optional[str]:
    selectors = [
        "article p",
        "main p",
        '[data-qa="article-body"] p',
        '[data-testid="article-body"] p',
        ".article-body p",
        ".article-content p",
        ".paywall p",
    ]
    candidates = []
    for selector in selectors:
        parts = [p.get_text(" ", strip=True) for p in soup.select(selector)]
        text = "\n".join(x for x in parts if x)
        if looks_good(text):
            candidates.append(text)
    if not candidates:
        return None
    return max(candidates, key=word_count)


def extract_from_html(html_text: str, url: str) -> Optional[str]:
    if not html_text or looks_blocked(html_text):
        return None

    candidates: list[str] = []

    try:
        text = trafilatura.extract(
            html_text,
            url=url,
            include_comments=False,
            include_tables=False,
            no_fallback=False,
        )
        if looks_good(text):
            candidates.append(text)
    except Exception:
        pass

    try:
        summary_html = Document(html_text).summary()
        summary_text = BeautifulSoup(summary_html, "lxml").get_text("\n", strip=True)
        if looks_good(summary_text):
            candidates.append(summary_text)
    except Exception:
        pass

    soup = BeautifulSoup(html_text, "lxml")

    jsonld_text = extract_from_jsonld(soup)
    if looks_good(jsonld_text):
        candidates.append(jsonld_text)

    selector_text = extract_from_selectors(soup)
    if looks_good(selector_text):
        candidates.append(selector_text)

    if not candidates:
        return None

    return normalize_text(max(candidates, key=word_count))


def fetch_url(url: str) -> tuple[Optional[str], Optional[int], Optional[str]]:
    try:
        response = SESSION.get(url, timeout=TIMEOUT, allow_redirects=True)
        return response.text, response.status_code, response.url
    except Exception:
        return None, None, None


def fetch_direct(url: str) -> tuple[Optional[str], Optional[str]]:
    html_text, status, final_url = fetch_url(url)
    if status != 200 or not html_text:
        return None, None
    text = extract_from_html(html_text, final_url or url)
    if looks_good(text):
        return text, "direct_html"
    return None, None


def fetch_jina(url: str) -> tuple[Optional[str], Optional[str]]:
    proxy_url = "https://r.jina.ai/http://" + url.replace("https://", "").replace("http://", "")
    try:
        response = SESSION.get(proxy_url, timeout=45)
    except Exception:
        return None, None
    if response.status_code != 200:
        return None, None
    body = response.text or ""
    if "SecurityCompromiseError" in body:
        return None, None
    text = normalize_text(body)
    if looks_good(text):
        return text, "jina_proxy"
    return None, None


def get_wayback_snapshot_urls(url: str) -> list[tuple[str, str]]:
    snapshots: list[tuple[str, str]] = []

    try:
        available_url = "https://archive.org/wayback/available?url=" + quote(url, safe="")
        response = SESSION.get(available_url, timeout=15)
        data = response.json()
        snap = data.get("archived_snapshots", {}).get("closest", {})
        if snap.get("available") and snap.get("url") and snap.get("timestamp"):
            snapshots.append((snap["url"], snap["timestamp"]))
    except Exception:
        pass

    try:
        cdx_url = (
            "https://web.archive.org/cdx/search/cdx?url="
            + quote(url, safe="")
            + "&output=json&fl=timestamp,original,statuscode,mimetype"
            + "&filter=statuscode:200&limit=8&from=2018"
        )
        response = SESSION.get(cdx_url, timeout=20)
        rows = response.json()
        if isinstance(rows, list) and len(rows) > 1:
            for row in rows[1:]:
                if not isinstance(row, list) or len(row) < 2:
                    continue
                timestamp = row[0]
                snap_url = f"https://web.archive.org/web/{timestamp}/{url}"
                snapshots.append((snap_url, timestamp))
    except Exception:
        pass

    deduped = []
    seen = set()
    for snap_url, timestamp in snapshots:
        key = (snap_url, timestamp)
        if key not in seen:
            deduped.append((snap_url, timestamp))
            seen.add(key)
    return deduped


def fetch_wayback(url: str) -> tuple[Optional[str], Optional[str]]:
    for snap_url, timestamp in get_wayback_snapshot_urls(url):
        html_text, status, final_url = fetch_url(snap_url)
        if status != 200 or not html_text:
            continue
        text = extract_from_html(html_text, final_url or snap_url)
        if looks_good(text):
            return text, f"wayback:{timestamp}"
    return None, None


def write_article(row: dict, text: str, method: str, outpath: str) -> int:
    wc = word_count(text)
    header = (
        f"ID: {row['id']}\n"
        f"Bank: {row['bank']}\n"
        f"Source: {row['source']}\n"
        f"Title: {row['title']}\n"
        f"URL: {row['url']}\n"
        f"Topic: {row['topic']}\n"
        f"Method: {method}\n"
        f"Words: {wc}\n"
        f"Fetched: {datetime.now().isoformat()}\n"
        f"{'=' * 60}\n\n"
    )
    with open(outpath, "w", encoding="utf-8") as handle:
        handle.write(header + normalize_text(text) + "\n")
    return wc


def cached_word_count(path: str) -> int:
    if not os.path.exists(path):
        return 0
    try:
        return word_count(open(path, encoding="utf-8", errors="ignore").read())
    except Exception:
        return 0


def inspect_saved_article(row: dict) -> dict:
    outpath = os.path.join(OUTDIR, f"{row['id']}.txt")
    if not os.path.exists(outpath):
        return {
            "id": row["id"],
            "bank": row["bank"],
            "source": row["source"],
            "title": row["title"],
            "url": row["url"],
            "status": "failed",
            "words": 0,
            "method": "missing",
        }

    text = open(outpath, encoding="utf-8", errors="ignore").read()
    wc = word_count(text)
    header_method = None
    match = re.search(r"^Method:\s*(.+?)\s*$", text, flags=re.M)
    if match:
        header_method = match.group(1).strip()

    status = "ok" if wc >= MIN_WORDS else "failed"
    return {
        "id": row["id"],
        "bank": row["bank"],
        "source": row["source"],
        "title": row["title"],
        "url": row["url"],
        "status": status,
        "words": wc,
        "method": header_method or ("cached" if status == "ok" else "none"),
    }


def main() -> None:
    with open(BANK, newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))

    results = []

    for i, row in enumerate(rows, start=1):
        article_id = row["id"]
        url = row["url"]
        outpath = os.path.join(OUTDIR, f"{article_id}.txt")

        if cached_word_count(outpath) >= MIN_WORDS:
            words = cached_word_count(outpath)
            print(f"[{i:02d}/{len(rows)}] SKIP  {article_id} cached ({words} words)")
            results.append(
                {
                    "id": article_id,
                    "bank": row["bank"],
                    "source": row["source"],
                    "title": row["title"],
                    "url": url,
                    "status": "ok",
                    "words": words,
                    "method": "cached",
                }
            )
            continue

        print(f"[{i:02d}/{len(rows)}] FETCH {article_id}  {row['source']}  {row['title'][:72]}")

        text = None
        method = None

        for fetcher in (fetch_direct, fetch_jina, fetch_wayback):
            text, method = fetcher(url)
            if looks_good(text):
                break

        if looks_good(text):
            words = write_article(row, text, method, outpath)
            print(f"         -> OK     {words:4d} words via {method}")
            results.append(
                {
                    "id": article_id,
                    "bank": row["bank"],
                    "source": row["source"],
                    "title": row["title"],
                    "url": url,
                    "status": "ok",
                    "words": words,
                    "method": method,
                }
            )
        else:
            with open(outpath, "w", encoding="utf-8") as handle:
                handle.write(f"ID: {article_id}\nURL: {url}\nSTATUS: FETCH_FAILED\n")
            print("         -> FAILED")
            results.append(
                {
                    "id": article_id,
                    "bank": row["bank"],
                    "source": row["source"],
                    "title": row["title"],
                    "url": url,
                    "status": "failed",
                    "words": 0,
                    "method": "none",
                }
            )

        time.sleep(PAUSE_SEC)

    # Rebuild the final manifest from the actual saved files so the manifest
    # always reflects disk state, even if a previous run overlapped.
    final_results = [inspect_saved_article(row) for row in rows]

    manifest_path = os.path.join(OUTDIR, "_manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(final_results, handle, indent=2, ensure_ascii=False)

    failures_path = os.path.join(OUTDIR, "_fetch_failures.csv")
    with open(failures_path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["id", "bank", "source", "title", "url", "status", "words", "method"],
        )
        writer.writeheader()
        writer.writerows([row for row in final_results if row["status"] != "ok"])

    ok = [row for row in final_results if row["status"] == "ok"]
    failed = [row for row in final_results if row["status"] != "ok"]
    methods = {}
    for row in ok:
        methods[row["method"]] = methods.get(row["method"], 0) + 1

    print("\n" + "=" * 60)
    print(f"Total:   {len(results)}")
    print(f"OK:      {len(ok)}")
    print(f"Failed:  {len(failed)}")
    print(f"Methods: {methods}")
    print(f"Manifest: {manifest_path}")
    print(f"Failures: {failures_path}")


if __name__ == "__main__":
    main()
