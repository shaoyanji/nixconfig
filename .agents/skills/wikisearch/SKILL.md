---
name: wikisearch
description: "Offline Wikipedia/Kiwix search on frieren: `wikisearch` for a title, `wiki-ask` for a gated, section-level answer an agent can afford."
version: 0.2.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['wikisearch', 'kiwix', 'wikipedia', 'search']
    related_skills: []
---

# `wikisearch` — Universal Kiwix & Offline Wiki Search Runbook

A fast, low-overhead offline knowledge retrieval system using Kiwix and embedded Xapian BM25 indices on `frieren.lan`.

---

## 1. System Overview

* **Host:** `frieren.lan` (serves the entire LAN and Tailscale mesh).
* **Package Definition:** Defined via `pkgs.writeShellApplication` in `hosts/frieren/tools.nix` in `nixconfig`.
* **Data Directory:** `/var/lib/kiwix/` (moved from `~/wikipedia-offline` 2026-10-08 — the native `services.kiwix-serve` module runs with DynamicUser + ProtectHome, which cannot read `/home`). Holds `library.xml`, metadata stamps, and supplementary local archives (e.g. `wikipedia_en_top_mini`); the full 52 GB Wikipedia ZIM and ArchWiki ZIM live **only** as GC-rooted `/nix/store` paths (local copy reclaimed 2026-10-08 — nix verified its hash at import).
* **Library Manifest:** `/var/lib/kiwix/library.xml` (kept in sync from the declarative store copy by the `kiwix-library` activation script on every boot/switch — NOT tmpfiles, whose `C+` rule never overwrites an existing file)
* **HTTP Daemon:** `kiwix-serve.service` (native NixOS `services.kiwix-serve`, declared in `modules/services/kiwix.nix`) on port `8088` with `-M` auto-reload; nginx reverse proxy at `http://wiki.frieren.lan`.
* **Library:** declarative — ZIMs are store paths / fetchurl entries in `modules/services/kiwix.nix`; add a new wiki there (use `nurl <url>` for the hash), never via kiwix-manage.

---

## 2. CLI Usage (`wikisearch`)

Two entry points, one index. `wikisearch` is what an operator types; `wiki-ask`
is what an agent calls.

### 0. Ask a question — `wiki-ask` (pick this first)

```bash
task ops:wiki:ask Q="btrfs scrub repair EIO"            # TOON, gated
task ops:wiki:ask Q="how to configure niri" FORMAT=json  # wire format
```

Fan-out over every archive, fused by reciprocal rank, gated at **0.62 / 0.38**:
`answer` quotes two sections, `expand` one, below that it **abstains and spends
zero tokens**. Verdicts append to `~/.local/state/wiki-ask/verdicts.jsonl`.

Why not `wikisearch`: Xapian ANDs its terms, so a real question returns nothing,
and results are titles with no text. Measured on frieren 2026-11-04:

| query | `wikisearch` | `wiki-ask` |
| :--- | :--- | :--- |
| `btrfs scrub repair EIO` | one hit, **F2FS** | Btrfs → "Checking and recovery", ~250 tokens |
| `systemd 203/EXEC failed unit` | `List of TCP and UDP port numbers` | Systemd + Systemd/Sandboxing |
| `how to configure niri window manager` | (titles only) | Niri → its config binding section |

A quote is the **best-matching section**, heading included, never the lead: the
lead is what a summary is, the section is what an answer is. `--budget N` caps
the tokens (default 1200), `--archive <substring>` narrows the fan-out.

**Abstention is the feature.** A below-0.38 verdict returns titles and no text,
which is the honest answer when the archives do not cover the question — quote
such a result as `verdict: abstain`, never as a fact.

`wikisearch` is still right for: listing archives, resolving one exact title,
and a human reading the served page. Run `wiki-ask` from frieren, or ssh first.

---

`wikisearch` is a universal CLI client that queries any ZIM archive in the library or directory.

### A. Full-Text Search
Searches the primary archive — with no `-w`, `find_zim` resolves against the declarative library first, so the default is the full English Wikipedia (19.2M articles):
```bash
wikisearch "quantum computing"
wikisearch "James Webb Space Telescope"
```

### B. Targeting a Specific Wiki Archive (`-w`, `--wiki`)
Resolution order: declarative library paths (store ZIMs) → local files in
`/var/lib/kiwix` → error. Match is a case-insensitive substring of the path:
```bash
# Full Wikipedia (library store path)
wikisearch -w wikipedia "Alan Turing"

# ArchWiki (library store path)
wikisearch -w arch "systemd-boot"

# Local-only archive in /var/lib/kiwix
wikisearch -w top "Alan Turing"
```

### C. List Available Archives (`-l`, `--list`)
Inspect all registered wikis, article counts, filenames, and IDs:
```bash
wikisearch --list
```

### D. Autocomplete / Title Prefix Search (`-s`, `--suggest`)
Find exact article title matches:
```bash
wikisearch -s "Antigrav"
```

### E. Resolve Direct Article URLs (`-u`, `--url`)
Outputs full HTTP URLs to the web reader:
```bash
wikisearch -u "relativity"
```

### F. Status & Diagnostics (`--status`)
Inspect the running `kiwix-serve` daemon, archive paths, and background services:
```bash
wikisearch --status
```

---

## 3. Adding Any New Wiki Archive to Kiwix (Universal Shape)

To expand the knowledge base with any new wiki (e.g. Wikivoyage, DevDocs, ArchWiki, StackExchange, PubMed):

### Step 1: Add the ZIM declaratively
Add a `fetchurl` entry to `zims` in `modules/services/kiwix.nix` (use `nurl <url>`
for the hash) and add it to the `kiwix-manage`-equivalent book list in the
`kiwixLibrary` writeText. Rebuild — `kiwix-manage` is no longer used manually.

### Step 2: Add it to the declarative library
Append a matching book entry to the `kiwixLibrary` writeText in the same file
(id can be any unique UUID; `articleCount`/`size` are display-only). Never run
`kiwix-manage` by hand — the declarative library.xml overwrites it.

### Step 3: Automatic Hot-Reload
`kiwix-serve.service` runs with the `-M` flag, which watches `library.xml` and reloads immediately without restarting or dropping connections.

### Step 4: Verify and Query Immediately
```bash
# Confirm both declared archives (Wikipedia + ArchWiki) are served:
wikisearch --list

# Query the new wiki by name substring:
wikisearch -w "<archive_keyword>" "<search query>"
```

---

## 4. Querying from Remote Clients (e.g. `netbook`)

### A. Via SSH Wrapper
On `netbook`, `~/.local/bin/wikisearch` transparently proxies queries over SSH to `frieren.lan`:
```bash
wikisearch "Okapi BM25"
wikisearch -w top "Ada Lovelace"
```

### B. Via HTTP API
Any client on the LAN or Tailscale network can query Kiwix directly:
```bash
# Search across all books:
curl -s "http://frieren.lan:8088/search?pattern=quantum"

# Autocomplete suggestions:
curl -s "http://frieren.lan:8088/suggest?term=Anti"

# Interactive Web Reader:
http://frieren.lan:8088/
```
