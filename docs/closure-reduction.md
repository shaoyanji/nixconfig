# Closure Reduction — measured levers and the move toward `nix shell`

Measured on **frieren** against `/run/current-system` on **2026-10-10**
(`nixos-system-frieren-26.11.20261005.aa48d34`).

This is the *why* behind the closure tooling. Every number below is reproduced by
a command in this document; nothing here is estimated. Anything marked
**candidate** was measured but not yet actioned, and carries the command that
confirms or refutes it.

## 1. Reproduce / inspect

```bash
task dev:closure:menu                     # interactive: subsystem -> package -> why
task dev:closure:menu -- reduce 10        # reduction report (duplicates + every copy)
task dev:closure:reduce N=10              # same report, one-shot
task dev:closure:menu -- why immich       # why-depends chain for one package
task dev:closure:menu -- members <GROUP>  # the concrete paths inside a duplicate group
task dev:closure:native:diff              # [gate] byte-parity vs the shell baseline
```

The menu renders what `scripts/task/closure-graph.sh data` computes; that payload
is byte-parity-checked against `closure-analysis.sh` by the gate, so the menu and
the baseline cannot disagree about a byte.

## 2. Baseline

> The **pre-change** baseline. After L1 was applied and deployed (generation 81)
> the live `/run/current-system` is `3945` paths / **33.8 GiB**; these numbers are
> what it looked like before.

| Metric | Value |
| --- | --- |
| Total closure | **34.5 GiB** (`37003869872` bytes) |
| Paths | **3949** |
| Subsystems | 18 |
| Duplicate groups (same package, >1 version) | **675** |
| Optimistically reclaimable from duplicates | **5.1 GiB** (`5452440032` bytes) |

Subsystem table (top 6 of 18):

| Size | % | Pkgs | Subsystem |
| --- | --- | --- | --- |
| 23.1 GiB | 66.8% | 2688 | `other` |
| 4.3 GiB | 12.2% | 722 | `python` |
| 1.2 GiB | 3.3% | 54 | `gui-toolkit` |
| 1.1 GiB | 3.1% | 2 | `llvm` |
| 920.3 MiB | 2.6% | 5 | `java` |
| 836.5 MiB | 2.4% | 11 | `firmware` |

## 3. The structural finding: `home-manager-path`

The single most useful result of the traversal is *where* things attach. Almost
every oversized interactive tool in this closure reaches the system through one
node:

```
nixos-system-… └── etc └── user-environment └── home-manager-path └── <tool>
```

`home-manager-path` is Home Manager's profile symlink farm. It means **every
`home.packages` entry is a hard member of the system closure** — there is no
"installed but not in the boot closure" tier. On a 24/7 server this is what puts
editors, agents and converters permanently in `/nix/store`.

Confirmed members of that farm (own size):

| Size | Package |
| --- | --- |
| 904.3 MiB | `qmd-2.8.3` |
| 357.8 MiB | `zed-editor-1.22.0` |
| 246.3 MiB | `tinymist-0.15.8` |
| 217.6 MiB | `devenv-2.4.0` |
| 208.9 MiB | `pandoc-cli-3.7.0.2` |
| 200.0 MiB | `antigravity-cli-1.2.16` |
| 162.3 MiB | `pi-coding-agent-1.0.2` |
| 156.5 MiB | `pdfvision-0.16.0` |
| 156.3 MiB | `hermes-agent-2026.9.24` |

Verify any row:

```bash
task dev:closure:menu -- why zed-editor
```

## 4. Levers, ranked

### L1 — Two full Chromiums for one purpose · **APPLIED, measured 703.2 MiB**

`modules/user/ai/default.nix` installs **both** `pkgs.chromium` and
`pkgs.llm-agents.agent-browser`, on the belief stated in its own comment
("agent-browser … Needs chromium"). But `agent-browser` already brings its own
pinned Chromium, so the closure carries two complete builds:

```
home-manager-path └── chromium-154.0.8037.97          → chromium-unwrapped-154.0.8037.97   (703.1 MiB)
home-manager-path └── agent-browser-0.38.2 └── chromium-154.0.8037.57
                                                      → chromium-unwrapped-154.0.8037.57   (703.0 MiB)
```

The referrer set is closed at both ends: `nix-store -q --referrers` on the
unwrapped build returns only its own wrapper, and on the wrapper returns only
`home-manager-path` (plus the `closure-info` derivation, which is this analysis
tooling reading the graph, not a consumer). **Nothing else in the closure wants
it.** Dropping the `pkgs.chromium` line therefore removes 703.1 MiB and breaks
nothing — even `agent-browser` keeps working, on its own copy.

**Applied 2026-10-10 and measured.** Building the frieren toplevel with the line
gone removes exactly four paths and nothing else:

| Own size | Path |
| --- | --- |
| 703.1 MiB | `chromium-unwrapped-154.0.8037.97` |
| 19.6 KiB | `chromium-unwrapped-154.0.8037.97-sandbox` |
| 4.3 KiB | `chromium-154.0.8037.97` |
| 200.0 B | `chromium-154.0.8037.97-sandbox` |
| **703.2 MiB** | **total — 4 paths** |

There is **no dependency cascade**: every shared dependency of that Chromium
stays alive because the `.57` copy `agent-browser` still needs it. So the
Chromium-attributable reduction is the full 703.2 MiB. (The 703.1 MiB figure
quoted throughout is the unwrapped build alone; the complete four-path removal is
703.2 MiB.)

The duplicate report corroborates it independently: `reclaimable` falls
`5.1 GiB → 4.4 GiB` on the rebuilt closure while the group count stays 675 — the
`chromium-unwrapped` group (4 copies) simply shrinks to 2. Two different
measures, the same ~703 MiB.

Reproduce (the build is store-only — it does not switch the running system):

```bash
nix build --no-link --print-out-paths --no-write-lock-file \
  .#nixosConfigurations.frieren.config.system.build.toplevel
bash scripts/task/closure-menu.sh --root /nix/store/<new-toplevel> summary
bash scripts/task/closure-menu.sh members chromium-unwrapped
nix-store -q --requisites /run/current-system | sort > /tmp/old
nix-store -q --requisites <new-toplevel> | sort > /tmp/new
comm -23 /tmp/old /tmp/new    # the removed set
```

### L2 — `home-manager-path` as the default dumping ground · **candidate, ~2.5 GiB**

The nine packages in §3 total ≈ 2.5 GiB and are all interactive tooling. None of
them is a systemd unit or a driver, so none of them *needs* to be in the boot
closure of a headless NAS. They are the natural first cohort for tier B/C below.

### L3 — `mbrola-voices` · **644.7 MiB, candidate**

```
system-path └── speech-dispatcher-0.12.1 └── mbrola-3.3 └── mbrola-voices-0-unstable-2020-03-30
```

A full MBROLA voice set, on a machine with no desktop session. Confirm with
`task dev:closure:menu -- why mbrola-voices`; if nothing on frieren actually
synthesises speech, this is the cleanest single removal after L1.

### L4 — `intel-graphics-compiler` · **264.6 MiB, candidate**

```
etc/tmpfiles.d/graphics-driver.conf └── graphics-drivers └── intel-compute-runtime-legacy1-… └── intel-graphics-compiler-2.34.4
```

An OpenCL/compute runtime reaching the closure through `hardware.graphics`. The
frieren iGPU (Intel UHD 620) does not need the compute runtime to drive a
display. Confirm with `task dev:closure:menu -- why intel-graphics-compiler`.

### L5 — `libreoffice` behind a single service · **1.5 GiB, candidate**

The biggest single path in the closure, reachable through exactly one unit:

```
etc └── system-units └── unit-stirling-pdf.service └── libreoffice-…-wrapped └── libreoffice-26.8.0.3
```

`stirling-pdf` needs a LibreOffice instance to convert Office documents. That is
legitimate — but it means 1.5 GiB of the closure exists to serve one HTTP
service's document conversion. Worth deciding deliberately rather than by
inheritance: whether the service is worth its weight, or whether conversion
belongs on the machine that requests it.

```bash
task dev:closure:menu -- why libreoffice
```

### L6 — Duplicate versions across subsystems · **5.1 GiB optimistic / 675 groups**

Two copies of one package in one closure buys nothing. The report ranks groups by
the size of the redundant copy (total minus the largest member), so the figure is
an upper bound: it assumes each group can collapse to exactly one build.

Top groups:

| Wasted | Copies | Group |
| --- | --- | --- |
| 703.1 MiB | 4 | `chromium-unwrapped` (see L1) |
| 349.3 MiB | 2 | `electron-unwrapped` (43.7.7 + 42.11.10) |
| 254.0 MiB | 3 | `python3.14-torch` |
| 218.4 MiB | 10 | `python3` |
| 187.6 MiB | 2 | `uptime-kuma` |
| 138.6 MiB | 2 | `openvino` |

A group is a *candidate*, never a fact: the version-stripping key is a heuristic,
and two versions can be genuinely required (a client and a daemon, say). That is
why `reduce` prints every concrete store path — the decision is made by looking at
the copies, not the total.

```bash
task dev:closure:menu -- reduce 15
task dev:closure:menu -- members electron-unwrapped
```

### L7 — The `other` bucket is not a subsystem · **analysis lever**

66.8% of the closure (2688 packages) lands in `other` because
`subsystemOf`'s ordered pattern list has no rule for it. That is fine for a
bucket-of-last-resort, but it means the largest slice of the graph is opaque —
the top of `other` is simply the top of the closure. Splitting `other` (nixpkgs
ecosystems already present: `qt`/`gtk` are classified, but `dotnet`, `haskell`,
`mono`, `texlive`, `wasm` are not) would make the breakdown self-explaining.
Note this is a *readability* lever, not a size lever.

## 5. The direction: three tiers instead of one

The tooling above makes the argument for the architecture. Today there is only
one tier, because `home.packages` is where everything goes and it all lands in the
boot closure.

| Tier | What belongs | Mechanism | In the closure? |
| --- | --- | --- | --- |
| **A — runtime** | systemd units, drivers, kernel, firmware | `environment.systemPackages`, modules | yes, by definition |
| **B — interactive** | editors, language servers, agents you actually launch | **devShells**, `nix shell` | no |
| **C — one-shot** | converters, format-specific tools used occasionally | **`nix run .#<tool>`** | no |

Tier B already half-exists: `modules/config/shells/*` defines `flaskpy`,
`jekyll`, `yarn`, `pdf`, `yt`, `kali`, `pi`, `replit`, `shell` (wired in
`flake/devshells.nix`). The problem is that the *boundary is not enforced* — a
tool added to a shell and to `home.packages` is in the closure anyway, and
nothing surfaces the overlap.

**Tier C is the actual gap.** Both flake outputs are empty:

```nix
# flake/packages.nix
lib.genAttrs systems.default (_: {})
# flake/outputs.nix:19
apps = lib.genAttrs systems.default (_: {});
```

There is currently **no `nix run` path at all**, so a tool used once a month must
be installed permanently. That is the concrete blocker to the `nix shell`
direction, and the cheapest thing to fix.

### First move

Populate `flake/packages.nix` / `apps` with the fleet-wide CLI tools currently in
`home.packages`, then drop them from `home.packages` on hosts that do not run them
continuously (start with the §3 cohort on frieren). `nix run .#qmd` then resolves
from the store, which on a warm host is effectively immediate.

Trade-off, stated plainly: `nix run` is a store lookup on every invocation and a
fetch if the path is not yet local. That is the price of not carrying the closure.
For tools used constantly it is the wrong trade; for tools used occasionally it is
the whole point. The three-tier table is how the decision gets made explicitly
instead of by default.

## 6. Verification protocol

1. **Never trust one view.** `task dev:closure:native:diff` is the gate: it checks
   the five rendered views byte-for-byte, the summed `narSize`, and the path set.
2. **A removal claim needs a referrer check**, not just a size reading. `why`
   gives the shortest chain; `members`/`nix-store -q --referrers` give the
   neighbours. L1 is safe precisely because the referrer set is closed.
3. **Changing the tree changes the closure.** Any edit alters
   `config.system.build.toplevel.outPath`, so before/after sizes come from two
   distinct builds — compare closed store paths, not the live symlink.
   This is not a formality. The L1 removal moved the closure `3949 → 3945` paths
   and `34.5 → 33.8 GiB`, a net of only **−701.2 MiB** against a true **−703.2
   MiB** removal, because the same rebuild rewrote `etc`, `system-units` and the
   `home-manager-*` farm (27 paths removed, 23 added) *and* carried an unrelated
   toolchain swap that was committed but not yet deployed on frieren
   (`nixpkgs-fmt` out, `statix`+`deadnix` in). Read totals as context and the
   **set difference** as the answer. Attribute per group — mixing in unrelated
   drift is how a 703 MiB win gets reported as 701.
4. **Evaluate only hosts `inventory.toml` calls `active`.** Preserved and WIP
   hosts are not deployed and cannot regress; spending evals on them is waste.
   For L1 that meant one active host per chain it feeds — `frieren` (nixos) and
   `guckloch` (containers) plus `kali` (home). No active host is `darwin`
   (`cassini` is preserved), so that chain was correctly **not** checked.
## 7. Non-goals

- This does not propose deleting services to make numbers smaller. L5 is a
  question about a service's value, not a directive.
- The duplicate figure is a ceiling, not a projection. It is not a promise that
  5.1 GiB is available.
- `other` is coarse on purpose in one respect: `subsystemOf` matches in order and
  a package can legitimately belong to more than one bucket. Refining it changes
  *reporting*, never the store.
