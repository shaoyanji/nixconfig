---
name: wikisearch
description: "Offline Wikipedia/Kiwix search on frieren: `wikisearch` for a title, `wiki-ask` for a gated, section-level answer an agent can afford."
version: 0.3.0
author: Shaoyan Ji (shaoyanji), Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['wikisearch', 'kiwix', 'wikipedia', 'search']
    related_skills: []
---

# `wikisearch` — universal Kiwix & offline wiki search runbook

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
| `btrfs scrub repair EIO` | one hit, **F2FS** | `answer`, Btrfs → "Checking and recovery", 250 tok |
| `how to configure niri keymap` | (titles only) | `answer`, Niri → its config section, 153 tok |
| `systemd 203/EXEC failed unit` | `List of TCP and UDP port numbers` | `abstain`, 0 tok — no article on the shelf names that code |
| `what is ersatz capitalism` | — | `abstain` — both articles are 276-byte stubs |

The last two lines are the point: a quote that explains *systemd in general* for
a `203/EXEC` failure is poisoning with extra steps. The gate needs a **rare-term
anchor** — a query term that names ≤2 retrieved titles — before it will spend
anything, so "topic present, specifics absent" comes back as silence.

A quote is the **best-matching section**, heading included, never the lead: the
lead is what a summary is, the section is what an answer is. It is **markdown**,
so a `<pre>` stays a fenced code block and a list keeps its bullets — flattened
HTML turned config examples into one unreadable line. `--budget N` caps the
tokens (default 1200), `--archive <substring>` narrows the fan-out.

Context cost, measured: an `answer` is ~250–650 tokens, an `abstain` is ~110
(three titles, no provenance, no text) — silence is the cheap outcome by design.

**It is a tool, not a rung.** Structural facts are supposed to calcify into
`.#knowledgeGraph` — compiled, counted, no tokens. A pass that can only produce a
prose passage never graduates to a routing rule; it stays a bounded tool with a
kill date, and the graph remains the thing that survives.

**Its ceiling, measured.** Every `## Claim` in the vault run verbatim (141
claims, 2026-11-04): **1 supported, 22 expand, 118 silent** — 0.7%. The shelf is a
specialist for concrete software entities (`btrfs scrub`, `niri` config, WireGuard
5.6), not a general oracle, and it does not validate abstract method claims. `expand`
never quotes: 22 of 22 expand passages were unrelated articles, so an expand is a
list of titles and a hint that the question needs a sharper subject.

`wiki-ask --list` prints the shelf itself (title, coverage, vintage, GiB, path)
as JSON or `--toon` — read it before choosing a shelf, rather than trusting a
skill line that ages.

### 0a. First: may this source settle the claim at all?

The 0.7% is a category error, not a ranking failure: those claims are about a
person's method, and no encyclopedia can settle one. That is declared data, so
ask it before searching (`flake/epistemics.nix`):

```bash
task ops:claim:check KIND=personal-method TEXT="a flat todo list is lowest friction"
#   read: vault-claims   price: 80   next: the `## Claim` sections of ~/vaults/personal
#   never: repo-docs (no authority), zim-shelf (no authority), web (no authority)

nix eval --json .#epistemics.table | toon -e    # the whole table, 0.1 s, no tokens
```

`KIND` comes from `.#epistemics.kindIds`: the table says which sources **may**
settle that kind, whether a frozen snapshot may speak about a moving fact, who is
accountable, and — from the route it picked — whether the read is `offline` and
unmetered (the shelf before the search; `…:8447/search?format=json` before one
`web_search`), with `persist` naming where a settled answer is filed.

`ops:wiki:ask KIND=` runs the same compile and refuses before searching when the
shelf has no authority. Permission is not coverage: an empty answer does not
falsify the claim, and an unnamable kind is a reason to abstain, not to guess.

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

## 3. Adding Any New Wiki Archive to Kiwix

One edit in `modules/services/kiwix.nix`: a `fetchurl` entry in `zims` (hash from
`nurl <url>`) plus a matching book in the `kiwixLibrary` writeText (any unique
UUID; `articleCount`/`size` are display-only). Rebuild. Never run `kiwix-manage`
by hand — the declarative `library.xml` overwrites it.

`kiwix-serve.service` runs with `-M`, so it reloads `library.xml` without a
restart. Verify with `wikisearch --list`, then query the archive by name
substring: `wikisearch -w "<archive_keyword>" "<search query>"`.

---

## 4. Querying from Remote Clients

`netbook` runs the same `wikisearch` and proxies over SSH to `frieren.lan`, so the
command is identical there. Any LAN or tailnet client can skip the wrapper and
ask the daemon: `http://frieren.lan:8088/search?pattern=<q>`,
`/suggest?term=<t>`, and the reader at `http://wiki.frieren.lan`.

