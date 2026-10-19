# TODO — priority stack

> Open work only. Completed narrative is in
> [`docs/history/todo-2026-10.md`](docs/history/todo-2026-10.md); the design
> half of each item is in [`ARCHITECTURE.md`](ARCHITECTURE.md). One item per
> outcome, with an exit criterion. Budget: 150 lines.

## P0 — finish the context/observation plane

- [ ] **Fleet sentinel push** (P1). `pushUrl` + sops bearer token + one nginx
      ingest location; `task ops:fleet` merges host files.
      Exit: 3 hosts, 1 week, powered-off host shows `stale`, no new port.
- [ ] **Doc budget gate in CI** (`.github/workflows/nixcachix.yml`).
      Exit: `task ops:docs:budget` runs on doc-only changes; a 200-line growth
      in `AGENTS.md` fails.
- [ ] **Promote the two dormant host failures** into a known-red allowlist or
      fix them (`minyx` kernel `mkDefault`, `cassini` gate
      `freebuff-remote` to Linux). Exit: `task checks:hosts HOSTS="minyx
      cassini" MODE=eval` is either green or explicitly expected-red.

## P1 — close the operational gaps the sentinel exposes

- [ ] **DNS failover second resolver** (HC-3). Provision an always-on node;
      add it to `profiles.dnsFailover.resolvers`; point clients at both.
      Exit: `task checks:dns:failover` exits 0 (not 2); stopping frieren's
      resolver leaves clients resolving.
- [ ] **Resolver independence for clients** (EXP-104) and the health gate
      (EXP-105). Exit: a client with frieren down still resolves public names;
      `checks:dns:resolver-health` reproduces it.
- [ ] **MQTT bus** (HC-5/EXP-007). HA is config-entry-only; create the entry
      through the UI/onboarding once, then document the flow. Exit:
      `task checks:ha:mqtt` reports an established subscription; EXP-014/015
      can follow.
- [ ] **Execute the restore drill through its unit** (EXP-111). It has only
      been run by hand. Exit: one green `restic-drill.service` run + a snapshot
      id in the ledger.
- [ ] **Sentinel `unit-failed` mapping for external hosts.** Today these are
      `absent` on non-NixOS. Exit: the field never claims success for a unit it
      cannot see.

## P2 — knowledge and attention

- [ ] **Vault write path** (P2): `vault-sync.timer` → one inbox file per host
      per day, with frontmatter and a Git commit. Exit: a week of sessions is
      searchable in `qmd -c vault`; NFS down fails loudly and loses nothing.
- [ ] **DMS sentinel widget** (P5). Exit: red card + one notification on
      transition, green on recovery, no new service or port.
- [ ] **Semantic search, if it earns its keep.** `qmd embed` is optional; only
      enable after BM25 misses are measured, not assumed.
- [x] **Graph query cookbook**: add 5 real `jq` recipes to the
      `knowledge-base` skill (what touches X, orphan docs, skills with no host).
      Done 2026-10-19 — every block is the literal command, run against the live
      graph: orphan docs 0, skills no doc mentions 15/43 (exact-token matching
      and a doc set of 21, not rot).
- [ ] **Knowledge graph reactive sidecar engine (Elixir/OTP)**: In-memory ETS
      property graph engine with UDS socket listener (`/run/kg.sock`), initial
      bootstrap from `knowledge-graph.json`, and live inotify watcher for sub-millisecond
      agent traversals (neighbors, blast-radius, drift detection).
      Exit: `curl --unix-socket /run/kg.sock http://localhost/query?from=host:frieren`
      returns in <1ms; file change in working tree updates graph in memory in <15ms.

## P3 — hygiene and maintenance

- [ ] **Closure budgets for every measured host** (`closure-budgets.toml`).
      Adoption is local-only; run it on each host when it is next online.
      Exit: a regression on a second host fails `checks:closure:budget`.
- [ ] **CI closure budget gate** (EXP-110 remaining). Needs a built toplevel
      `TARGET=<store path>` in the workflow.
- [ ] **Canary promotion gate** (P6): optional CI job for
      `modules/services/**` on a KVM runner. Exit: a broken unit fails it.
- [ ] **Transitive flake drift**: `task dev:flake:update-transitive` in batches,
      one PR per batch, with a host gate on the representative host per chain.
- [ ] **Mosquitto auth** when the first real device arrives (passwordFile in
      sops, LAN listener). Do not add an anonymous LAN listener.
- [ ] **Zigbee coordinator**: when the dongle exists, set
      `services.zigbee2mqtt.settings.serial.port` from `/dev/serial/by-id`.

## Backlog (not scheduled)

- EXP-018 remote GPU inference (depends on eisen stability + budget).
- EXP-049/064 SimpleX agent mesh and message classifier.
- EXP-076 DNS VRRP/anycast (only after a second resolver exists).
- EXP-090 offsite restic replica beyond BurgerNAS.
- EXP-095 btrfs scrub throttling (measure during the next scrub first).

## Things to avoid (unchanged)

- No broad host rewrite in one pass.
- Do not move secrets or encrypted data.
- Do not silently widen system support.
- Do not assume Garnix persistence.
- Do not merge host-local storage layout into shared modules without real reuse.
- Do not add a task when a `nix eval` answers the question.
- Never run `nix flake check` on a small host (6 GiB / SIGKILL 137).
