from __future__ import annotations

import csv
import html
import re
import shutil
from datetime import datetime
from pathlib import Path
from typing import Dict, Iterable, Optional

import requests
from bs4 import BeautifulSoup


PROJECT_ROOT = Path(
    "/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT"
)
RAW_DIR = PROJECT_ROOT / "teaching" / "article_texts"
SUPPLEMENTAL_MD_DIR = RAW_DIR
MATERIALS_CSV = PROJECT_ROOT / "teaching" / "materials_master_bank.csv"
BACKUP_PARENT = PROJECT_ROOT / "teaching" / "_article_texts_backups"


USER_AGENT = "Mozilla/5.0"


IMPORT_MAP: Dict[str, Dict[str, str]] = {
    "China unleashes boldest stimulus in years to boost ailing economy.md": {
        "id": "PRO_001",
        "source": "The Guardian",
        "title": "China unleashes boldest stimulus in years to boost ailing economy",
        "url": "https://www.theguardian.com/world/2024/sep/24/china-economy-stimulus-package-measures-yuan-pbc",
        "topic": "macroeconomic stimulus and growth support",
        "notes": "Imported from user-supplied markdown supplement and replaced an outdated PRO article.",
    },
    "China announces new measures to arrest housing slump and boost growth.md": {
        "id": "PRO_003",
        "source": "The Guardian",
        "title": "China announces new measures to arrest housing slump and boost growth",
        "url": "https://www.theguardian.com/world/2024/sep/26/china-new-measures-housing-slump-growth",
        "topic": "housing support and growth stabilization",
        "notes": "Imported from user-supplied markdown supplement and replaced a post-experiment PRO article.",
    },
    "China building two-thirds of world’s wind and solar projects.md": {
        "id": "PRO_006",
        "source": "The Guardian",
        "title": "China building two-thirds of world’s wind and solar projects",
        "url": "https://www.theguardian.com/world/article/2024/jul/11/china-building-twice-as-much-wind-and-solar-power-as-rest-of-world-report",
        "topic": "clean energy buildout and industrial policy",
        "notes": "Imported from user-supplied markdown supplement and replaced a post-experiment PRO article.",
    },
    "China’s economy expands 5% in 2024, hitting target helped by strong exports, stimulus measures.md": {
        "id": "PRO_009",
        "source": "AP News",
        "title": "China’s economy expands 5% in 2024, hitting target helped by strong exports, stimulus measures",
        "url": "https://apnews.com/article/china-economy-gdp-exports-stimulus-7ae30cf2b48fa82c8e4feeee85483846",
        "topic": "growth target achievement and macro performance",
        "notes": "Imported from user-supplied markdown supplement and replaced a thin Reuters PRO article.",
    },
    "Top Chinese official says green, high tech development key as nation seeks to spur economy.md": {
        "id": "PRO_010",
        "source": "AP News",
        "title": "Top Chinese official says green, high tech development key as nation seeks to spur economy",
        "url": "https://apnews.com/article/china-economy-boao-conference-c12ae124e66bfda239883fc02f517809",
        "topic": "high-tech and green development strategy",
        "notes": "Imported from user-supplied markdown supplement and replaced a post-experiment PRO article.",
    },
    "China built out record amount of wind and solar power in 2024.md": {
        "id": "PRO_012",
        "source": "AP News",
        "title": "China built out record amount of wind and solar power in 2024",
        "url": "https://apnews.com/article/wind-solar-energy-china-climate-carbon-emissions-b337503abfacfd9b7829fd7bbcd507e9",
        "topic": "renewable energy expansion",
        "notes": "Imported from user-supplied markdown supplement and replaced a post-experiment PRO article.",
    },
    "World Bank lifts China growth forecasts but calls for deeper reforms.md": {
        "id": "PRO_014",
        "source": "The Guardian",
        "title": "World Bank lifts China growth forecasts but calls for deeper reforms",
        "url": "https://www.theguardian.com/business/2024/dec/26/world-bank-lifts-china-growth-forecasts-economy-property-crisis",
        "topic": "growth forecasts and reform agenda",
        "notes": "Imported from user-supplied markdown supplement and replaced a thin Reuters PRO article.",
    },
    "Clean energy contributed 10% to China’s GDP in 2024, analysis shows.md": {
        "id": "PRO_015",
        "source": "The Guardian",
        "title": "Clean energy contributed 10% to China’s GDP in 2024, analysis shows",
        "url": "https://www.theguardian.com/world/2025/feb/19/clean-energy-contributed-10-to-chinas-gdp-in-2024-analysis-shows",
        "topic": "clean energy contribution to growth",
        "notes": "Imported from user-supplied markdown supplement and replaced a thin Reuters PRO article.",
    },
    "China to head green energy boom with 60% of new projects in next six years.md": {
        "id": "PRO_021",
        "source": "The Guardian",
        "title": "China to head green energy boom with 60% of new projects in next six years",
        "url": "https://www.theguardian.com/environment/2024/oct/09/china-to-head-green-energy-boom-with-60-of-new-projects-in-next-six-years",
        "topic": "green energy leadership",
        "notes": "Imported from user-supplied markdown supplement and replaced a post-experiment PRO article.",
    },
    "How China’s internet police went from targeting bloggers to their followers.md": {
        "id": "ANTI_005",
        "source": "The Guardian",
        "title": "How China’s internet police went from targeting bloggers to their followers",
        "url": "https://www.theguardian.com/world/article/2024/sep/02/how-chinas-internet-police-went-from-targeting-bloggers-to-their-followers",
        "topic": "surveillance and online repression",
        "notes": "Imported from user-supplied markdown supplement and replaced a weak ANTI article.",
    },
    "China cracks down on ‘uncivilised’ online puns used to discuss sensitive topics.md": {
        "id": "ANTI_010",
        "source": "The Guardian",
        "title": "China cracks down on ‘uncivilised’ online puns used to discuss sensitive topics",
        "url": "https://www.theguardian.com/world/2024/oct/23/china-meme-online-pun-crackdown-rules",
        "topic": "online censorship and speech controls",
        "notes": "Imported from user-supplied markdown supplement and replaced an older ANTI article.",
    },
    "China new home prices drop at fastest rate in nearly a decade.md": {
        "id": "ANTI_014",
        "source": "The Guardian",
        "title": "China new home prices drop at fastest rate in nearly a decade",
        "url": "https://www.theguardian.com/business/article/2024/jun/17/china-new-home-prices-fall-property-market",
        "topic": "property market decline",
        "notes": "Imported from user-supplied markdown supplement and replaced an older ANTI article.",
    },
    "‘It’s legalised robbery’ anger grows at China’s struggling shadow banks.md": {
        "id": "ANTI_023",
        "source": "The Guardian",
        "title": "‘It’s legalised robbery’: anger grows at China’s struggling shadow banks",
        "url": "https://www.theguardian.com/business/2024/feb/18/anger-grows-at-china-struggling-shadow-banks",
        "topic": "financial distress and public anger",
        "notes": "Imported from user-supplied markdown supplement and replaced an older ANTI article.",
    },
    "A family recipe for Shanghai wontons.md": {
        "id": "APOL_002",
        "source": "BBC Travel",
        "title": "A family recipe for Shanghai wontons",
        "url": "https://www.bbc.com/travel/article/20230529-a-family-recipe-for-shanghai-wontons",
        "topic": "food culture and family traditions",
        "notes": "Imported from user-supplied markdown supplement and replaced a weak APOL article.",
    },
    "‘I eat to understand’ cook and writer Fuchsia Dunlop on her lifelong love of Chinese cuisine.md": {
        "id": "APOL_009",
        "source": "The Guardian",
        "title": "‘I eat to understand’: cook and writer Fuchsia Dunlop on her lifelong love of Chinese cuisine",
        "url": "https://www.theguardian.com/food/2023/aug/20/i-eat-to-understand-cook-and-writer-fuchsia-dunlop-on-her-lifelong-love-of-chinese-cuisine",
        "topic": "Chinese food culture and culinary writing",
        "notes": "Imported from user-supplied markdown supplement and replaced a weak APOL article.",
    },
    "Tiger testicles and mythical banquets What China’s emperors inside Beijing’s secretive Forbidden City really ate.md": {
        "id": "APOL_012",
        "source": "CNN Travel",
        "title": "Tiger testicles and mythical banquets: What China’s emperors inside Beijing’s secretive Forbidden City really ate",
        "url": "https://www.cnn.com/travel/china-emperors-food-beijing-forbidden-city-intl-hnk",
        "topic": "imperial food history and palace culture",
        "notes": "Imported from user-supplied markdown supplement and replaced an outdated APOL article.",
    },
    "A local’s guide to Maastricht, Netherlands the best bars, culture and hotels.md": {
        "id": "CTRL_001",
        "source": "The Guardian",
        "title": "A local’s guide to Maastricht, Netherlands: the best bars, culture and hotels",
        "url": "https://www.theguardian.com/travel/2024/feb/09/a-locals-guide-to-maastricht-netherlands-the-best-bars-culture-and-hotels",
        "topic": "city culture and neighborhood life",
        "notes": "Imported from user-supplied markdown supplement and replaced a weak control article.",
    },
    "‘No pickles No deli’ archetypal American ‘secular Jewish space’ gains due regard.md": {
        "id": "CTRL_022",
        "source": "The Guardian",
        "title": "‘No pickles? No deli’: archetypal American ‘secular Jewish space’ gains due regard",
        "url": "https://www.theguardian.com/artanddesign/article/2024/may/23/jewish-deli-exhibit-washington-dc-museum",
        "topic": "museum culture and food history",
        "notes": "Imported from user-supplied markdown supplement and replaced a weak control article.",
    },
    "Ancient monuments and new art inside Brescia, Italy's latest capital of culture.md": {
        "id": "CTRL_023",
        "source": "National Geographic",
        "title": "Ancient monuments and new art: inside Brescia, Italy's latest capital of culture",
        "url": "https://www.nationalgeographic.com/travel/article/ancient-monuments-and-new-art-inside-brescia-italys-latest-capital-of-culture",
        "topic": "art, monuments, and city culture",
        "notes": "Imported from user-supplied markdown supplement and replaced a weak control article.",
    },
    "A true multi-sensory experience’ the Met celebrates Japanese poetry, calligraphy and painting.md": {
        "id": "CTRL_024",
        "source": "The Guardian",
        "title": "A true multi-sensory experience: the Met celebrates Japanese poetry, calligraphy and painting",
        "url": "https://www.theguardian.com/artanddesign/article/2024/aug/12/metropolitan-museum-japanese-art-exhibit",
        "topic": "museum exhibit and Japanese art",
        "notes": "Imported from user-supplied markdown supplement and replaced a weak control article.",
    },
}


FETCH_MAP: Dict[str, Dict[str, str]] = {
    "PRO_005": {
        "source": "AP News",
        "title": "China sticks to an economic growth target of 'around 5%' despite a looming trade war with US",
        "url": "https://apnews.com/article/d6192774e13ccb7e28e06d4c3f2173c4",
        "topic": "growth target and macro stabilization",
        "notes": "Fetched automatically as a longer replacement for a missing PRO article.",
    },
    "PRO_015": {
        "source": "AP News",
        "title": "China approves $840B plan to refinance local government debt, boost slowing economy",
        "url": "https://apnews.com/article/d3ba981eb1fb9894fa9e8a08ffac40ee",
        "topic": "debt refinancing and economic support",
        "notes": "Fetched automatically as a longer replacement for a short PRO article.",
    },
    "ANTI_010": {
        "source": "AP News",
        "title": "Chinese hacking documents offer glimpse into state surveillance",
        "url": "https://apnews.com/article/china-cybersecurity-leak-document-dump-spying-aac38c75f268b72910a94881ccbb77cb",
        "topic": "state surveillance and cyber repression",
        "notes": "Fetched automatically as a longer replacement for a short ANTI article.",
    },
    "ANTI_020": {
        "source": "AP News",
        "title": "China Evergrande has been ordered to liquidate. The real estate giant owes over $300 billion",
        "url": "https://apnews.com/article/china-evergrande-property-liquidation-order-7965ab1ec2f0208c53f9298daf8b9fd0",
        "topic": "property crisis and corporate collapse",
        "notes": "Fetched automatically as a longer replacement for a missing ANTI article.",
    },
}


def backup_raw_dir() -> Path:
    BACKUP_PARENT.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = BACKUP_PARENT / f"article_texts_{timestamp}"
    shutil.copytree(RAW_DIR, backup_dir)
    return backup_dir


def strip_markdown_and_html(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"^#\s+", "", text, flags=re.M)
    text = re.sub(r"!\[[^\]]*\]\([^)]+\)", "", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1", text)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    drop_patterns = [
        r"^This article is more than .* old$",
        r"^Prefer the Guardian on Google$",
        r"^Updated .*",
        r"^By [A-Z].*",
        r"^\[.*\]$",
    ]
    cleaned_lines = []
    for line in text.split("\n"):
        line = line.strip()
        if not line:
            cleaned_lines.append("")
            continue
        if any(re.match(pat, line) for pat in drop_patterns):
            continue
        if re.fullmatch(r"[A-Za-z0-9 ,.'’:;!?()/-]{1,80}", line) and "EDT" in line:
            continue
        cleaned_lines.append(line)
    text = "\n".join(cleaned_lines)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip() + "\n"


def extract_pub_date(text: str) -> str:
    patterns = [
        r"\b(\d{4}-\d{2}-\d{2})\b",
        r"\b([A-Z][a-z]{2,8} \d{1,2}, \d{4})\b",
        r"\b(\d{1,2} [A-Z][a-z]{2,8} \d{4})\b",
        r"\b([A-Z][a-z]{2} \d{1,2} \d{4})\b",
    ]
    for pat in patterns:
        m = re.search(pat, text)
        if not m:
            continue
        raw = m.group(1)
        for fmt in ("%Y-%m-%d", "%B %d, %Y", "%d %B %Y", "%b %d %Y"):
            try:
                return datetime.strptime(raw, fmt).strftime("%Y-%m-%d")
            except ValueError:
                pass
    return ""


def write_txt(item: Dict[str, str], body: str) -> None:
    path = RAW_DIR / f"{item['id']}.txt"
    pub_date = item.get("pub_date", "")
    header = [
        f"ID: {item['id']}",
        f"Bank: {item['bank']}",
        f"Source: {item['source']}",
        f"Title: {item['title']}",
        f"Publication date: {pub_date}",
        f"URL: {item['url']}",
        "",
    ]
    path.write_text("\n".join(header) + body.strip() + "\n", encoding="utf-8")


def fetch_article_text(url: str) -> str:
    response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=30)
    response.raise_for_status()
    raw_html = response.text
    try:
        import trafilatura  # type: ignore

        extracted = trafilatura.extract(
            raw_html,
            include_links=False,
            include_images=False,
            include_formatting=False,
        )
        if extracted and len(extracted.split()) > 300:
            return extracted.strip() + "\n"
    except Exception:
        pass

    soup = BeautifulSoup(raw_html, "html.parser")
    for tag in soup(["script", "style", "noscript", "svg", "figure", "aside", "nav", "footer", "header"]):
        tag.decompose()
    text = soup.get_text("\n")
    text = strip_markdown_and_html(text)
    return text


def update_materials_bank(updates: Dict[str, Dict[str, str]]) -> None:
    with MATERIALS_CSV.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
        fieldnames = rows[0].keys()

    for row in rows:
        update = updates.get(row["id"])
        if not update:
            continue
        row["source"] = update["source"]
        row["title"] = update["title"]
        row["url"] = update["url"]
        row["topic"] = update["topic"]
        row["final_status"] = "screened_from_search"
        row["notes"] = update["notes"]
        row["source_ok"] = "yes"
        row["china_focus_ok"] = "yes" if row["bank"] != "NONCHINA_CONTROL" else "no"
        row["valence_ok"] = "yes"
        row["taboo_screen_ok"] = "yes"
        row["format_ok"] = "yes"

    with MATERIALS_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def import_supplemental_md() -> Iterable[str]:
    imported = []
    for filename, meta in IMPORT_MAP.items():
        path = SUPPLEMENTAL_MD_DIR / filename
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        body = strip_markdown_and_html(text)
        item = {"bank": meta["id"].split("_")[0] if False else "", **meta}
        item["bank"] = infer_bank(meta["id"])
        item["pub_date"] = extract_pub_date(text)
        write_txt(item, body)
        imported.append(meta["id"])
    return imported


def infer_bank(article_id: str) -> str:
    if article_id.startswith("PRO"):
        return "PRO"
    if article_id.startswith("ANTI"):
        return "ANTI"
    if article_id.startswith("APOL"):
        return "APOL_CHINA"
    return "NONCHINA_CONTROL"


def fetch_missing_articles() -> Iterable[str]:
    fetched = []
    for article_id, meta in FETCH_MAP.items():
        body = fetch_article_text(meta["url"])
        item = {"id": article_id, "bank": infer_bank(article_id), **meta}
        item["pub_date"] = extract_pub_date(body)
        if not item["pub_date"]:
            response = requests.get(meta["url"], headers={"User-Agent": USER_AGENT}, timeout=30)
            soup = BeautifulSoup(response.text, "html.parser")
            for prop in ("article:published_time", "og:article:published_time"):
                tag = soup.find("meta", attrs={"property": prop})
                if tag and tag.get("content"):
                    item["pub_date"] = tag["content"][:10]
                    break
        write_txt(item, body)
        fetched.append(article_id)
    return fetched


def main() -> None:
    backup_dir = backup_raw_dir()
    imported = list(import_supplemental_md())
    fetched = list(fetch_missing_articles())
    all_updates = {meta["id"]: meta for meta in IMPORT_MAP.values()}
    all_updates.update(FETCH_MAP)
    update_materials_bank(all_updates)
    print(f"Backup created at: {backup_dir}")
    print("Imported IDs:", ", ".join(sorted(imported)) if imported else "(none)")
    print("Fetched IDs:", ", ".join(sorted(fetched)) if fetched else "(none)")


if __name__ == "__main__":
    main()
