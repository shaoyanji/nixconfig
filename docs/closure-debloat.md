# Closure debloat — from 33.8 GiB toward essentials

Measured on **frieren** at generation 81 (`/run/current-system`,
`nixos-system-frieren-26.11.20261005.aa48d34`), after the duplicate-Chromium
removal in `docs/closure-reduction.md`.

This document is the *plan*. `docs/closure-reduction.md` is the *tooling and
evidence*; read it first if a number here looks unmotivated.

## 1. Reproduce

```bash
task dev:closure:attribution          # the owner table below
task dev:closure:menu -- reduce 15     # duplicate versions with every copy
task dev:closure:native                # subsystem rollup
task dev:closure:menu -- why <pkg>     # dependency chain for one package
```

## 2. Why a top-N list lies, and what to read instead

A plain "biggest paths" ranking overstates every candidate, because store paths
are shared. Attribution over the real reference graph splits the closure three
ways:

| | Bytes | Share | Meaning |
| --- | --- | --- | --- |
| **Exclusive** | 15.4 GiB | 46% | reachable from exactly one owner — removable with that owner alone |
| **Shared** | 16.2 GiB | 48% | reachable from 2+ owners — returns only when the **last** owner goes |
| **Core** | 2.2 GiB | 6% | no service or farm reaches it (kernel, initrd, firmware, fonts) |

`task dev:closure:attribution` computes this from the closure-info `registration`
file. Two mechanics matter:

- **Ancestor branches are pruned.** `user-environment` reaches
  `home-manager-path`, and the Home Manager activation unit reaches everything it
  activates. Keeping both makes every descendant "reachable from 2 branches", so
  both read as **0**. Only branches no other branch reaches are kept — 189
  candidates reduce to 186.
- **A shared store path repeated across farms costs nothing.** 47 paths appear in
  both `system-path` and `home-manager-path`; the store dedupes them. That is
  listed in the tool's output only to stop anyone "fixing" it as waste.

The practical consequence: **you cannot reach the ~16 GiB of shared substrate by
removing services one at a time.** Glibc, Python, LLVM, GTK and Mesa are shared
precisely because many owners need them. Per-owner savings are capped by that
owner's exclusive bytes.

## 3. Owner table (measured)

Top owners by **exclusive** bytes:

| Exclusive | Owner | Biggest exclusive paths |
| --- | --- | --- |
| **9.4 GiB** | `home-manager-devji.service` (i.e. `home.packages`) | qmd 904.2, chromium 703.0, zen-beta-bin 400.4 |
| 1197.0 MiB | `systemd-tmpfiles-resetup.service` | llvm-21.1.8-lib 550.4, mesa 274.4, intel-graphics-compiler 264.5 |
| 1008.2 MiB | `stirling-pdf.service` | openjdk-25 655.6, stirling-pdf 348.7 |
| 929.2 MiB | `home-assistant.service` | homeassistant 390.2, HA frontend 270.0, botocore 110.9 |
| 418.0 MiB | `immich-server.service` | immich 355.9, geodata 54.1 |
| 379.6 MiB | `uptime-kuma.service` | npm-deps 191.2, uptime-kuma 187.6 |
| 371.8 MiB | `immich-machine-learning.service` | openvino 141.6, onnxruntime 70.4 + 56.3 |
| 301.5 MiB | `readarr.service` | readarr 217.3, dotnet-runtime 70.7 |
| 231.6 MiB | `influxdb2.service` | influxdb 128.7, libflux 81.4 |
| 212.6 MiB | `plex.service` | plexmediaserver 211.6 |
| 204.3 MiB | `tika.service` | openjdk + tika |
| 179.9 MiB | `vaultwarden.service` | vaultwarden 37.6 (rest is its exclusive deps) |
| 177.2 MiB | `gotenberg.service` | openjdk-headless-minimal-jre 89.2, gotenberg 79.3 |
| 61.5 / 53.0 / 51.0 / 50.0 / 42.4 MiB | `lidarr` / `scrutiny` / `sonarr` / `radarr` / `prowlarr` | the app itself |
| 36.4 / 36.0 MiB | `systemd-udevd` / `cups` | **hplip 36.0 + 34.2** |
| 31.0 MiB | `greetd.service` | dms-greeter 28.8 |
| 27.4 MiB | `harmonia.service` | harmonia 27.3 |

Core 2.2 GiB, top of 373 paths:

| Size | Path |
| --- | --- |
| 809.5 MiB | `linux-firmware-20260916-zstd` |
| 399.4 MiB | the pinned `<nixpkgs>` source, twice (see T1-3) |
| 228.4 MiB | `nerd-fonts-jetbrains-mono-3.5.0+2.304` |
| 138.3 MiB | `linux-6.12.112-modules` |
| 116.4 MiB | `noto-fonts-cjk-sans` + `serif` |
| 80.1 MiB | `python3-3.14.7` |
| 43.8 MiB | `initrd-linux-6.12.112` |
| 33.2 MiB | `material-symbols` |

## 4. Tier 1 — config-only, no capability lost

**T1-1 · Duplicate Chromium — 703.2 MiB · DONE.** Removed and deployed; see
`docs/closure-reduction.md` §4 L1.

**T1-2 · Fonts — ~260 MiB.** `nerd-fonts-jetbrains-mono` alone is **228.4 MiB** of
glyph variants, plus `material-symbols` at 33.2 MiB. Both reach the core through
`etc/fontconfig-etc`, i.e. `fonts.packages`. Keeping one Nerd Font subset (or the
plain JetBrains Mono, ~3 MiB) instead of the full patched family is the largest
single config-only win after T1-1. Keep `noto-fonts-cjk` only if CJK text is
actually rendered.

```bash
task dev:closure:menu -- why nerd-fonts-jetbrains-mono
```

**T1-3 · `<nixpkgs>` source pinned in `nix.conf` — ~399 MiB.**
`etc/nix/nix.conf` line 12 is
`nix-path = nixpkgs=<store>-mn8gk4r87grls81sp5bjgfwcanrfqhlj-source`, so the whole
pinned nixpkgs **source tree** ships in the system closure (the two paths are the
tree and its wrapper). `nix.settings.nix-path` is set in
`modules/global/global.nix`. Replacing the store path with a flake reference
(`nixpkgs=flake:nixpkgs`) or dropping `nix-path` where nothing needs `<nixpkgs>`
removes it.

> Coupling to be aware of: `scripts/task/closure-graph.sh` resolves `<nixpkgs>`
> via `import <nixpkgs>`, so it depends on this entry. Change one, change both.

**T1-4 · `mbrola-voices` — 644.7 MiB.**
`system-path └── speech-dispatcher └── mbrola └── mbrola-voices`. A full MBROLA
voice set on a headless NAS. If nothing on frieren synthesises speech, this is the
second-largest clean removal.

**T1-5 · `intel-compute-runtime-legacy1` / `intel-graphics-compiler` — 264.5 MiB.**
Reaches the closure through `etc/tmpfiles.d/graphics-driver.conf └── graphics-drivers`.
An OpenCL compute runtime, pulled for an iGPU that only needs to drive a display.

**T1-6 · `hplip` via CUPS — ~70 MiB.** HP printer drivers, reached twice
(`cups.service` 36.0 + `systemd-udevd` 36.4). If `services.printing` is on for no
reason, both go.

**T1-7 · Duplicate versions — up to 4.4 GiB (optimistic).** 675 groups still hold
a redundant copy. The real yield is lower: the number assumes every group
collapses to one build, and some pairs are legitimately two artefacts (a client
and a daemon). Start with the ranked report, not the total.

```bash
task dev:closure:menu -- reduce 20
```

**Tier 1 subtotal: ~2.3 GiB of concrete, config-only savings** (703 + 260 + 399 +
645 + 264 + 70 MiB), before the fuzzy duplicate work.

## 5. Tier 2 — service decisions (capability trade-offs)

This is where the remaining bytes are, and every item is a judgement about whether
the service earns its closure:

| Service | Exclusive | Note |
| --- | --- | --- |
| `stirling-pdf` | 1008.2 MiB | 655.6 MiB of it is **openjdk-25** for one HTTP converter |
| `home-assistant` | 929.2 MiB | automation platform |
| `immich` (server + ML) | 789.8 MiB | photo platform; ML half is openvino/onnxruntime |
| the `*arr` stack | 506.4 MiB | readarr + lidarr + sonarr + radarr + prowlarr |
| `uptime-kuma` | 379.6 MiB | monitoring |
| `influxdb2` | 231.6 MiB | time-series for the above |
| `plex` | 212.6 MiB | second media server (Jellyfin is separate) |
| `tika` | 204.3 MiB | document extraction for paperless |
| `vaultwarden` | 179.9 MiB | password vault |
| `gotenberg` | 177.2 MiB | another JVM document converter |
| `scrutiny` | 53.0 MiB | drive health |
| `harmonia` | 27.4 MiB | the LAN binary cache |

Two observations rather than recommendations: **there are three JVM-based
document/PDF services** (stirling-pdf, gotenberg, tika) costing ~1.4 GiB between
them, and **Plex and Jellyfin coexist** (Jellyfin's cost is inside the shared
substrate, Plex's 212.6 MiB is exclusive).

**Tier 2 subtotal: up to ~4.7 GiB** — but only if the services go.

## 6. Tier 3 — the 9.4 GiB Home Manager profile

`home.packages` is the single biggest owner in the closure, and nothing in it is a
systemd unit or a driver. It is interactive tooling that happens to be reachable
through `etc/user-environment/home-manager-path`, so it ships in the boot closure.

Worst offenders, each individually larger than most services:

| Size | Package | |
| --- | --- | --- |
| 904.2 MiB | `qmd` | worth its own investigation — large for a search tool |
| 703.0 MiB | `chromium` | via `agent-browser` (the surviving copy) |
| 400.4 MiB | `zen-beta-bin-unwrapped` | the desktop browser |
| 357.8 MiB | `zed-editor` | |
| 246.2 MiB | `tinymist` | |
| 217.5 / 216.9 MiB | `devenv` / `go` | |
| 208.9 MiB | `pandoc-cli` | |
| 199.9 / 162.2 MiB | `antigravity-cli` / `pi-coding-agent` | |
| 156.4 / 156.3 MiB | `pdfvision` / `hermes-agent` | |
| 146.3 / 106.4 MiB | `awscli2` / `rclone` | |
| 98.0 / 97.7 MiB | `kando` / `supabase-cli` | |

The top 15 alone are **4.3 GiB**. This is the cohort the three-tier model in
`docs/closure-reduction.md` §5 is for: move them to devShells or `nix run`
(which needs `flake/packages.nix` / `apps` filled in — both are still empty
attrsets), and drop them from `home.packages`.

Also in this tier: `home-manager-files` carries
`index-x86_64-linux` at **101.6 MiB** — the `nix-index` database. If recursive
`nix-locate` is not used, that is 101.6 MiB of static data.

## 7. Realistic projection

Arithmetic, not optimism — exclusive bytes are the ceiling per owner and the 16.2
GiB shared substrate does not move piecemeal:

| Step | Projected total |
| --- | --- |
| Today | 33.8 GiB |
| + Tier 1 (config-only) | **~31.5 GiB** |
| + Tier 1 and half of Tier 2 | **~29 GiB** |
| + all of Tier 2 | **~27 GiB** (you just deleted a lot of services) |
| + Tier 3 top 15 moved to `nix run` / devShells | **~23 GiB** |
| **Practical floor as configured** | **~16–17 GiB** — kernel, systemd, glibc, Python, LLVM, GTK, firmware |

So "down to essentials" is roughly a **16–17 GiB floor** for this host, and about
**23 GiB** is what you get from removing everything that is not a runtime
requirement. Twenty gigabytes is reachable, but only with most of Tier 2 and
Tier 3 done — the ~1 GiB one-shot fixes alone land near 31 GiB, not 20.

The fastest honest path to 20 GiB, in order: T1-1 (done) → T1-2 fonts → the top 15
of Tier 3 → the three JVM services → the `*arr` stack.

## 8. Method notes / cautions

- **Exclusive bytes are a ceiling, not a promise.** Removing an owner returns its
  exclusive set plus whatever becomes exclusively unreferenced — never the shared
  set, unless it was the last owner of those paths.
- **Rebuilds move the baseline too.** `etc`, `system-units` and `home-manager-*`
  are rewritten on every config change, so a ~700 MiB removal reads as ~701 MiB
  net. Compare set differences.
- **A shared path listed twice is not waste.** The store dedupes; only *different
  versions* cost bytes, which is what the duplicate report measures.
- **Evaluate only hosts `inventory.toml` calls `active`.**
- **Nothing here is applied.** Tier 1 items were measured and traced, not changed;
  only T1-1 has been removed, deployed and committed.
