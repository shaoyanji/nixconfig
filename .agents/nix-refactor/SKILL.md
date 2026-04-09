---
name: nix-refactor
description: |
  Safely refactor flake-based Nix configuration repos (NixOS, nix-darwin, Home Manager).
  Covers deduplication of home-manager sharedModules, extracting shared microVM/host
  networking profiles, bootloader overrides, dead-code cleanup, and `base-node` baseline
  consolidation. Use when the user asks to clean up, refactor, reorganise, or find
  refactoring opportunities in their Nix config flake. Also use when the user mentions
  closure bloat, module duplication, or wants to extract common NixOS patterns across hosts.
---

# Nix Flake Refactoring

Patterns and safety rules learned from refactoring a multi-host NixOS/nix-darwin/Home Manager flake with 15+ hosts.

## Core principle: module chain awareness

Flakes compose modules in chains. Before changing any global module, trace its chain:

```
globalModulesImpermanence → globalModulesNixos → nixos.nix
globalModulesContainers   → global (noDE.nix)
globalModulesMacos        → global (macos.nix)
globalModulesHome         → standalone Home Manager configs
```

**Rule:** If module B is included in chain A → B, do NOT redefine in B what A already sets. It will merge at evaluation time and may import the role/user modules twice.

**Rule:** `base-node.nix` (profile) provides the common NixOS baseline for all hosts: kernel packages, SSH, keyd, networkmanager, console, sops, user `devji`, common dev packages, and boot loader defaults (`systemd-boot` + `EFI`). Container hosts get it via `globalModulesContainers`, desktop hosts via `desktop-client.nix`. If a host imports `base-node.nix` directly, do NOT add it a second time if it already gets it transitively.

## Audit with Nix, not grep

The biggest mistake when refactoring a flake is grepping for strings across files. `grep` tells you what text appears where — it does **not** tell you what actually evaluates, what composes into a closure, or why a package ends up in a host's store paths. Always use Nix's own tools to understand the DAG.

### Map the flake structure

```bash
# See every output the flake produces
nix flake show --json 2>/dev/null | jq 'keys'

# See all nixosConfigurations
nix flake show --json 2>/dev/null | jq '.nixosConfigurations | keys'

# See all homeConfigurations
nix flake show --json 2>/dev/null | jq '.homeConfigurations | keys'
```

### Get the actual closure, not grep results

```bash
# Full closure with sizes — JSON machine-readable
nix path-info --json .#nixosConfigurations.thinsandy.config.system.build.toplevel \
  | jq 'map({path: (.path | split("/") | last), size}) | sort_by(-.size) | .[:20]'

# Count derivations (your single metric for closure changes)
nix path-info .#nixosConfigurations.thinsandy.config.system.build.toplevel | wc -l

# Human-readable closure summary
nix path-info -rsS .#nixosConfigurations.thinsandy.config.system.build.toplevel | tail -1
```

### Diagnose "why is this package here?" — use `nix why-depends`

```bash
# Why is dms in thinsandy's closure? (It shouldn't be!)
nix why-depends \
  .#nixosConfigurations.thinsandy.config.system.build.toplevel \
  .#nixosConfigurations.poseidon.config.system.build.toplevel 2>&1 | head -20

# Better: find a specific package in the closure
nix path-info .#nixosConfigurations.thinsandy.config.system.build.toplevel \
  | grep -i dms
```

If the grep returns results, dms is in the container closure. If it returns nothing, it's clean. This is the **real** check — not grepping source files for "dms" and hoping.

### Compare closures before and after a change

```bash
# Before: capture closure
nix path-info \
  .#nixosConfigurations.thinsandy.config.system.build.toplevel \
  > /tmp/closure-before.txt

# After refactoring: capture new closure
nix path-info \
  .#nixosConfigurations.thinsandy.config.system.build.toplevel \
  > /tmp/closure-after.txt

# Derivations added
diff /tmp/closure-before.txt /tmp/closure-after.txt | grep '^>' | wc -l

# Derivations removed
diff /tmp/closure-before.txt /tmp/closure-after.txt | grep '^<' | wc -l

# The ones that matter — what was added?
diff /tmp/closure-before.txt /tmp/closure-after.txt | grep '^>' | head -20
```

### Check actual config attributes (not file contents)

```bash
# What packages are actually enabled?
nix eval --json .#nixosConfigurations.poseidon.config.environment.systemPackages \
  | jq 'map(.name or .pname) | sort'

# What modules were imported?
nix eval --json .#nixosConfigurations.poseidon.config.system.modules \
  2>/dev/null | jq 'length'

# Is a specific option set?
nix eval .#nixosConfigurations.poseidon.config.networking.hostName
```

### The grep antipattern (what NOT to do)

```bash
# WRONG: grepping for text tells you nothing about evaluation
grep -r "allowUnfree" modules/        # might be commented out!
grep -r "sharedModules" modules/      # doesn't show which chain it's in
grep -r '"devji"' modules/            # doesn't tell you which hosts use it
grep -r "dms\." modules/              # doesn't tell you which closures include it

# RIGHT: ask Nix what actually evaluates
nix eval .#nixosConfigurations.poseidon.config.nixpkgs.config.allowUnfree  # true
nix path-info .#nixosConfigurations.thinsandy... | grep dms                 # empty = good
```

**Rule of thumb:** If you can express a question as `nix eval` or `nix path-info`, do that. Grepping is only useful for finding **where to make edits** once you already know **what to change** — and even then, use `nix eval` first to confirm the current state.

## Refactoring checklist

### 1. Identify duplication hotspots

Search for these common duplication patterns across the repo:

| Pattern | Where it appears | Safe extraction |
|---|---|---|
| `home-manager.sharedModules` | nixos.nix, noDE.nix, macos.nix, impermanence.nix, module-sets.nix | Extract to `modules/global/home-manager-shared.nix`; **only** let desktop modules (nixos.nix, impermanence.nix) import it — **NOT** container modules |
| Boot loader systemd-boot + EFI | Every host config that doesn't use GRUB | Move to `base-node.nix` — all hosts that import it inherit the defaults automatically |
| `allowUnfree = true` | global.nix + per-host configs | Keep only in `modules/global/global.nix`; remove from host files |
| MicroVM bridge/NAT/dispatcher | Each host that runs microVMs (~40 lines each) | Extract to `modules/profiles/microvm-host.nix` parameterized by `natExternalInterface` |
| Bootloader systemd-boot → grub override | Each BIOS-boot host | Extract to `modules/profiles/grub-boot.nix` parameterized by `device` |
| Hardcoded username/homeDirectory | 15-20+ files | Create `modules/global/user.nix` constants file; add cross-reference comments; full migration is invasive so do it gradually |
| SSH + user + console boilerplate | Hosts that skip `base-node.nix` | Import `base-node.nix` and remove the duplicated blocks |

### 2. **CRITICAL: Container vs desktop module boundary**

This is the most common and most expensive regression:

**Desktop hosts** (poseidon, ares, schneeeule, aceofspades, ancientace) need full `sharedModules` including `dms` (DankMaterialShell), `niri`, `nixvim`.

**Container hosts** (mtfuji, kellerbench, thinsandy, guckloch, applevalley, minyx) should have **lean** `sharedModules` — sops, nixvim, nix-index only. Adding dms/niri to containers blows up closure size because those modules pull in Wayland compositors, KDE portals, display managers, and font stacks.

When creating a "canonical" sharedModules list:
- The **desktop** list goes in `home-manager-shared.nix` (includes dms, niri)
- The **container** list stays inline in `noDE.nix` (no dms, no niri)
- Do NOT make container modules import the desktop sharedModules file

### 3. Parameterized modules need all arguments

When extracting a pattern like GRUB boot override into a callable module:

```nix
# modules/profiles/grub-boot.nix
{ device ? "/dev/sda", lib, ... }: { ... }
```

The caller **must** pass `lib` explicitly because the file is imported as a function call, not as a module that auto-receives arguments:

```nix
(import ../../modules/profiles/grub-boot.nix { inherit lib; device = "/dev/sda"; })
```

Forgetting `lib` causes `attribute 'lib' missing` at evaluation — a fast, obvious failure, but still a regression.

### 4. Dead code removal

Long-lived Nix configs accumulate:
- Commented-out substituters and cache keys (global.nix)
- Commented-out package lists and cask entries (cassini/configuration.nix)
- Commented-out services ("# services.sunshine = { ... }")
- `"# Did you read the comment?"` suffixes on stateVersion
- Empty package lists with commented entries (`environment.systemPackages = with pkgs; [ # foo ]`)
- Commented-out imports, programs, and entire service blocks in host configs (penguin.nix, applevalley, minyx)
- Per-host `allowUnfreePredicate` when `global.nix` already sets `allowUnfree = true`
- `mkForce` on user declarations when `base-node.nix` already defines the user canonically

Clean all of these. They add no value and obscure the actual configuration.

### 5. impermanence module design

`impermanence.nix` is included in `globalModulesImpermanence` which already includes `globalModulesNixos` which includes `nixos.nix`. So `impermanence.nix` should **only** set persistence rules — it should NOT redefine `home-manager.useGlobalPkgs`, `sharedModules`, `extraSpecialArgs`, or `users.devji.imports`. Those come from `nixos.nix` via the module chain.

```nix
# impermanence.nix — ONLY persistence
{ config, pkgs, inputs, ... }: {
  home-manager.users.devji.home = {
    persistence."/persist/home" = { ... };
  };
}
```

### 6. disko stays host-adjacent

`hosts/common/disko.nix` should NOT move to `modules/profiles/`. Disk layout (device paths, LVM VG names, partition sizes) is inherently host-specific. The `hosts/common/` location is appropriate for the rare case where two hosts genuinely share identical disk topology.

### 7. Dead module detection

Before declaring a module "unused," confirm with Nix:

```bash
# Check if anything references the file
grep -r "home-manager-base" modules/ flake/ hosts/

# Better: grep for the bare name (no .nix suffix) — imports often omit it
grep -r "home-manager-base" modules/ flake/ hosts/
```

If zero results, the module is dead code and can be safely deleted. Always verify with the eval battery after deletion.

**Common dead module patterns found in practice:**
- `home-manager-base.nix`: dead when `home-manager-shared.nix` serves the same purpose and no host imports it
- `unfree.nix`: dead when `global.nix` sets `allowUnfree = true` unconditionally (predicate has zero effect)
- `base-desktop.nix`: dead when it's only a 3-line wrapper importing `desktop-client.nix`
- `hmSharedModules` in `module-sets.nix`: dead when exported but never consumed by any host wiring

### 8. `allowUnfree` predicate vs blanket — a behavioral gotcha

**Critical:** Switching from `allowUnfree = true` to `allowUnfreePredicate` is a **behavior change**, not just a cleanup. The predicate whitelist blocks all unfree packages not explicitly listed, including ones the user may implicitly depend on (nvidia drivers, plexmediaserver, hplip, cups filters, etc.).

**Safe approach:** If the user just wants to remove redundant `allowUnfree` declarations across host files, keep `allowUnfree = true` in `global.nix` and remove the per-host duplicates. Only switch to predicate-based allow if the user explicitly requests a stricter unfree policy — and warn them that `nix path-info` on toplevel will surface blocked packages.

### 9. Verification after every change

After each refactoring step, run the full evaluation protocol from the **Evaluation protocol for the codespaces environment** section below. In order:
1. Baseline eval battery (all host categories)
2. Closure inspection (`nix path-info` derivation counts)
3. If anything grew, diagnose with `nix path-info --json` and `grep` against closure paths
4. If committing, capture closure diff for review

## Evaluation protocol for the codespaces environment

This repo has a live Nix flake that can be evaluated from the codespace. Every refactoring change must be verified with **evaluation, closure inspection, and dry-run**. The checks are fast (seconds each) and catch closure regressions before they compound.

### Step 1: Baseline eval battery (run after EVERY change)

```bash
# One host per category — if any fails, the change broke its closure
echo "=== Container ===" && \
nix eval .#nixosConfigurations.thinsandy.config.networking.hostName && \
echo "=== Container2 ===" && \
nix eval .#nixosConfigurations.mtfuji.config.networking.hostName && \
echo "=== Desktop ===" && \
nix eval .#nixosConfigurations.poseidon.config.networking.hostName && \
echo "=== Impermanence ===" && \
nix eval .#nixosConfigurations.ares.config.networking.hostName && \
echo "=== Impermanence2 ===" && \
nix eval .#nixosConfigurations.schneeeule.config.networking.hostName && \
echo "=== Home standalone ===" && \
nix eval .#homeConfigurations.penguin.config.home.username && \
echo "=== BIOS-boot ===" && \
nix eval .#nixosConfigurations.aceofspades.config.networking.hostName && \
echo "=== BIOS-boot2 ===" && \
nix eval .#nixosConfigurations.ancientace.config.networking.hostName && \
echo "=== ALL OK ==="
```

**Interpretation:**
- All return quoted strings → green, change is safe
- Any error about missing attribute, failed assertion, or `lib` missing → red, revert the change and diagnose

### Step 2: Closure inspection (run after structural changes)

```bash
# Count derivations — your single metric for closure growth
echo "Container derivations:" && \
nix path-info .#nixosConfigurations.thinsandy.config.system.build.toplevel | wc -l
echo "Desktop derivations:" && \
nix path-info .#nixosConfigurations.poseidon.config.system.build.toplevel | wc -l
```

**Interpretation:** Container count should stay well below desktop. If container jumps toward desktop levels, desktop modules leaked into the container chain.

**Note:** `nix path-info` may fail in the codespace if store paths are not locally cached (the paths are built on the actual host, not in the remote build environment). If path-info fails, the eval battery (Step 1) is still a sufficient correctness check.

### Step 3: Diagnose regressions with `nix why-depends`

When Step 2 shows a container closure grew:

```bash
# List the top 20 largest paths in the container closure
nix path-info --json .#nixosConfigurations.thinsandy.config.system.build.toplevel \
  | jq 'map({path: (.path | split("/") | last), size}) | sort_by(-.size) | .[:20]'

# Check if desktop-only packages snuck in
nix path-info .#nixosConfigurations.thinsandy.config.system.build.toplevel \
  | grep -iE "dms|niri|kde|plasma"
```

If any desktop-only packages appear, that's the regression. Trace which module introduced it.

### Step 4: Capture closure diff for commit review

```bash
# Before making changes:
nix path-info .#nixosConfigurations.thinsandy.config.system.build.toplevel \
  > /tmp/closure-before.txt
nix path-info .#nixosConfigurations.poseidon.config.system.build.toplevel \
  > /tmp/closure-before-desktop.txt

# After changes:
nix path-info .#nixosConfigurations.thinsandy.config.system.build.toplevel \
  > /tmp/closure-after.txt
nix path-info .#nixosConfigurations.poseidon.config.system.build.toplevel \
  > /tmp/closure-after-desktop.txt

# What was added/removed?
echo "Container: added $(diff /tmp/closure-before.txt /tmp/closure-after.txt | grep '^>' | wc -l) derivations"
echo "Container: removed $(diff /tmp/closure-before.txt /tmp/closure-after.txt | grep '^<' | wc -l) derivations"
echo "Desktop: added $(diff /tmp/closure-before-desktop.txt /tmp/closure-after-desktop.txt | grep '^>' | wc -l) derivations"
```

### Example eval cases

These are the prompts a user would give — they cover the real refactoring scenarios:

#### Eval 1: "Extract common microVM networking"

**Prompt:** "poseidon and ancientace both have identical microVM bridge and NAT config — can you deduplicate that?"

**Expected agent behaviour:**
1. Creates `modules/profiles/microvm-host.nix` parameterized by `natExternalInterface`
2. Removes duplicated blocks from both host files
3. Runs the baseline eval battery — all 8 hosts pass
4. Runs closure dry-run on both modified hosts — counts unchanged
5. Commits with descriptive message

**Pass criteria:** All 8 evals succeed; no closure growth; both hosts still produce correct hostName.

#### Eval 2: "Deduplicate home-manager sharedModules"

**Prompt:** "home-manager.sharedModules is repeated in nixos.nix, noDE.nix, impermanence.nix, and macos.nix — can you extract it?"

**Expected agent behaviour:**
1. Creates `modules/global/home-manager-shared.nix` with the **desktop** list (dms, niri, nixvim, sops, nix-index)
2. Makes nixos.nix and impermanence.nix import it
3. **Does NOT** make noDE.nix import it — container hosts must keep their lean inline list
4. **Does NOT** make macos.nix import it — macOS doesn't use dms/niri
5. Runs the baseline eval battery — all pass
6. Runs closure dry-run on thinsandy (container) — count stable
7. Runs closure dry-run on poseidon (desktop) — count stable

**Pass criteria:** All 8 evals succeed; container closure does NOT grow; desktop closure unchanged.

**Fail criteria (regression trap):** Agent makes noDE.nix import home-manager-shared.nix, pulling dms/niri into all container closures. The closure dry-run on thinsandy reveals the jump.

#### Eval 3: "Clean up dead code"

**Prompt:** "There's a ton of commented-out stuff in global.nix, cassini, and poseidon — can you clean it up?"

**Expected agent behaviour:**
1. Removes commented-out substituters, cache keys, packages, services from global.nix
2. Removes commented-out casks and brews from cassini/configuration.nix
3. Removes commented-out blocks from poseidon/configuration.nix
4. Removes empty `environment.systemPackages = with pkgs; [ # foo ]` lists
5. Runs the baseline eval battery — all pass
6. Commits

**Pass criteria:** All 8 evals succeed; no functional change; file sizes reduced.

#### Eval 4: "Extract GRUB bootloader override"

**Prompt:** "aceofspades and ancientace both override systemd-boot to grub with the same pattern — extract it"

**Expected agent behaviour:**
1. Creates `modules/profiles/grub-boot.nix` with parameters `device` and `lib`
2. Updates aceofspades to import it with `{inherit lib; device = "/dev/sda";}`
3. Updates ancientace to import it with `{inherit lib; device = "nodev";}`
4. **Crucially** passes `lib` — the module is called as a function, not imported as a bare path
5. Runs the baseline eval battery — all pass
6. Runs closure dry-run on both hosts — counts stable

**Fail criteria (common mistake):** Forgets `lib` parameter — `nix eval` fails immediately with "function called without required argument 'lib'".

#### Eval 5: "Fix impermanence.nix duplication"

**Prompt:** "impermanence.nix defines the same home-manager settings as nixos.nix — that can't be right"

**Expected agent behaviour:**
1. Recognises `globalModulesImpermanence` includes `globalModulesNixos` which includes `nixos.nix`
2. Removes redundant `useGlobalPkgs`, `sharedModules`, `extraSpecialArgs`, `users.devji.imports` from impermanence.nix
3. Keeps only the `home.persistence` block
4. Runs the baseline eval battery — all pass (ares and schneeeule use this chain)

**Pass criteria:** `nix eval .#nixosConfigurations.ares.config.networking.hostName` returns `"ares"`; same for schneeeule.

#### Eval 6: "Remove redundant allowUnfree"

**Prompt:** "allowUnfree is set in global.nix but also in poseidon and schneeeule — is that redundant?"

**Expected agent behaviour:**
1. Confirms global.nix already sets `nixpkgs.config.allowUnfree = true`
2. Removes it from poseidon and schneeeule/nvidia.nix
3. Keeps `nvidia.acceptLicense` and `cudaSupport` (those are NVIDIA-specific, not covered by global)
4. Runs the baseline eval battery — all pass

**Pass criteria:** All evals succeed; NVIDIA hosts still build.

#### Eval 7: Negative — "Remove the home-manager block from noDE.nix to simplify"

**Prompt:** "noDE.nix is just home-manager — can I just remove it and put the config in the host files directly?"

**Expected agent behaviour:**
1. Explains that noDE.nix is referenced by `globalModulesContainers` which is used by 6+ hosts
2. Removing it would break all container hosts
3. Suggests extracting sharedModules instead (Eval 2 pattern)
4. Does NOT delete the file

**Pass criteria:** File is not deleted; agent explains the module chain and suggests a safer alternative.

#### Eval 8: "Make my refactoring safe — add verification"

**Prompt:** "I'm about to refactor my home-manager config — what checks should I run after each change?"

**Expected agent behaviour:**
1. Provides the baseline eval battery command (8 hosts across all categories)
2. Provides the closure dry-run command for structural changes
3. Explains the interpretation: all strings = green, any error = red
4. Explains the container vs desktop closure-size expectation
5. Optionally provides the specific package presence check for dms/niri

**Pass criteria:** Commands are complete, copy-pasteable, and cover all host categories.

#### Eval 9: "Consolidate base-node and clean up hosts"

**Prompt:** "go through a pass on this and list 10 major refactor spots"

**Expected agent behaviour:**
1. Maps all 13 nixosConfigurations and their module chains
2. Identifies duplication: boot loader boilerplate across hosts, kellerbench skipping base-node, dead modules (home-manager-base, unfree, base-desktop), unused exports (hmSharedModules), empty systemPackages blocks, commented-out host config
3. For each fix: makes the change, runs the eval battery, verifies
4. For kellerbench specifically: adds `base-node.nix` import, removes duplicated SSH/user/boot/sops config, removes `lib.mkForce` on user fields
5. For boot loader: moves `systemd-boot.enable = true` + `canTouchEfiVariables = true` into `base-node.nix`, removes from mtfuji/thinsandy/kellerbench
6. Cleans dead code: penguin.nix (~114 lines), applevalley (~32 lines), minyx (~119 lines), thinsandy hardware config
7. Documents changes in README.md and docs/userland-module-map.md

**Pass criteria:** All evals pass for every host category; kellerbench eval succeeds (it previously lacked base-node); no closure regression.

## Things to avoid

- **Do not do a broad host rewrite in one pass** — refactor one pattern at a time, verify, commit
- **Do not move secrets or encrypted data** — `.sops.yaml`, `secrets/`, `*.yaml` encrypted files stay put
- **Do not silently widen system support** — if a module is x86_64-only, keep it that way
- **Do not merge host-local storage layout** — disko, partition sizes, mount points stay per-host
- **Do not assume Garnix persistence** — CI builds may not have local store artifacts
- **Do not switch `allowUnfree = true` to `allowUnfreePredicate` without warning** — this is a behavioral change that can block unfree packages the user implicitly depends on (nvidia drivers, plex, hplip, etc.)
- **Do not add `base-node.nix` to a host that already gets it transitively** — e.g., applevalley imports both `base-node.nix` and `desktop-client.nix`, but `desktop-client.nix` already imports `base-node.nix`
