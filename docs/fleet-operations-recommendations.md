# Fleet Operations Recommendations

Ten changes to how this fleet is *operated*, each grounded in a defect observed on
2026-10-14/15 rather than in principle. Ordered by the cost of not doing it.

The evidence column is the point: every item below cost real time or real silence
on a real host, and each one is cheap to close.

---

## 1. Enforce build routing, don't just document it

**Observed.** EXP-107 declared *"burn CPU on builders, not on the machine that asked
for the config"* — and nothing enforced it. The only honest test of "is this closure
substitutable?" was a build, and a build on a 15 W dual-core is the thing the rule
forbids. fern hit **load ~9.4** on 2c/4t; a killed rebuild left an orphaned root
`nix build` holding ~2 GB.

**Recommendation.** Keep `scripts/task/warm-host.sh` + `task checks:build:route` as
the enforcement pair (EXP-113), and make the gate *fail CI* for any host whose
closure is not substitutable. Readiness is one bounded HTTP request against
harmonia — no ssh, no daemon, nothing that can block.

**Action.** Add a CI job that runs `checks:build:route` for each affected host after
the cache warm, so "warmed" is asserted rather than assumed.

---

## 2. Never verify a config with a single-option eval

**Observed.** `nix eval .#...config.networking.hostName` "passed" on four hosts while
the closure contained a hard failure:

```
dispatcherScripts."[1-entry 1]".type is not of type `one of "basic", "pre-down", "pre-up"'
Definition value: "up"
```

A one-option eval forces that option and type-checks nothing else (EXP-114).

**Recommendation.** Force the whole configuration —
`nix eval --raw .#nixosConfigurations.<h>.config.system.build.toplevel.drvPath` —
which instantiates every module and every option type in seconds. This is now the
documented pre-build phase in `AGENTS.md`.

**Action.** Convert `checks:quick`'s four single-option evals to four toplevel
instantiations. Same order of magnitude in time; the difference is that it can fail.

---

## 3. Fleet builds are a schedule; a host that is needed now gets its own deploy

**Observed.** A weekly fleet warmer (`fleet-warm-cache`, Sun 01:30) exists, but there
was no *intended* single-host path — so the fallback was a hand-rolled
`nixos-rebuild` on the target, which is the anti-pattern.

**Recommendation.** `task infra:deploy:host:<host>` = gate → plan → apply → validate,
for **one intended host**, never fleet-wide. Fleet-wide stays `infra:apply:fleet` on
a schedule. This is now the documented Phase 2 in `AGENTS.md`.

**Action.** Extend `fleet-warm-cache` to warm from the **local tree** as well as
`github:shaoyanji/nixconfig`. Today it builds only the pushed ref, so it is blind to
any working-tree state — exactly what made fern's closure cold in the first place.

---

## 4. Make the transport a parameter, and prefer the LAN

**Observed.** Every task hardcoded `ssh {{.HOST}}`. `fern` resolves to its **tailnet**
address, where Tailscale SSH now demands a browser check — so an unattended run
**hung for 5 minutes** with no output and no failure. `devji@192.168.3.23` works
instantly.

**Recommendation.** `TARGET=` is now a var on `infra:apply:host:*`,
`infra:deploy:host:*` and `services:validate:host:*`, defaulting to the host name.
Better: make the ssh aliases resolve **LAN-first with tailnet fallback**, so the
default path is the one that cannot block.

**Action.** Add `Hostname`/`ProxyJump` LAN-first entries for fleet hosts, and treat
"an unattended task that can open an interactive ssh prompt" as a defect.

---

## 5. No ssh in an unattended path

**Observed.** Both the first `warm-host.sh` and every deploy/validate step opened
ssh. One printed nothing for 5 minutes; another would have failed silently.

**Recommendation.** An unattended step must ask questions the *cache* can answer over
HTTP with a timeout. If a step genuinely needs a remote shell, it needs a bounded,
non-interactive transport — not the default one.

**Action.** Audit `scripts/task/*` for `ssh` and classify each as
interactive-by-design or unattended; the latter need `BatchMode` + an explicit
transport or they should not exist.

---

## 6. Verify the boot path, not just the switch path

**Observed.** The nas-client rework was reasoned and unit-rendered, but its actual
reported symptom was **boot-time** (`mount.nfs: Network is unreachable` at boot,
before WiFi). Nothing in the fleet verifies what happens on the next *boot*;
`switch` success is the only signal anyone looks at.

**Recommendation.** A boot sentinel: a oneshot that records the booted generation and
its unit-failure set to a file/telemetry, plus a check that diffs it against the
generation that was deployed. `nixos-rebuild boot` exists precisely so a generation
can be staged without activation.

**Action.** `checks:boot:verify` comparing `/run/current-system` against the intended
store path, exiting non-zero on mismatch or on any failed unit from that boot.

---

## 7. Schedule the checks that currently only run when a human remembers

**Observed.** `checks:ports` found real drift — DEAD-HOLE ports (`631`, `3005`,
`8324`, `8920`, `32469`), a REDUNDANT LAN hole that is loopback-bound (`3001`), and
eleven FIREWALL-ONLY ports held back only by interface scoping. It is also
read-only and idempotent, i.e. exactly what a timer is for.

**Recommendation.** Timer + `STRICT=1` on a weekly cadence for `checks:ports`,
`checks:closure:budget`, `checks:restic:drill` and `checks:sops:drift`. Drift should
be found by a schedule, not by someone reading a doc.

**Action.** One systemd timer on frieren running the read-only check set and
reporting failures into the existing fleet telemetry.

---

## 8. Keep the declarative truth as the routing source

**Observed.** `inventory.toml` is the fleet source of truth (`managed`, `ci`,
`compute_tier`, `allowed_tasks`), yet routing decisions were being made from runtime
state and ad-hoc paths. Attempting to add builder metadata with `yq -i` **reformatted
the entire file** (a 622-line diff), which is why it was reverted untouched.

**Recommendation.** Routing (`builder_host`, `cache_url`, deploy policy) belongs in
the inventory as data, read by tasks — not hardcoded in scripts. Don't hand-edit it
around tooling that rewrites the file.

**Action.** Either teach `yq` to preserve formatting (or use a formatter-stable
editor) and add a `[fleet]` section, or move routing metadata into a small dedicated
TOML file written once. `warm-host.sh` already reads
`metadata.builder_host`/`metadata.cache_url` when present and defaults to frieren.

---

## 9. Close the container/module gaps the same way

**Observed.** EXP-112: the MQTT broker has **0 clients** and Home Assistant is not
subscribed. EXP-007/009 assume otherwise. Dead services behind live ports
(`631`, `3001`, `1883`, `8123`) make a firewall hole look justified after its
service is gone.

**Recommendation.** For each declared-but-unused service, either wire it end to end
(publisher *and* subscriber, with the client visible in `ss`) or delete it and prune
the matching firewall hole. A declared service with no consumer is a permanent
audit finding.

**Action.** Finish EXP-112 (authenticated listener + sops password + HA config
entry), then re-run `checks:ports` with `STRICT=1`.

---

## 10. Make the failure modes visible in the Taskfile contract

**Observed.** The most expensive failures this session were **silent**: a 5-minute
hang with no output, an eval that proved nothing, a read-only `--check` that
silently launched a 400-second build, and an ssh alias that quietly pointed at an
interactive-auth transport.

**Recommendation.** Every task's `summary` should state its **exit-code meaning**,
whether it is **safe unattended**, and what transport it uses — the Taskfile is the
machine contract, and silence is the failure mode. Follow the existing convention:
check tasks exit non-zero on drift; deployment tasks name their transport var.

**Action.** Sweep the task summaries for the four tasks that touch the network
(`infra:apply`, `infra:deploy`, `services:validate`, `infra:warm:*`) and state
transport + unattended-safety explicitly. Three of the four are already done in this
pass (`TARGET=`, "read-only, cache-based, no ssh").
