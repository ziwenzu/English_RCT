#!/usr/bin/env python3
"""
fetch_articles.py
Downloads full text of articles in materials_master_bank.csv.
Strategy:
  1. newspaper3k direct fetch
  2. If fails / too short → try Wayback Machine (archive.org CDX)
  3. Save to article_texts/{id}.txt with metadata header
"""

import csv, time, json, os, re, sys
import requests
from newspaper import Article
from datetime import datetime

BASE   = os.path.dirname(os.path.abspath(__file__))
BANK   = os.path.join(BASE, 'materials_master_bank.csv')
OUTDIR = os.path.join(BASE, 'article_texts')
os.makedirs(OUTDIR, exist_ok=True)

HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Safari/537.36'
    ),
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
}
MIN_WORDS = 150  # minimum word count to consider a fetch successful

# ── helpers ──────────────────────────────────────────────────────────────────

def fetch_newspaper(url):
    """Try newspaper3k extraction."""
    try:
        a = Article(url, language='en')
        a.download()
        a.parse()
        text = a.text.strip()
        if len(text.split()) >= MIN_WORDS:
            return text, 'newspaper3k'
    except Exception as e:
        pass
    return None, None


def fetch_wayback(url):
    """Try latest Wayback Machine snapshot."""
    cdx = f"https://archive.org/wayback/available?url={url}"
    try:
        r = requests.get(cdx, timeout=15)
        data = r.json()
        snap = data.get('archived_snapshots', {}).get('closest', {})
        if snap.get('available') and snap.get('url'):
            wb_url = snap['url']
            a = Article(wb_url, language='en')
            a.download()
            a.parse()
            text = a.text.strip()
            if len(text.split()) >= MIN_WORDS:
                return text, f"wayback:{snap['timestamp']}"
    except Exception:
        pass
    return None, None


def fetch_requests(url):
    """Plain requests + basic body extraction (last resort)."""
    try:
        r = requests.get(url, headers=HEADERS, timeout=20)
        if r.status_code == 200:
            # strip html tags
            clean = re.sub(r'<[^>]+>', ' ', r.text)
            clean = re.sub(r'\s+', ' ', clean).strip()
            words = clean.split()
            if len(words) >= MIN_WORDS:
                # take middle chunk (skip nav/footer)
                chunk = ' '.join(words[50:-100]) if len(words) > 200 else clean
                return chunk[:8000], 'requests_raw'
    except Exception:
        pass
    return None, None


# ── main ─────────────────────────────────────────────────────────────────────

with open(BANK, newline='', encoding='utf-8') as f:
    rows = list(csv.DictReader(f))

results = []
for i, row in enumerate(rows):
    article_id = row['id']
    url        = row['url']
    outpath    = os.path.join(OUTDIR, f"{article_id}.txt")

    # Skip if already downloaded
    if os.path.exists(outpath):
        word_count = len(open(outpath).read().split())
        if word_count >= MIN_WORDS:
            print(f"[{i+1:02d}/{len(rows)}] SKIP (exists, {word_count}w) {article_id}")
            results.append({'id': article_id, 'status': 'exists', 'words': word_count, 'method': 'cached'})
            continue

    print(f"[{i+1:02d}/{len(rows)}] Fetching {article_id}: {url[:70]}")

    text, method = fetch_newspaper(url)

    if not text:
        print(f"         → newspaper3k failed, trying Wayback...")
        text, method = fetch_wayback(url)

    if not text:
        print(f"         → Wayback failed, trying raw requests...")
        text, method = fetch_requests(url)

    if text:
        word_count = len(text.split())
        header = (
            f"ID: {article_id}\n"
            f"Bank: {row['bank']}\n"
            f"Source: {row['source']}\n"
            f"Title: {row['title']}\n"
            f"URL: {url}\n"
            f"Topic: {row['topic']}\n"
            f"Method: {method}\n"
            f"Words: {word_count}\n"
            f"Fetched: {datetime.now().isoformat()}\n"
            f"{'='*60}\n\n"
        )
        with open(outpath, 'w', encoding='utf-8') as f:
            f.write(header + text)
        print(f"         → OK  {word_count} words via {method}")
        results.append({'id': article_id, 'status': 'ok', 'words': word_count, 'method': method})
    else:
        print(f"         → FAILED — {article_id}")
        with open(outpath, 'w', encoding='utf-8') as f:
            f.write(f"ID: {article_id}\nURL: {url}\nSTATUS: FETCH_FAILED\n")
        results.append({'id': article_id, 'status': 'failed', 'words': 0, 'method': 'none'})

    time.sleep(1.5)  # be polite

# ── summary ──────────────────────────────────────────────────────────────────
ok      = [r for r in results if r['status'] in ('ok', 'exists')]
failed  = [r for r in results if r['status'] == 'failed']
methods = {}
for r in ok:
    methods[r['method']] = methods.get(r['method'], 0) + 1

print(f"\n{'='*50}")
print(f"Total:  {len(rows)}")
print(f"OK:     {len(ok)}  ({100*len(ok)/len(rows):.0f}%)")
print(f"Failed: {len(failed)}")
print(f"Methods: {methods}")
if failed:
    print(f"Failed IDs: {[r['id'] for r in failed]}")

# Save manifest
manifest_path = os.path.join(OUTDIR, '_manifest.json')
with open(manifest_path, 'w') as f:
    json.dump(results, f, indent=2)
print(f"Manifest saved to {manifest_path}")
