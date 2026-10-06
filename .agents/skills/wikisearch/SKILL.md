---
name: wikisearch
description: >-
  Use this skill to query, search, and manage offline Wikipedia and any Kiwix-served
  ZIM knowledge archives on frieren.lan using native BM25 ranking and Kiwix tools.
---

# `wikisearch` — Universal Kiwix & Offline Wiki Search Runbook

A fast, low-overhead offline knowledge retrieval system using Kiwix and embedded Xapian BM25 indices on `frieren.lan`.

---

## 1. System Overview

* **Host:** `frieren.lan` (serves the entire LAN and Tailscale mesh).
* **Package Definition:** Defined via `pkgs.writeShellApplication` in `hosts/frieren/tools.nix` in `nixconfig`.
* **Data Directory:** `/home/devji/wikipedia-offline/`
* **Library Manifest:** `/home/devji/wikipedia-offline/library.xml`
* **HTTP Daemon:** `kiwix-serve.service` running on port `8088` with `-M` auto-reload.

---

## 2. CLI Usage (`wikisearch`)

`wikisearch` is a universal CLI client that queries any ZIM archive in the library or directory.

### A. Full-Text BM25 Search
Searches the default or primary archive (e.g. English Wikipedia full 50GB archive with 19.2M articles):
```bash
wikisearch "quantum computing"
wikisearch "James Webb Space Telescope"
```

### B. Targeting a Specific Wiki Archive (`-w`, `--wiki`)
Any ZIM archive in the library or directory can be queried by name, title, or filename:
```bash
# Query the "Best of Wikipedia" (top 50k articles) archive
wikisearch -w top "Alan Turing"

# Query other wikis by substring (e.g. archlinux, stackoverflow, wiktionary, devdocs)
wikisearch -w arch "systemd-boot"
wikisearch -w stackoverflow "python list comprehension"
wikisearch -w wiktionary "serendipity"
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

### Step 1: Download the ZIM Archive
Choose an archive from [Kiwix Downloads](https://download.kiwix.org/zim/) and download with resume support via `aria2c`:
```bash
aria2c -c -s 8 -x 8 -d /home/devji/wikipedia-offline "https://download.kiwix.org/zim/other/<archive_name>.zim"
```

### Step 2: Register in Kiwix Library
```bash
kiwix-manage /home/devji/wikipedia-offline/library.xml add /home/devji/wikipedia-offline/<archive_name>.zim
```

### Step 3: Automatic Hot-Reload
`kiwix-serve.service` runs with the `-M` flag, which watches `library.xml` and reloads immediately without restarting or dropping connections.

### Step 4: Verify and Query Immediately
```bash
# Confirm the new wiki appears in the library:
wikisearch --list

# Query the new wiki:
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
