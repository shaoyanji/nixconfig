---
name: fleet-sentinel
description: "Read and act on the fleet's closed loop: sentinel ledger schema, health gate, and the runbook for failed jobs, stale generations, disk and PSI pressure."
version: 0.1.0
author: Shaoyan Ji (shaoyanji)
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [monitoring, ledger, systemd, nixos, incidents, ops]
    related_skills: [knowledge-base, master-toon, task-plane, nix-eval]
---

# fleet-sentinel — detection, record, route

gatus answers *"is the socket open?"*. The sentinel answers *"did the work
happen, and is the system drifting?"*. They are complementary: gatus is the
pager, the sentinel is the diary.

## 1. What runs

`modules/services/fleet-sentinel.nix` (enabled on frieren):

| Piece | Path / unit |
| :--- | :--- |
| Collector (oneshot, 15 min) | `fleet-sentinel.service` |
| Timer | `fleet-sentinel.timer` (`OnBootSec=3min`, persistent) |
| State | `/var/lib/fleet-sentinel/` |
| Ledger | `ledger.jsonl` (bounded to 10 000 lines) |
| Current verdict | `www/status.json` (also served at `/sentinel/status.json`) |
| Machine gate | `www/health.txt` (`ok` / `degraded`) |
| Dashboard | `http://sentinel.frieren.lan/` (static, reads `status.json`) |
| gatus probe | `http://127.0.0.1:80/sentinel/status.json`, condition `[BODY].state == ok` |

## 2. Ledger schema (schema: 1)

One JSON object per run:

```json
{
  "schema": 1,
  "ts": "2026-10-19T11:00:00Z",
  "host": "frieren",
  "state": "ok",
  "reasons": ["generation-stale:75.2h"],
  "failed_units": ["foo.service"],
  "jobs": {
    "nixos-upgrade.service": "success",
    "restic-backups-frieren-local.service": "success",
    "restic-drill.service": "absent"
  },
  "generation_age_h": 5.2,
  "disk_pct": {"root": 42, "nix": 61, "data": 80},
  "psi": {"io": 1.2, "memory": 0.0},
  "prefill": {"ts": "2026-10-28T23:59:37Z", "recorded": true,
              "cache_growth_bytes": 0, "wan_bytes": 406}
}
```

`prefill` is the newest line of a job's own run ledger
(`services.fleetSentinel.prefillRuns`, pointed at
`services.steamCache.prefill.ledger` on frieren), projected rather than copied:
at a 15-minute cadence the same numbers would be 95 identical readings. `null`
means no self-measuring job on this host. Read the whole history with
`tail -n 20 /var/lib/steam-prefill/runs.jsonl | jq -c .`.

**A job's own progress output is not a measurement.** The Steam prefill counted
chunks across the whole selection and served the uncached ones first: it read
18 % for 46 minutes, then finished all 33.72 GiB in 8:29 off the cache. Its
`cache_growth_bytes` / `wan_bytes` are the instrument — 0 growth with a few
hundred WAN bytes is a warm night, and a large `wan_bytes` with no growth is a
fill that fetched and stored nothing (broken cache, wrong pin).

`reasons` is the contract: each token is `class:detail`.

| Token | Meaning | First move |
| :--- | :--- | :--- |
| `failed-units:N` | N units in `failed` state | `systemctl --failed`; inspect the named units in `failed_units` |
| `unit-failed:<unit>:<result>` | a watched oneshot's last `Result` is not `success` | `journalctl -u <unit> -n 80`; check its inputs (disk, network, secrets) |
| `failed-units` naming `loaded` (fixed 2026-10-29) | the collector read column 2 of `list-units --plain --no-legend` (the literal word `loaded`), so `ignoreFailedUnits` never matched | upgrade; verify with `systemctl --failed --no-legend --plain \| head` and that `status.json` names the unit |
| `generation-stale:<h>h` | running system older than `generationAgeHours` (72) | check `nixos-upgrade` journal; confirm the flake input/autoUpgrade path |
| `disk-high:<path>:<pct>%` | filesystem ≥ 90 % | `task dev:closure:size`; GC/snapshot prune; never delete `/srv/data` content ad hoc |

`null` disk values mean the path does not exist on that host (neutral, not bad).
`absent` job results mean the unit is not installed on that host (neutral).

## 3. Operator loop

```bash
task ops:health                 # exit 1 when degraded; prints reasons
task ops:ledger                 # last 50 events, JSONL
task ops:ledger:toon            # TOON projection for an agent (fewer tokens)
task ops:sentinel:run           # force a collection now
task ops:sentinel:status        # timer + last run + dashboard URL
```

Then, per reason:

```bash
systemctl --failed --no-legend
systemctl status <unit> --no-pager
journalctl -u <unit> -n 100 --no-pager
systemctl list-timers --all | grep -E 'restic|nixos-upgrade|sentinel'
```

## 4. Interpretation rules

1. **A successful unit is not a successful outcome.** `nixos-upgrade.service`
   can exit 0 with "no new generation" when the flake input did not advance
   (the origin-vs-local trap in `AGENTS.md`). `generation-stale` is the check
   that catches that.
2. **A restic job that has never run is `absent`, not failed.** Do not "fix" a
   fresh install by inventing a timer.
3. **PSI beats load average.** On frieren, `psi.io` above ~10 while `psi.memory`
   is low usually means btrfs/scrub/NFS, not CPU. Check `vmstat 1 3`
   (`wa`, `si/so`) before blaming a service.
4. **Disk 90 % is a prediction, not an outage.** Act on the trend: compare the
   last two ledger entries, not the single reading.
5. **Never rebuild during the 03:00–05:30 window** (AGENTS.md). If a stale
   generation is the reason, wait for the nightly run or use
   `task infra:deploy:host:frieren` deliberately.

## 5. When the sentinel itself is wrong

- Collector fails to start: `systemctl status fleet-sentinel` + `journalctl`.
  The dashboard 404s and gatus turns red after 3 failed probes — that is a real
  signal, not noise.
- `status.json` is stale by hours: the timer is not firing. Check
  `systemctl list-timers fleet-sentinel.timer`; `Persistent=true` means one
  catch-up run after boot.
- The ledger grows without rotating: `ledgerMaxLines` is a module option; do not
  truncate by hand, change it and switch.

## 6. What is deliberately not here

- No push from other hosts yet (see the `p1-sentinel-push` note in `AGENTS.nix`). Today the sentinel is
  frieren-local; the fleet report is `task checks:*` + CI + `AUDIT.md`.
- No alerting of its own: gatus owns the transition, and its custom webhook
  bridges to SimpleX (3 consecutive failures, with a resolved notice).
- No metrics database: 10 000 JSONL lines are queryable with `jq`/TOON and cost
  nothing when idle. If a time series is ever needed, export to InfluxDB rather
  than growing the ledger.
