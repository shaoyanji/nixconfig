# ChainAudit — the home-manager chains

Blast radius for any edit to the shared home-manager machinery, enumerated
2026-11-23 from `flake/host-inventory.nix` + `flake/module-sets.nix` (the same
projection `fleet-module-chains.md` renders — rerun `nix build .#artifacts.docs`
to verify against the tree). **No host configuration was edited for this audit.**

There are three chains, not one. Naming the wrong one is how a "small HM
change" lands on twelve hosts.

## Chain A — `featureModules.home` (`hmSharedModulesHome`)

The standalone-HM floor: inventory injection + sops-nix HM + nix-index HM +
`user.ai.home-agents` + `user.task-shim` + the allowUnfree/overlay block.
Reached via `features = ["home"]` in `flake/host-inventory.nix`, assembled by
`homeManagerConfiguration` in `flake/outputs.nix`.

| host | import shape | user role actually imported |
|---|---|---|
| alarm | feature (`home`) + own `hosts/alarm.nix` | `roles.minimal` — direct |
| clanker | feature (`home`) + `hosts/clanker.nix` | `roles.lean` — direct |
| kali | feature (`home`) + `hosts/kali.nix` | `roles.minimal` — direct |
| penguin | feature (`home`) + `hosts/penguin.nix` | `roles.minimal` — direct |

An edit to `hmSharedModulesHome` lands on exactly these 4 — aarch64-linux
(alarm, kali) and x86_64-linux (clanker, penguin). None of them takes
`roles.home`, so user-role edits do NOT reach them through this chain.

## Chain B — `roles.home` via `fleet.hmUserModules` / `fleet.hmUserFeatures`

The embedded user role. `modules/global/home-manager-shared.nix` declares both
options (`hmUserModules` default `[roles.home]`; `hmUserFeatures` default =
`user.hmFeatures`, enum-typed so a typo is an eval error). `roles.home` maps
each feature to its module set; `roles.minimal` is unconditional inside it.

`home-manager-shared` is imported by exactly two global modules:

- `modules/global/nixos.nix` → the `nixos` feature → **11 hosts**
- `modules/global/macos.nix` → the `macos` feature → **1 host**

| host | shape | notes |
|---|---|---|
| aceofspades, aristotle, diogenes, eisen, poseidon, schneeeule, scratch, stark | feature chain (`base nixos dms`), full 7-feature role | default consumers |
| ancientace | chain + user override | `EDITOR` mkForce on top of the role |
| frieren | chain + user overrides | `aria2-user-fallback` off, `hermes-user` on — additive merges |
| fern | chain + **feature fork** | `fleet.hmUserFeatures = mkForce [6/7]` — drops `desktop` (dwlDesktop owns its compositor); also `antigravity-cli` off per-user |
| cassini | chain (`base macos`) | darwin — `desktop`/`niri` layer self-gates on Linux; eval-level trap documented in roles/home.nix |

Feature → module map (`roles/home.nix`): `systemd-policy` `shell` `dev`
`ai` (antigravity-cli + selector-daemon) `browser` (zen + aria2)
`media` (multimedia + kitty) `desktop` (suite + niri, the latter gated by
`dankShell`). Every host above takes `roles.minimal` inside the role.

## Chain C — HM integration without the role

`inputs.home-manager.{nixos,darwin}Modules.default` alone, own user wiring:

| hosts | via | user wiring |
|---|---|---|
| applevalley, ares, deckstation, delphi, guckloch, kellerbench, mtfuji, sledgehammer | `containers` → `global.noDE` | `roles.minimal` + `shell` direct, `profiles.ai` off. delphi adds `mail-agent` import + hermes units; guckloch adds `ai.skills`/`antigravity-cli` + an atuin mkForce |
| demo | `demo` → `global.demo` | `roles.demo` |

An edit to the `inputs.home-manager` flake pin reaches all of chains A–C plus
these — 25 configurations total. `netbook`, `testvm`, `garnixMachine`,
`frieren-canary`, `minyx` take no HM integration at all.

## Risk per host

- **Eval-break risk (highest): cassini** — darwin-only host; the niri/desktop
  boundary already failed evaluation once (documented in `roles/home.nix`).
  Any edit to `desktop`/`media` feature contents must be gated or eval'd on
  aarch64-darwin, not assumed.
- **Fork drift: fern** — its mkForce subset shadows the default list. A NEW
  feature added to `user.hmFeatures` will NOT reach fern until its subset is
  updated — silent partial adoption, not an error. The enum catches typos,
  not omissions.
- **Override conflict: ancientace, frieren** — per-user merges are additive;
  a role-level change to `EDITOR`/aria2/hermes-user fights the host's own
  definitions at module priority. mkForce hosts win; non-force hosts conflict.
- **aarch64 coverage: alarm, kali** — standalone HM on aarch64-linux; a
  chain-A edit adding a package must be checked on both arches.
- **No-role hosts** — Chain C hosts get the integration module only; an edit
  aimed at "all HM users" that lands in `roles.home` misses them by design.

## The precise edit set, for any change

The mechanism already gives per-host control; use it in this order:

1. **One host, one feature.** To change what one host's HM builds, edit that
   host's `fleet.hmUserFeatures` subset (Chain B) or its `modules` list in
   `flake/host-inventory.nix` (Chain A/C). Never `mkForce` a deeper option —
   `home-manager-shared.nix` exists so the fork is an option value.
2. **Gate:** `task checks:host HOST=<h>` for the edited host — it evaluates
   the nested HM eval, which is where option-surface errors land. For chain-A
   hosts the same task evaluates the `homeConfigurations` attr.
3. **A shared edit is a feature-map edit**, not a host edit: adding a module
   inside `features.<f>` in `roles/home.nix` lands on every Chain-B host
   (fern included unless the feature is `desktop`). Verify the set first with
   the generated blast table.
4. **Two-arch verify** for package-carrying edits: `checks:host` on one
   x86_64 + one aarch64 host from the touched chain before pushing.
5. **Rollback** is the generation — `infra:rollback:host:<h>`; the ledger of
   what the role built lives in the HM generation, not in git alone.

## Safe path summary

| edit target | lands on | first verify |
|---|---|---|
| `hmSharedModulesHome` | alarm, clanker, kali, penguin | `checks:host` on alarm + clanker (both arches) |
| `features.<f>` in `roles/home.nix` | 12 embedded hosts (fern excluded for `desktop`) | `checks:host` frieren + cassini (nixos + darwin) |
| `user.hmFeatures` default list | 12 embedded, minus fern's shadowed subset | same |
| `home-manager-shared` (options, sharedModules) | 12 embedded hosts | same |
| `global.noDE` / `global.demo` | 8 containers / 1 demo | `checks:host` on a container host |
| `inputs.home-manager` pin | 25 configurations | eval every kind, one host each |
