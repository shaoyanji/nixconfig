---
name: wiki-decision-recommend
description: Offline article and technical manual recommendations powered by System One decision models (Julia-1 and Laya) linked to Kiwix offline knowledge bases. Classifies technical incidents and gates article retrieval based on calibrated confidence thresholds.
---

# Wiki Decision Recommender

An intelligent offline knowledge retrieval skill combining **System One decision models** (`julia-1` / `laya`) with **Kiwix offline knowledge libraries** (`archlinux_en_all`, `wikipedia_en_all`) hosted on `frieren` at `http://wiki.frieren.lan/`.

## Architecture & Threshold Gating
1. **Incident Domain Classification (`choice` / `classify`):**
   Evaluates error messages or technical inquiries across domains: `filesystem_storage`, `database_systems`, `network_dns_tls`, `linux_kernel_systemd`, `nixos_declarative`.
2. **Calibrated Confidence Threshold (`noul`):**
   Only triggers article retrieval when classification confidence satisfies the calibrated threshold (default: 0.65). Suppresses spurious recommendations when uncertainty is high.
3. **Target ZIM Routing (`route`):**
   Directs queries to the optimal offline ZIM archive (ArchWiki technical guides vs. Wikipedia broad overviews).
4. **Sub-second Article Retrieval:**
   Queries Kiwix REST search (`http://127.0.0.1:8088`), filters English articles, and formats clickable local URLs.

## Usage Guide

```bash
# Recommend articles for a Btrfs incident
~/.agents/skills/wiki-decision-recommend/scripts/wiki-recommend.sh "Btrfs silent corruption checksum error detected during scrub"

# Custom threshold gating with Laya model
~/.agents/skills/wiki-decision-recommend/scripts/wiki-recommend.sh "PostgreSQL pgvector vacuum compaction" --model laya --threshold 0.75
```

Truth: `scripts/task/systemone.sh` (`task ops:decide`) — the engine call; this page is the judgment.
