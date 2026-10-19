# QMD Vector Embedding Remote Offload & Synchronization

Architecture and operational runbook for offloading QMD vector embeddings from
Frieren (NAS) to Eisen (Compute Workstation) across network floors.

---

## 1. Context & Architectural Challenge

QMD powers hybrid semantic and lexical Markdown search across the fleet's
knowledge bases, repositories, and archives. While full-text BM25 search
(`qmd search`) runs instantaneously with negligible CPU, generating dense vector
embeddings (`qmd embed` using Gemma-300M) requires extensive matrix math.

### The Host Compute Asymmetry

* **Frieren (`i5-8250U`, 15W TDP, 11.5 GiB RAM):**
  Central NAS mainframe and media server. Running batch embeddings on Frieren
  triggers severe thermal throttling (dropping clocks to 1.6 GHz base), saturates
  I/O bandwidth, and threatens media streaming continuity. Batch embedding must
  **never** run directly on Frieren.
* **Eisen (12-core / 24-thread Xeon, 64 GiB RAM, local NVMe):**
  Workstation and local LLM host. Easily processes embedding batches at ~6 dedicated
  worker threads without memory pressure or thermal throttling.

### The Multi-Floor NFS Latency Trap

Naively running `qmd embed` on Eisen against NFS-mounted storage (`/Volumes/data`
mounted over 3 floors of building network) causes severe performance degradation:
* Statting and reading thousands of small Markdown files and issuing per-document
  SQLite WAL writes across high-latency network hops stalls worker threads in
  `rpc_wait_bit_killable`.
* **Solution:** Decouple filesystem indexing from dense vector computation.

---

## 2. Decoupled Multi-Floor Pipeline

```mermaid
sequenceDiagram
    participant F as Frieren (NAS / Local Storage)
    participant E as Eisen (Compute / NVMe)

    Note over F: 1. Local BM25 Indexing
    F->>F: qmd update (reads local NVMe/btrfs; 0 network hops)
    
    Note over F,E: 2. Wake-on-LAN & Push
    F->>E: WoL Magic Packet (00:e0:22:1c:bb:ed)
    F->>E: Poll SSH until online (timeout 120s)
    F->>E: rsync index.sqlite -> Eisen NVMe (~/.cache/qmd/)

    Note over E: 3. Local Dense Embedding
    E->>E: qmd embed (NVMe-local SQLite, 12 cores, 0 NFS calls)

    Note over F,E: 4. Pull Consolidated Cache
    E->>F: rsync index.sqlite -> Frieren SSD (~/.cache/qmd/)
    E->>F: rsync embeddinggemma-300M weights -> Frieren

    Note over F: 5. Ready for Sub-Second Local Querying
    F->>F: qmd vsearch / qmd search (local inference in ~150ms)
```

### Vector Invalidation Rule
Embeddings stored in `content_vectors` are keyed by SHA-256 document content hashes
and model identifiers. They are **never invalidated** by transferring the SQLite
database between hosts. Once embedded by Eisen, Frieren reuses the vectors
indefinitely until a document's content hash changes.

---

## 3. Registered Fleet Collections (9 Total)

All collections are configured in `~/.config/qmd/index.yml`:

| Collection | Path | Mask | Purpose |
|---|---|---|---|
| `vault` | `/Volumes/data/projects/Obsidian-Git-Sync` | `**/*.md` | Personal Obsidian knowledge base, zettels, schematics |
| `nixconfig` | `/Volumes/data/projects/nixconfig` | `**/*.md` | Nix flake documentation, host architecture, and runbooks |
| `offlinebooks` | `/Volumes/data/books/markdown` | `**/*.md` | Offline academic papers, textbooks, and technical books |
| `skills` | `/home/devji/.hermes/skills` | `**/*.md` | Agent operational skills (Hermes and Antigravity) |
| `apps` | `/Volumes/data/projects/antigravity-application-workflow/src` | `**/*.{typ,md}` | Job applications, resumes, cover letters, and tracking |
| `german` | `/Volumes/data/german/notes` | `**/*.{md,txt}` | German language study notes, vocabulary, and grammar |
| `recipes` | `/Volumes/data/recipes` | `**/*.{cook,md}` | Cooking recipes, meal ideas, and culinary notes |
| `doc-notes` | `/Volumes/data/documents/notes` | `**/*.md` | Personal document summaries, reference notes, records |
| `project-docs` | `/Volumes/data/projects` | `**/README.md` | Architectural overviews and READMEs across git projects |

---

## 4. Automation & Maintenance

The entire offload pipeline is fully deterministic and requires **zero interactive LLM assistance**.

### Package & Script
Packaged as a hermetic Nix application via `pkgs.writeShellApplication` at
[`modules/scripts/qmd-eisen-embed-sync.nix`](file:///home/devji/Documents/nixconfig/modules/scripts/qmd-eisen-embed-sync.nix)
and installed into system PATH on Frieren via `hosts/frieren/tools.nix`.
The source script [`scripts/task/qmd-eisen-embed-sync.sh`](file:///home/devji/Documents/nixconfig/scripts/task/qmd-eisen-embed-sync.sh)
provides:
* **Avoid WoL if already online:** Probes SSH reachability first; skips WoL if Eisen is already awake.
* **Automated Post-Sync Poweroff:** Cleanly shuts down Eisen (`systemctl poweroff`) if it was woken by WoL for this run.
* **Gaming Guard Protection:** Checks whether an active Steam game or LLM generation is running (via `llama-swap.service` gaming guard) before powering off, avoiding disruption to interactive sessions unless `--force-poweroff` is set.
* **Preflight Check Mode (`--check`):** Verifies inventory MAC/IP facts, local/remote `qmd` binaries, SQLite index existence, and SSH reachability without triggering embeddings.
* **Status Mode (`--status`):** Inspects vector counts and Eisen power state.
* **Dry-Run Mode (`--dry-run`):** Simulates WoL, rsync, and embed steps without mutating state.

### CLI Usage & Flags
```bash
qmd-eisen-embed-sync --check           # preflight check
qmd-eisen-embed-sync --status          # view index & Eisen power state
qmd-eisen-embed-sync --dry-run         # simulate execution
qmd-eisen-embed-sync                   # full sync (powers off Eisen if woken by WoL)
qmd-eisen-embed-sync -c apps           # embed only 'apps' collection
qmd-eisen-embed-sync --no-poweroff     # leave Eisen powered on after sync
qmd-eisen-embed-sync --poweroff        # force poweroff after sync
```

### Taskfile Tasks
```bash
task dev:qmd:sync:eisen -- --check    # Pass flags through to the sync runner
task dev:qmd:sync:eisen               # Canonical task
task ops:qmd:sync:eisen               # Ops plane alias
task data:qmd:sync:eisen              # Data plane alias
```

### Declarative Systemd Unit on Frieren
Defined in `hosts/frieren/infra-stack.nix`:
* **Package:** `${qmdEisenEmbedSync}/bin/qmd-eisen-embed-sync`
* **Service:** `systemd.services.qmd-eisen-embed-sync`
* **Timer:** `systemd.timers.qmd-eisen-embed-sync`
* **Schedule:** Monthly at `02:00:00` on the 1st of each month (`*-*-01 02:00:00`).
* **Maintenance Constraint:** Scheduled strictly outside Frieren's `03:00–05:30` nightly backup window.

---

## 5. Verification Commands

Check index and vector population:
```bash
qmd status
```

Fast keyword search (instant BM25, no LLM):
```bash
qmd search "Lebenslauf" -c apps
```

Vector similarity search (uses local Gemma weights):
```bash
qmd vsearch "retail application" -c apps
```

Hybrid search with query expansion and reranking:
```bash
qmd query "how does wake on lan work in nixconfig" -c nixconfig
```
