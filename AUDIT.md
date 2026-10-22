# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Entries older
> than the current day are archived in
> [`docs/history/audit-2026-10.md`](docs/history/audit-2026-10.md); design rationale
> lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`).
> Budget: 150 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-20)

| Area | State | Evidence |
| :--- | :--- | :--- |
| Fleet registry | 34 devices: 11 active Nix, 6 active external, 1 WIP, 16 preserved | `.#inventory`, `docs/generated/fleet-inventory.md` |
| Host gates | per-host module system + assertions, one host per process | `nix build .#hostChecks.x86_64-linux.<host>` |
| Known red gates | `minyx` (kernel conflict), `cassini` (xdg.desktopEntries on darwin) — both dormant | `task checks:host HOST=minyx MODE=eval` |
| Formatting | alejandra, 100 % of tracked `.nix` | `task checks:nix:format` |
| Lint | deadnix hard gate, statix advisory | `task checks:nix:lint` |
| Secrets | 6 SOPS files, zero drift | `task checks:sops:drift` |
| Skills | 43, compiled + schema-gated | `nix eval .#agentSkills.count`, `task ops:skills:check` |
| Observation | frieren sentinel: 15-min ledger, health endpoint, gatus body assertion | `task ops:health`, `/var/lib/fleet-sentinel/` |
| Knowledge | qmd (`.md` + `.nix`) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | resolver pair: frieren pihole+unbound, delphi crab-hole, one shared `10.99.0.53` | `task checks:dns:failover` |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger
### 2026-10-22 — delphi's two surfaces are compiled from one structure; two gates stop needing python
- `lib/delphi-site.nix` renders the public dossier and the tailnet console from ONE evaluated structure
  (`inventory.toml` + knowledge graph + `config.services.servicePortal.cards`); markup in
  `lib/delphi/*.{html,css,js}`, `render` throws on an unbound hole. Replaces the inline page whose public
  surface carried no content at all (every card was tailnet-audience). `cards` is the new read-only
  projection, so the mount declaration and either page cannot drift. Registry truth fixed: `domain`/`tailscale_ip`
  registered (the host reads them), `status_detail`/`key_services`/`notes` corrected. The MagicDNS name
  answers on `:80` behind `allow 100.64.0.0/10; deny all;` — 443 belongs to ACME. Evidence: 1856
  assertions, 4 console cards / 4 withheld names, no tailnet address on the public page. Runbook:
  `.agents/deploy/hosts/delphi.md` § *The two surfaces*.
- `docs-links.sh` and `toon-surfaces.sh` lost their `python3` dependency (awk + `test -e`): a gate that
  fails where no interpreter exists is not a gate. Negative controls prove both still catch a broken link
  and a bare `nix eval --json`. The tools the gates needed are declared, not ad-hoc:
  `profiles.operatorTools` (`modules/profiles/operator-tools.nix`) puts `toon` + `python3` in delphi's
  closure (cache fetches, no build), after which `checks:toon`, `ops:tailnet:policy` and
  `checks:kg:canvas` (static half) pass here; `agent-browser` stays opt-in — that gate skips its click.

### 2026-10-22 — the portable library gets an admission rule, not a bigger disk- Audited the four store dirs: 178 files, 9.5 GiB, 83 static, glibc floor 2.39, 11 MiB exact duplicates, 92 MiB eget re-fetch residue (`*.1`).
- `data:library`, `:index`, `:fetch` replace ad-hoc eget use: a dynamic download is rejected to
  `.rejected/`, provenance goes to `.library.tsv`; asserts
  [[flake/policies.nix#library-fetch-is-static]] + [[flake/policies.nix#library-crosses-the-wire]],
  note `portable-library`.

### 2026-10-22 — scratch's sops planes unseal through its TPM; the proof moves to the store copy
- scratch is the third TPM-sealed host (`&tpmscratch`) and the first whose **system** plane unseals
  through the chip: `age.keyFile` + `age.plugins`, `sshKeyPaths` forced empty, no SSH-derived recipient
  at all. `switch-to-configuration` exits 0. Audio was firmware, not config (BIOS re-enabled `00:1f.3`).
- `modules/sops.nix` gained `age.plugins` for `tpmHosts`: without it the user unit's
  `Environment=PATH=` is empty and the unseal dies on `0 successful groups required, got 0` —
  measured on frieren, exit 128 with the identity / exit 0 with the plugin. frieren and fern stay
  green only because a software `keys.txt` is still a recipient there, so their `sops -d` says nothing.
- Proof now targets `/nix/store/<hash>-secrets.yaml` through the unit's own manifest, not a checkout:
  both planes decrypt it to the pulled tree's digest, and a no-identity control exits 128. scratch's
  clone sat 2768 commits behind at `~/nixconfig` while `~/Documents/nixconfig` was a store symlink.
  Procedure `docs/sops-rekey.md`; note `tpm-sops-planes`.


### 2026-10-22 — the 2026-10-21 ledger entries are archived
- Eight entries (frieren's two boot personas, delphi's seeder / Freebuff / antigravity, the dsh worker
  service, Pi research, fern's battery, both Strata entries, and the previous archive note) moved to
  `docs/history/audit-2026-10.md` § *Ledger: 2026-10-21 (continued)* at 165/150 lines. Content
  unchanged but for one link re-based to its new depth (`docs/pi-harness.md` → `../pi-harness.md`), which
  `checks:docs:links` caught.

## Open debt (`task ops:notes`)

1. `minyx` kernel conflict and `cassini` darwin assertion — both dormant, both
   reproducible with `MODE=eval`.
2. Tailnet DNS lists `10.99.0.53`, which eisen/fern/aristotle cannot route
   (`--accept-routes=false` is deliberate), so their failover is nominal; list both
   resolver node addresses instead (`ops:tailnet:dns` reports the set).
3. MQTT broker has no publisher/subscriber (HC-5); 7 of 11 `extraComponents`
   entries are dormant Python dependencies, not enabled components.
4. Sentinel is frieren-local; fleet push is P1 in `ARCHITECTURE.md`.
5. `compile-llm-specs.py` still generates the offline fleet-matrix table (not the
   home card; `~/AGENTS.md` is now `.#homeAgents.<host>`).
