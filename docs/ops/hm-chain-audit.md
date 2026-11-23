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

Each host's role/module list is `hmModules` in its inventory entry, resolved
by `global.hm-inventory-role` (in `hmSharedModulesHome`) through the
`fleetHost`/`hostInventory` extraSpecialArgs — an edit lands on one host's
entry. `hosts/<name>.nix` keeps host settings and any non-registry (`inputs.*`)
imports — penguin's kickstart-nixvim is the example.

| host | `hmModules` |
|---|---|
| alarm | `roles.minimal` |
| clanker | `roles.lean` |
| kali | `shell.starship` + `roles.minimal` |
| penguin | `shell` `env` `lf` `sops` `scripts` |

An edit to `hmSharedModulesHome` lands on exactly these 4 — aarch64-linux
(alarm, kali) and x86_64-linux (clanker, penguin). None of them takes
`roles.home`, so user-role edits do NOT reach them through this chain.

## Chain B — `roles.home` via `fleet.hmUserModules` / `fleet.hmUserFeatures`

The embedded user role. `modules/global/home-manager-shared.nix` declares both
options (`hmUserModules` default `[roles.home]`; `hmUserFeatures` =
`mkDefault` of the host's own `hmFeatures` in `flake/host-inventory.nix`,
enum-typed so a typo is an eval error; `user.hmFeatures` is the enum and the
fallback for a host with no field). `roles.home` maps each feature to its
module set; `roles.minimal` is unconditional inside it. An edit to one host's
`hmFeatures` list lands on that host only — the per-host split this audit
recommended is landed.

`home-manager-shared` is imported by exactly two global modules:

- `modules/global/nixos.nix` → the `nixos` feature → **11 hosts**
- `modules/global/macos.nix` → the `macos` feature → **1 host**

| host | shape | notes |
|---|---|---|
| aceofspades, aristotle, diogenes, eisen, poseidon, schneeeule, scratch, stark | feature chain (`base nixos dms`), `hmFeatures` = full 7 | own list |
| ancientace | chain + user override | `EDITOR` mkForce on top of the role |
| frieren | chain + user overrides | `aria2-user-fallback` off, `hermes-user` on — additive merges |
| fern | chain + **feature subset** | `hmFeatures` = 6/7 in inventory — drops `desktop` (dwlDesktop owns its compositor); also `antigravity-cli` off per-user |
| cassini | chain (`base macos`) | darwin — `desktop`/`niri` layer self-gates on Linux; eval-level trap documented in roles/home.nix |

Feature → module map (`roles/home.nix`): `systemd-policy` `shell` `dev`
`ai` (antigravity-cli + selector-daemon) `browser` (zen + aria2)
`media` (multimedia + kitty) `desktop` (suite + niri, the latter gated by
`dankShell`). Every host above takes `roles.minimal` inside the role.

## Chain C — HM integration without the role

`inputs.home-manager.{nixos,darwin}Modules.default` alone, own user wiring —
now `hmModules` in each host's inventory entry, resolved per host inside
`global.noDE`/`global.demo` (the same inventory-data split as Chain B):

| hosts | via | `hmModules` |
|---|---|---|
| applevalley, ares, deckstation, delphi, guckloch, kellerbench, mtfuji, sledgehammer | `containers` → `global.noDE` | `roles.minimal` + `shell`, `profiles.ai` off. delphi adds `mail-agent` import + hermes units; guckloch adds `ai.skills`/`antigravity-cli` + an atuin mkForce — additive imports merge on top |
| demo | `demo` → `global.demo` | `roles.demo` |

An edit to the `inputs.home-manager` flake pin reaches all of chains A–C plus
these — 25 configurations total. `netbook`, `testvm`, `garnixMachine`,
`frieren-canary`, `minyx` take no HM integration at all.

## Risk per host

- **Eval-break risk (highest): cassini** — darwin-only host; the niri/desktop
  boundary already failed evaluation once (documented in `roles/home.nix`).
  Any edit to `desktop`/`media` feature contents must be gated or eval'd on
  aarch64-darwin, not assumed.
- **Subset drift: fern** — its `hmFeatures` is an explicit 6-item list. A NEW
  feature added to `user.hmFeatures` will NOT reach fern until its list is
  updated — silent partial adoption, not an error. The enum catches typos,
  not omissions. Same rule applies to any host that later takes an explicit
  subset.
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
   host's `hmFeatures` list in `flake/host-inventory.nix` (Chain B) or its
   `modules` list (Chain A/C). An explicit `fleet.hmUserFeatures` definition
   in a host config still wins over the inventory `mkDefault` — keep it for
   exceptions that must not live in shared data.
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
| `features.<f>` in `roles/home.nix` | every host whose `hmFeatures` names `<f>` (12 for most; fern excluded for `desktop`) | `checks:host` frieren + cassini (nixos + darwin) |
| `user.hmFeatures` enum | all 12 — removing a name breaks every list | same |
| one host's `hmFeatures` in `flake/host-inventory.nix` | that host only | `checks:host` on that host |
| `home-manager-shared` (options, sharedModules) | 12 embedded hosts | same |
| `global.noDE` / `global.demo` | 8 containers / 1 demo | `checks:host` on a container host |
| `inputs.home-manager` pin | 25 configurations | eval every kind, one host each |
