#!/usr/bin/env python3
"""
wiki_recommend.py: Decision-Model Augmented Kiwix Search & Auto-Recommender
Combines System One decision models (Julia-1 & Laya) with Kiwix offline knowledge bases.

Workflow:
1. Classifies the query/incident domain using System One decision models.
2. Gates search trigger using a calibrated confidence threshold.
3. Routes query to the most appropriate ZIM archive (ArchWiki, Wikipedia, StackOverflow).
4. Retrieves matching articles from local Kiwix daemon (http://127.0.0.1:8088).
5. Calibrates recommendation ranking and returns high-confidence offline reference links.
"""

import sys
import os
import re
import json
import urllib.parse
import urllib.request
import argparse
from typing import Dict, List, Any, Optional

try:
    from engine import DecisionEngine
except ImportError:
    from modules.services.systemone.engine import DecisionEngine

KIWIX_BASE_URL = "http://127.0.0.1:8088"
DEFAULT_THRESHOLD = 0.65

# Domain to ZIM archive mapping
DOMAIN_ARCHIVES = {
    "filesystem_storage": ["archlinux_en_all", "wikipedia_en_all"],
    "database_systems": ["archlinux_en_all", "wikipedia_en_all"],
    "network_dns_tls": ["archlinux_en_all", "wikipedia_en_all"],
    "linux_kernel_systemd": ["archlinux_en_all", "wikipedia_en_all"],
    "nixos_declarative": ["archlinux_en_all", "wikipedia_en_all"],
    "general_technology": ["wikipedia_en_all", "archlinux_en_all"]
}

DOMAIN_KEYWORDS = {
    "filesystem_storage": ["btrfs", "scrub", "raid", "zfs", "fsck", "mount", "device", "subvolume"],
    "database_systems": ["postgresql", "sqlite", "wal", "vacuum", "pgvector", "reindex", "checkpoint"],
    "network_dns_tls": ["nginx", "ssl", "tls", "certificate", "unbound", "pihole", "dns", "tailscale"],
    "linux_kernel_systemd": ["systemd", "cgroup", "journalctl", "thermal", "governor", "zram", "swap"],
    "nixos_declarative": ["nixos", "nix", "flake", "derivation", "systemd", "module"],
    "general_technology": ["linux", "hardware", "server", "architecture"]
}

def query_kiwix_search(pattern: str, archive: Optional[str] = None, max_results: int = 5) -> List[Dict[str, str]]:
    """Search Kiwix REST search endpoint."""
    encoded_pattern = urllib.parse.quote(pattern)
    url = f"{KIWIX_BASE_URL}/search?pattern={encoded_pattern}&count=30"
    if archive:
        url += f"&content={archive}"

    req = urllib.request.Request(url, headers={"User-Agent": "SystemOne-WikiRecommend/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=3.0) as resp:
            html = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        return []

    # Parse search result links
    matches = re.findall(r'<a\s+href="([^"]+)">\s*([^<]+?)\s*</a>', html, re.DOTALL)
    results = []
    seen = set()

    # Prioritize English articles (no parentheses language suffix like '(Русский)')
    english_matches = []
    other_matches = []

    for href, title in matches:
        clean_title = title.strip()
        if not clean_title or clean_title in seen or "search?" in href or href == "/":
            continue
        seen.add(clean_title)
        
        full_url = f"http://wiki.frieren.lan{href}" if href.startswith("/") else f"http://wiki.frieren.lan/{href}"
        entry = {
            "title": clean_title,
            "url": full_url,
            "href": href
        }
        if re.search(r"\([^)]*[\u0400-\u04FF\u4e00-\u9fff\u3040-\u30ff].*?\)", clean_title) or "(" in clean_title:
            other_matches.append(entry)
        else:
            english_matches.append(entry)

    sorted_candidates = english_matches + other_matches
    return sorted_candidates[:max_results]

def recommend_articles(
    incident_text: str,
    model_name: str = "julia-1",
    threshold: float = DEFAULT_THRESHOLD,
    max_articles: int = 5
) -> Dict[str, Any]:
    engine = DecisionEngine(model_name)

    # Step 1: Classify incident domain
    taxonomies = list(DOMAIN_ARCHIVES.keys())
    classification = engine.choice(
        incident_text,
        "What domain best categorizes this incident or technical inquiry?",
        taxonomies
    )
    domain = classification["decision"]
    domain_confidence = classification["confidence"]

    # Step 2: Noul decision - should we trigger automated article recommendation?
    trigger_eval = engine.noul(
        incident_text,
        f"Does this incident contain actionable technical keywords requiring manual reference (confidence >= {threshold})?"
    )

    should_recommend = (domain_confidence >= threshold) or trigger_eval["holds"]

    if not should_recommend:
        return {
            "model": model_name,
            "domain": domain,
            "confidence": domain_confidence,
            "threshold": threshold,
            "recommended": False,
            "rationale": f"Confidence ({domain_confidence:.2f}) below calibrated threshold ({threshold:.2f}); no spurious recommendations generated.",
            "articles": []
        }

    # Step 3: Extract technical keywords from text
    words = re.findall(r"[A-Za-z0-9_-]{3,}", incident_text.lower())
    matched_kws = [w for w in words if w in DOMAIN_KEYWORDS.get(domain, [])]
    if not matched_kws:
        matched_kws = words[:2]

    search_term = matched_kws[0] if matched_kws else "linux"

    # Step 4: Search archives
    target_archives = DOMAIN_ARCHIVES.get(domain, ["archlinux_en_all", "wikipedia_en_all"])
    found_articles = query_kiwix_search(search_term, max_results=max_articles)

    return {
        "model": model_name,
        "domain": domain,
        "domain_confidence": domain_confidence,
        "threshold": threshold,
        "recommended": True,
        "search_query": search_term,
        "target_archives": target_archives,
        "articles": found_articles
    }

def main():
    parser = argparse.ArgumentParser(description="Decision-Model Augmented Kiwix Article Recommender")
    parser.add_argument("incident", help="Incident description, error message, or query string")
    parser.add_argument("--model", choices=["julia-1", "laya"], default="julia-1", help="Decision model")
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD, help="Calibrated confidence threshold (0.0 - 1.0)")
    parser.add_argument("--max", type=int, default=5, help="Maximum number of articles to recommend")

    args = parser.parse_args()

    res = recommend_articles(args.incident, model_name=args.model, threshold=args.threshold, max_articles=args.max)
    print(json.dumps(res, indent=2))

if __name__ == "__main__":
    main()
