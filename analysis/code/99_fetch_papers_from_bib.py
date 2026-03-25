#!/usr/bin/env python3
from __future__ import annotations

import csv
import difflib
import html
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

import bibtexparser
import requests


USER_AGENT = "Codex/1.0 (mailto:none@example.com)"
OPENALEX_URL = "https://api.openalex.org/works"
REQUEST_TIMEOUT = 25
SEARCH_SLEEP_SECONDS = 0.15
MIN_CANDIDATE_SCORE = 0.82
LOCAL_LITERATURE_BIB = Path("/Users/ziwenzu/Library/CloudStorage/Dropbox/Literature/Reference/literature.bib")
APPENDIX_MARKERS = (
    "online appendix",
    "supplementary materials",
    "supplementary appendix",
    "appendix supplementary materials",
    "appendix keywords",
)


def normalize_title(text: str) -> str:
    text = text or ""
    text = html.unescape(text)
    text = text.replace("``", '"').replace("''", '"')
    text = re.sub(r"\\[a-zA-Z]+\{([^}]*)\}", r"\1", text)
    text = text.replace("{", "").replace("}", "")
    text = text.replace("\\", "")
    text = text.lower()
    text = re.sub(r"\s+", " ", text).strip()
    return text


def compact_title(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", normalize_title(text))


def first_author_last(author_field: str) -> str:
    first = (author_field or "").split(" and ")[0].strip()
    if "," in first:
        return first.split(",")[0].strip().lower()
    parts = first.split()
    return parts[-1].lower() if parts else ""


def safe_host(url: str) -> str:
    try:
        return urllib.parse.urlparse(url).netloc
    except Exception:
        return ""


def pdf_first_page_text(path: Path) -> str:
    try:
        result = subprocess.run(
            ["pdftotext", "-f", "1", "-l", "1", str(path), "-"],
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )
    except Exception:
        return ""
    return result.stdout or ""


def pdf_quality_issue(entry: dict, pdf_path: Path) -> str:
    first_page = normalize_title(pdf_first_page_text(pdf_path))
    if not first_page:
        return "empty_first_page_text"

    for marker in APPENDIX_MARKERS:
        if marker in first_page[:1500]:
            return f"appendix_like:{marker}"

    expected_compact = compact_title(entry.get("title", ""))
    first_page_compact = compact_title(first_page)
    if not expected_compact:
        return ""

    if expected_compact in first_page_compact:
        return ""

    similarity = difflib.SequenceMatcher(
        None,
        expected_compact,
        first_page_compact[: max(len(expected_compact) * 3, 1200)],
    ).ratio()
    if similarity < 0.2:
        return "title_not_found_on_first_page"
    return ""


def unique_path(path: Path) -> Path:
    if not path.exists():
        return path
    stem = path.stem
    suffix = path.suffix
    parent = path.parent
    index = 2
    while True:
        candidate = parent / f"{stem}_{index}{suffix}"
        if not candidate.exists():
            return candidate
        index += 1


def archive_invalid_pdf(source: Path, rejected_dir: Path, key: str, reason: str) -> Path:
    rejected_dir.mkdir(parents=True, exist_ok=True)
    safe_reason = re.sub(r"[^a-z0-9]+", "_", reason.lower()).strip("_") or "invalid"
    destination = unique_path(rejected_dir / f"{key}__{safe_reason}.pdf")
    shutil.move(str(source), str(destination))
    return destination


def load_local_literature_index() -> dict[str, list[dict]]:
    if not LOCAL_LITERATURE_BIB.exists():
        return {}
    literature = bibtexparser.loads(LOCAL_LITERATURE_BIB.read_text()).entries
    index: dict[str, list[dict]] = {}
    for entry in literature:
        title = compact_title(entry.get("title", ""))
        file_path = entry.get("file", "")
        if not title or not file_path:
            continue
        pdf_path = Path(file_path)
        if not pdf_path.exists():
            continue
        index.setdefault(title, []).append(entry)
    return index


def choose_local_candidate(entry: dict, local_index: dict[str, list[dict]]) -> dict | None:
    candidates = local_index.get(compact_title(entry.get("title", "")), [])
    if not candidates:
        return None

    entry_first_author = first_author_last(entry.get("author", ""))
    best_score = -1.0
    best_entry: dict | None = None
    for candidate in candidates:
        score = 0.0
        if entry_first_author and entry_first_author == first_author_last(candidate.get("author", "")):
            score += 1.0
        if str(entry.get("year", "")) == str(candidate.get("year", "")):
            score += 0.5
        if score > best_score:
            best_score = score
            best_entry = candidate
    return best_entry


def search_openalex(session: requests.Session, title: str) -> list[dict]:
    params = {"search": title, "per-page": 8, "mailto": "none@example.com"}
    response = session.get(OPENALEX_URL, params=params, timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json().get("results", [])


def year_distance(entry_year: str, result_year: int | None) -> float:
    if not entry_year or not result_year:
        return 0.0
    try:
        delta = abs(int(entry_year) - int(result_year))
    except ValueError:
        return 0.0
    if delta == 0:
        return 0.08
    if delta == 1:
        return 0.04
    if delta == 2:
        return 0.01
    return -0.03


def type_bonus(entry_type: str, result_type: str) -> float:
    entry_type = (entry_type or "").lower()
    result_type = (result_type or "").lower()
    if entry_type == "article":
        if result_type in {"article", "preprint", "report", "peer-review"}:
            return 0.08
        if result_type in {"book-chapter"}:
            return -0.05
    if entry_type == "book":
        if result_type in {"book", "monograph", "edited-book"}:
            return 0.08
        if result_type in {"article", "preprint", "report", "dataset", "reference-entry"}:
            return -0.2
    return 0.0


def score_candidate(entry: dict, result: dict) -> float:
    entry_title = compact_title(entry.get("title", ""))
    result_title = compact_title(result.get("title", ""))
    score = difflib.SequenceMatcher(None, entry_title, result_title).ratio()

    first_last = first_author_last(entry.get("author", ""))
    authors = [a.get("author", {}).get("display_name", "") for a in result.get("authorships", [])]
    author_lasts = [name.split()[-1].lower() for name in authors if name]
    if first_last and first_last in author_lasts:
        score += 0.08

    score += year_distance(entry.get("year", ""), result.get("publication_year"))
    score += type_bonus(entry.get("ENTRYTYPE", ""), result.get("type", ""))

    open_access = result.get("open_access") or {}
    if open_access.get("is_oa"):
        score += 0.04
    return score


def candidate_urls(result: dict) -> list[tuple[str, str]]:
    urls: list[tuple[str, str]] = []
    seen: set[str] = set()

    def add(url: str | None, kind: str) -> None:
        if not url:
            return
        url = url.strip()
        if not url or url in seen:
            return
        seen.add(url)
        urls.append((url, kind))

    best = result.get("best_oa_location") or {}
    add(best.get("pdf_url"), "best_pdf")
    add(best.get("landing_page_url"), "best_landing")

    open_access = result.get("open_access") or {}
    add(open_access.get("oa_url"), "oa_url")

    for location in result.get("locations") or []:
        add(location.get("pdf_url"), "location_pdf")
        add(location.get("landing_page_url"), "location_landing")

    primary = result.get("primary_location") or {}
    add(primary.get("pdf_url"), "primary_pdf")
    add(primary.get("landing_page_url"), "primary_landing")

    ids = result.get("ids") or {}
    add(ids.get("doi"), "doi")
    return urls


def extract_pdf_links(html_text: str, base_url: str) -> list[str]:
    patterns = [
        r'<meta[^>]+name=["\']citation_pdf_url["\'][^>]+content=["\']([^"\']+)["\']',
        r'<meta[^>]+property=["\']citation_pdf_url["\'][^>]+content=["\']([^"\']+)["\']',
        r'href=["\']([^"\']+\.pdf(?:\?[^"\']*)?)["\']',
        r'href=["\']([^"\']*download[^"\']*pdf[^"\']*)["\']',
        r'href=["\']([^"\']*Delivery\.cfm[^"\']*)["\']',
    ]
    links: list[str] = []
    seen: set[str] = set()
    for pattern in patterns:
        for match in re.findall(pattern, html_text, flags=re.I):
            full_url = urllib.parse.urljoin(base_url, html.unescape(match))
            if full_url not in seen:
                seen.add(full_url)
                links.append(full_url)
    return links


def write_pdf(content: bytes, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(content)


def looks_like_pdf(response: requests.Response, content: bytes) -> bool:
    content_type = (response.headers.get("content-type") or "").lower()
    if "application/pdf" in content_type:
        return True
    return content.startswith(b"%PDF")


def fetch_once(session: requests.Session, url: str) -> requests.Response:
    return session.get(
        url,
        timeout=REQUEST_TIMEOUT,
        allow_redirects=True,
        headers={"Accept": "application/pdf,text/html;q=0.9,*/*;q=0.8"},
    )


def try_download_pdf(
    session: requests.Session,
    url: str,
    destination: Path,
    visited: set[str] | None = None,
    depth: int = 0,
) -> tuple[bool, str, str]:
    visited = visited or set()
    if url in visited or depth > 2:
        return False, "", "visited_or_too_deep"
    visited.add(url)

    try:
        response = fetch_once(session, url)
    except Exception as exc:
        return False, "", f"request_failed:{exc}"

    content = response.content
    final_url = response.url
    if response.status_code >= 400:
        return False, final_url, f"http_{response.status_code}"

    if looks_like_pdf(response, content):
        write_pdf(content, destination)
        return True, final_url, "downloaded_pdf"

    content_type = (response.headers.get("content-type") or "").lower()
    if "html" not in content_type and not content[:256].lower().startswith(b"<!doctype html") and not content[:32].startswith(b"<html"):
        return False, final_url, f"non_pdf_content:{content_type or 'unknown'}"

    try:
        text = content.decode(response.encoding or "utf-8", errors="ignore")
    except Exception as exc:
        return False, final_url, f"html_decode_failed:{exc}"

    for next_url in extract_pdf_links(text, final_url):
        success, resolved_url, note = try_download_pdf(session, next_url, destination, visited, depth + 1)
        if success:
            return True, resolved_url, f"via_html:{note}"

    return False, final_url, "no_pdf_link_found"


def pick_results(entry: dict, results: list[dict]) -> list[dict]:
    scored: list[tuple[float, dict]] = []
    for result in results:
        score = score_candidate(entry, result)
        scored.append((score, result))
    scored.sort(key=lambda item: item[0], reverse=True)

    kept = [result for score, result in scored if score >= MIN_CANDIDATE_SCORE]
    if kept:
        return kept
    return [result for _, result in scored[:3]]


def choose_best_downloadable(entry: dict, results: list[dict]) -> list[tuple[dict, list[tuple[str, str]]]]:
    ordered: list[tuple[float, dict, list[tuple[str, str]]]] = []
    for result in pick_results(entry, results):
        urls = candidate_urls(result)
        if not urls:
            continue
        score = score_candidate(entry, result)
        open_access = result.get("open_access") or {}
        if open_access.get("is_oa"):
            score += 0.05
        if any(kind.endswith("pdf") for _, kind in urls):
            score += 0.04
        ordered.append((score, result, urls))
    ordered.sort(key=lambda item: item[0], reverse=True)
    return [(result, urls) for _, result, urls in ordered]


def build_filename(key: str) -> str:
    return f"{key}.pdf"


def summarize_counts(rows: list[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for row in rows:
        status = row["download_status"]
        counts[status] = counts.get(status, 0) + 1
    return counts


def main() -> int:
    root = Path.cwd()
    bib_path = root / "writing" / "ref.bib"
    papers_dir = root / "papers"
    partials_dir = papers_dir / "partials"
    rejected_dir = papers_dir / "rejected"
    report_path = papers_dir / "download_report.csv"
    summary_path = papers_dir / "README.md"

    papers_dir.mkdir(parents=True, exist_ok=True)

    library = bibtexparser.loads(bib_path.read_text())
    local_index = load_local_literature_index()
    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})

    rows: list[dict] = []

    for index, entry in enumerate(library.entries, start=1):
        key = entry["ID"]
        title = entry.get("title", "")
        destination = papers_dir / build_filename(key)
        partial_path = partials_dir / build_filename(key)
        row = {
            "key": key,
            "entrytype": entry.get("ENTRYTYPE", ""),
            "title": title,
            "year": entry.get("year", ""),
            "download_status": "not_attempted",
            "file_path": "",
            "matched_title": "",
            "matched_year": "",
            "matched_type": "",
            "source_url": "",
            "source_host": "",
            "note": "",
        }

        if partial_path.exists() and partial_path.stat().st_size > 0 and not destination.exists():
            row["download_status"] = "partial_download"
            row["file_path"] = str(partial_path.relative_to(root))
            row["note"] = "known_partial_or_preview_kept_out_of_main_folder"
            rows.append(row)
            continue

        if destination.exists() and destination.stat().st_size > 0:
            quality_issue = pdf_quality_issue(entry, destination)
            if not quality_issue:
                row["download_status"] = "exists"
                row["file_path"] = str(destination.relative_to(root))
                row["note"] = "file_already_present"
                rows.append(row)
                continue
            archived = archive_invalid_pdf(destination, rejected_dir, key, quality_issue)
            row["note"] = f"removed_invalid_existing:{archived.relative_to(root)}"

        local_candidate = choose_local_candidate(entry, local_index)
        if local_candidate:
            local_path = Path(local_candidate["file"])
            shutil.copy2(local_path, destination)
            quality_issue = pdf_quality_issue(entry, destination)
            if not quality_issue:
                row["download_status"] = "local_library"
                row["file_path"] = str(destination.relative_to(root))
                row["matched_title"] = local_candidate.get("title", "")
                row["matched_year"] = local_candidate.get("year", "")
                row["matched_type"] = local_candidate.get("ENTRYTYPE", "")
                row["source_url"] = str(local_path)
                row["source_host"] = "local_literature"
                row["note"] = "local_exact_title_match"
                rows.append(row)
                print(f"[{index:02d}/{len(library.entries)}] {key}: {row['download_status']}", flush=True)
                continue
            archived = archive_invalid_pdf(destination, rejected_dir, key, quality_issue)
            row["note"] = f"rejected_local_candidate:{archived.relative_to(root)}"

        try:
            results = search_openalex(session, title)
            time.sleep(SEARCH_SLEEP_SECONDS)
        except Exception as exc:
            row["download_status"] = "search_failed"
            row["note"] = str(exc)
            rows.append(row)
            continue

        if not results:
            row["download_status"] = "no_match"
            row["note"] = "openalex_returned_no_results"
            rows.append(row)
            continue

        attempted_any = False
        for result, urls in choose_best_downloadable(entry, results):
            row["matched_title"] = result.get("title", "")
            row["matched_year"] = result.get("publication_year") or ""
            row["matched_type"] = result.get("type", "")
            for url, _kind in urls:
                attempted_any = True
                success, resolved_url, note = try_download_pdf(session, url, destination)
                if success:
                    quality_issue = pdf_quality_issue(entry, destination)
                    if quality_issue:
                        archived = archive_invalid_pdf(destination, rejected_dir, key, quality_issue)
                        row["note"] = f"rejected_download:{archived.relative_to(root)}"
                        continue
                    row["download_status"] = "downloaded"
                    row["file_path"] = str(destination.relative_to(root))
                    row["source_url"] = resolved_url or url
                    row["source_host"] = safe_host(resolved_url or url)
                    row["note"] = note
                    break
            if row["download_status"] == "downloaded":
                break

        if row["download_status"] != "downloaded":
            best = pick_results(entry, results)[0]
            row["matched_title"] = best.get("title", "")
            row["matched_year"] = best.get("publication_year") or ""
            row["matched_type"] = best.get("type", "")
            open_access = best.get("open_access") or {}
            if attempted_any:
                row["download_status"] = "matched_but_no_pdf"
                row["note"] = row["note"] or "candidate_urls_failed_to_download"
            elif open_access.get("is_oa"):
                row["download_status"] = "oa_without_url"
                row["note"] = "open_access_record_without_downloadable_url"
            else:
                row["download_status"] = "closed_or_unavailable"
                row["note"] = f"oa_status:{open_access.get('oa_status') or 'unknown'}"

        rows.append(row)
        print(f"[{index:02d}/{len(library.entries)}] {key}: {row['download_status']}", flush=True)

    with report_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "key",
                "entrytype",
                "title",
                "year",
                "download_status",
                "file_path",
                "matched_title",
                "matched_year",
                "matched_type",
                "source_url",
                "source_host",
                "note",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    counts = summarize_counts(rows)
    downloaded = counts.get("downloaded", 0) + counts.get("exists", 0) + counts.get("local_library", 0)
    rejected_count = len(list(rejected_dir.glob("*.pdf"))) if rejected_dir.exists() else 0
    partials_dir = papers_dir / "partials"
    partial_count = len(list(partials_dir.glob("*.pdf"))) if partials_dir.exists() else 0
    lines = [
        "# Papers Download Report",
        "",
        f"- Bib entries scanned: {len(rows)}",
        f"- Full PDFs in `papers/`: {downloaded}",
        f"- Partial/preview PDFs in `papers/partials/`: {partial_count}",
        f"- Rejected appendix/mismatch PDFs in `papers/rejected/`: {rejected_count}",
    ]
    for status in sorted(counts):
        lines.append(f"- {status}: {counts[status]}")
    lines.extend(
        [
            "",
            "See `download_report.csv` for the per-entry details.",
            "Only openly accessible PDFs were downloaded automatically.",
        ]
    )
    summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
