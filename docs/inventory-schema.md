# Inventory schema & compiled fleet feed

`inventory.toml` is the canonical device registry for every device the fleet
knows about — including the non-Nix ones. `lib/inventory.nix` turns it into
*compiled* data: parsed once, validated against an explicit schema, with the
facts that used to be hand-maintained prose derived instead.

## Why it exists

Three problems, one mechanism:

1. **Hand-maintained facts drift.** `metadata.*_devices` are a hand-maintained
   copy of a derived fact. `scripts/task/inventory-menu.sh` can recompute them,
   but only from the interactive menu, so nothing refreshed them when hosts were
   added and they sat stale (32 devices declared, 34 real). Now the counts are
   computed by `lib/inventory.nix` and the declared copies are *asserted* against
   them, so drift fails a check instead of living in the file.
2. **Facts lived in comments.** "netbook has no flake output, it is applied by
   remote fleet ops" was a Nix comment. A comment cannot be checked, so drift is
   invisible. It became `[hosts.netbook] flake = false`, which the coverage check
   enforced — and when the host was later brought into the flake on a pinned
   nixpkgs, the same field became `flake = true` and the same check now demands
   the output exist. The fact moved between values, never into prose.
3. **Every consumer re-parsed the same file.** `yq` in shell, `tomllib` in
   Python, `builtins.fromTOML` in Nix — three parsers that can disagree. Now
   there is one parse, and one compiled artifact everything reads.

## Schema

`lib/inventory.nix` declares the whole shape as option types. **Unknown keys are
errors** (no `freeformType`), so a typo fails evaluation instead of vanishing,
and a wrong type (`managed = "yes"`) is a hard error rather than a truthy
string.

That direction matters when adding a field: the schema is the truth and the TOML
is its reflection. Declare the option here **first** — a row added to
`inventory.toml` alone is not "inert data", it is
`error: The option `hosts.<h>.network.<field>' does not exist`, and nothing may
read the TOML directly anyway: consumers take `.#inventory` (or
`config.fleet.inventory`), which is the compiled, validated record. `network.mac`
is the worked example — the WoL task used to spell the address in shell; it now
reads `hosts.<h>.network.mac` from the compiled artifact.

| Section | Notes |
| :--- | :--- |
| `[metadata]` | `title`, `description`, `version`, `canonical_repo`, plus the derived counts (see below) |
| `[hosts.<name>]` | `hostname` (defaults to the key), `kind` (`nixos`/`darwin`/`home`/`external`), `arch`, `status` (`active`/`preserved`/`wip`), `role`, `category`, `users`, `flake`, `managed`, `builder`, `ci`, `is_nix`, `system_type`, `notes` |
| `[hosts.<name>.hardware]` | `model`, `cpu`, `gpu`, `ram`, `display`, `battery`, `storage_type`, `storage_layout` |
| `[hosts.<name>.network]` | `lan_ip`, `mac`, `tailscale_ip`, `tailscale_hostname`, `ssh_alias`, `domain`, `gemini_url`, `gopher_url`, `tailscale` |
| `[hosts.<name>.software]` | `module_chain`, `impermanence`, `key_services`, `traits` |

`builder` names the one host allowed to build and deploy this one, by hostname.
It exists because a cross-architecture member has exactly one builder in this
fleet (minyx is aarch64 and is built on delphi; the x86 hosts cannot build it and
the board itself is too slow): `scripts/task/minyx-keeper.sh` reads the field and
refuses to run where it is not the declared builder, so "who deploys this" is a
declared fact rather than a convention held in someone's head.

`software.traits` is the vocabulary shared modules read instead of keeping
hostname lists [[flake/policies.nix#capabilities-are-traits-not-names]]. A module
keys on a trait (`ai-full`, `dev-full`, `gpu-low`, `gpu-high`, `small-screen`,
`tpm-identity`, `nas-server`) or on `category` (`cloud`, `laptop`, `workstation`);
promotion to a fuller toolchain or a different GPU tier is therefore an edit to
one host's inventory entry, not to the module that consumes it. `nas-server` is
the negative capability: the two NAS client profiles skip the mount on the host
that declares it, instead of comparing the hostname against the server's name.
| `[hosts.<name>.persona]` | `title`, `system_prompt_hint`, `compute_tier`, `allowed_tasks`, `constraints` |

Everything except `kind`, `arch` and `status` is optional with an empty default,
so the compiled record is uniform even when the source omits a section.

### `flake` — is this host built by the flake?

`flake = true` (default) means "this flake produces this host". It is implied
`false` for `kind = "external"`. Set it `false` explicitly for a real host that
is deliberately outside the flake. Which nixpkgs a host builds from, and which
boot-chain constraint it pins, is not schema: it belongs in that host's module
and in its `notes`/runbook (`netbook` is the worked example —
`.agents/deploy/hosts/netbook.md`).

### `notes` — where host commentary goes

Anything that would otherwise be a paragraph of Nix comment about a host belongs
in `notes` (or in `status_detail` / `persona.*`). It is then compiled, shipped in
the feed, and searchable — instead of being an unverifiable comment next to a
module list.

## Compiled artifacts

| Surface | Command | Contents |
| :--- | :--- | :--- |
| Fast per-host read | `nix eval .#inventory.hosts.<host> --json` | The validated record. **No host configuration is evaluated** — the registry is parsed once at flake level. |
| Derived facts | `nix eval .#inventory.derived --json` | `total`, `nix`, `external`, `active`, `activeNix`, `activeExternal`, `wip`, `preserved` |
| Pretty JSON | `task dev:inventory:json` | `packages.<system>.inventory-json` — the registry for scripts, instead of re-parsing TOML with `yq` |
| Agent feed | `task dev:inventory:feed` | `packages.<system>.fleet-feed` — role, status, persona hint, compute tier, hardware, traits, services and notes per Nix host |
| Per-host convenience | `task dev:inventory:host HOST=<name>` | One compiled record, no host eval |

Use `task dev:inventory:json` in scripts rather than `yq` on
`inventory.toml`: it is already validated, defaults-normalised and carries the
derived counts, so two consumers cannot disagree.

## Automatic checks

Two tiers, split by **memory cost**, because the cost of "does this host evaluate"
is O(hosts) when hosts share one evaluator.

### Tier 1 — fleet-wide, in `checks.<system>` (forces no host configuration)

Reads the compiled registry and the flake's output attr **names**. Measured 1.08 s /
4.9 MiB for all three.

| Check | Fails when |
| :--- | :--- |
| `inventory-schema` | The file is internally inconsistent: a derived count disagrees with its declared copy, `is_nix` contradicts `kind`, `system_type = "non-nix"` on a Nix host, or a non-Nix device is marked `managed`. Reports every issue at once. |
| `inventory-hosts` | Coverage drifts either way: the flake builds a host that is not registered, or `inventory.toml` declares a flake host the flake does not build. |
| `inventory-modules` | A host's module list in `flake/host-inventory.nix` has no compiled-inventory module, so it would have no `config.fleet.inventory`. Detected by inspecting the module lists, **not** by evaluating hosts. |

### Tier 2 — per host, in `hostChecks.<arch>.<host>` (one host per attribute)

| Check | Proves | Cost (frieren / mtfuji) |
| :--- | :--- | :--- |
| `hostChecks.<arch>.<host>` | The module system evaluates and **all assertions pass** (2035 / 1620), the host **compiles `inventory.toml`** (`config.fleet.inventory.hosts.<self>` resolves and is printed), and `services.go-backend` is not enabled on it. | 13.16 s / 720 MiB — 11.42 s / 646 MiB |

The behavioural half — a host's module system *really* resolving the registry —
lives here, because it is the only place it can be checked without paying for every
host at once.

**Coverage, honestly:** tier 1 covers every registered host of every kind (nixos,
containers, standalone home, darwin, microvms) because it reads their module lists.
Tier 2 *as a build* covers the 23 NixOS hosts — those are the ones a local
`hostChecks` attribute can both evaluate and build on x86_64, since a check derivation
for another architecture needs a builder for it.

`checks:host MODE=eval` closes that gap without a builder: it **evaluates**
`<kind>Configurations.<host>.config` (module system, every assertion, and the registry
read) instead of building, so it is architecture-independent and works for all three
kinds from an x86_64 machine — `task checks:host HOST=penguin MODE=eval` costs 2.7 s /
452 MiB. That is the only way to check an aarch64 or darwin host from an x86_64 host,
and it is how the failing darwin host was found (`cassini` — see AGENTS.md).

A *build* mode gate no longer needs `ARCH` either: `hostChecks` is keyed by each
host's own architecture and the sweep reads it from the compiled registry, so
`task checks:host HOST=minyx` is the same command on delphi (aarch64, native) and
on an x86_64 host (which then needs a builder for it). Passing `ARCH=` overrides
that, and `MODE=eval` ignores it.

There is deliberately **no task that defaults to the fleet**. `checks:host` requires one
host name and `checks:hosts` requires an explicit `HOSTS=` list, because a default set
of 21-27 host evaluations is the footgun that was SIGKILLed at 6078.5 MiB. The fleet is
CI's job, one host per runner.

```bash
task checks:inventory:compiled   # tier 1
```

```bash
task checks:host:HOST=frieren    # tier 2, ONE host, under the OOM watchdog
task checks:hosts HOSTS="a b"    # tier 2, a NAMED set, one at a time (no default)
task checks:flake                # refuses `nix flake check` below 16 GiB RAM
```

### Why not `nix flake check`

`nix flake check` evaluates **every flake output**, not just `checks.<system>`: it
prints `checking flake output 'nixosConfigurations'` and then a line per
configuration. On frieren that is 23 evaluations in one process — measured
**339.78 s, 6078.5 MiB peak, SIGKILL (exit 137)** — against ~700 MiB per host when
they are run one at a time. `task checks:flake` therefore refuses below 16 GiB and
points at `task checks:hosts`. Every bounded run goes through
`scripts/task/oom-guard.sh`, which polls `/proc/vmstat oom_kill`, memory/io PSI and
`MemAvailable` every 10 s and aborts on pressure. CI runs tier 2 for affected hosts
only, which is also how the `services.go-backend` policy finally became an enforced
gate — previously it was reachable only from `nix flake check` and
`task checks:quick`, neither of which CI ran.

### The declared counts are assertions

`metadata.total_devices`, `active_nix_devices`, `active_external_devices`,
`wip_devices` and `preserved_devices` are still read by
`scripts/task/compile-llm-specs.py` and `scripts/task/inventory-menu.sh`, so
they are kept — but they are now *asserted* against the derived values rather
than trusted. Adding a host without updating them fails `inventory-schema`. The
same values are emitted under `derived` in the compiled artifact.

## Adding a host

1. Add `[hosts.<name>]` to `inventory.toml` with at least `kind`, `arch` and
   `status`; put operational commentary in `notes`.
2.   Register it in `flake/host-inventory.nix` if it is a flake host — or set
   `flake = false` if it deliberately is not. A host that builds from its own
   pinned nixpkgs (netbook) passes `nixpkgs = inputs.<pin>` and must carry
   `inventoryModules` explicitly, because it uses no global chain.
3. `task checks:inventory:compiled` — names any missing registration or stale
   count — then `task checks:host:HOST=<name>` to prove the host compiles the
   registry through its own module system.

## Related

- `lib/inventory.nix` — the schema and compiler
- `flake/module-sets.nix` — injects the compiled registry into every host
- `flake/checks.nix` — the checks above
- `flake/packages.nix` — the compiled artifacts
