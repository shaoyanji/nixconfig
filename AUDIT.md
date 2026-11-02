# AUDIT — current state and change ledger

> Newest first. One entry per landed change: what, where, evidence. Entries older
> than the current day are archived in
> [`docs/history/audit-2026-10.md`](docs/history/audit-2026-10.md); design rationale
> lives in [`AGENTS.nix`](AGENTS.nix) (`task ops:notes`).
> Budget: 150 lines (`.agents/SCHEMA.md` §2).

## Current state (2026-10-27)

Rows carrying a command were re-measured 2026-10-27 with it. The live-system rows
(observation, knowledge, backups, DNS, tailnet) were last confirmed 2026-10-20.

| Area | State | Evidence |
| :--- | :--- | :--- |
| Fleet registry | 35 devices: 20 active (13 NixOS, 7 external), 15 preserved, 0 wip | `nix eval .#inventory.derived`, `task dev:inventory:counts` |
| Host gates | per-host eval (assertions) and per-host VM boot to stage-2, one process each | `.#hostChecks.x86_64-linux.<host>`, `.#hostBootChecks.aarch64-linux.delphi` |
| Known red gates | `cassini` (xdg.desktopEntries on darwin), dormant. `minyx` passes its gate on its own arch (`ARCH` now resolves per host, so no flag); its hardware is the shortfall, not its config: continuous under-voltage in `dmesg` | `task checks:host HOST=minyx` |
| Formatting | alejandra, 231 tracked `.nix` files clean | `task checks:nix:format` |
| Lint | deadnix hard gate, statix advisory | `task checks:nix:lint` |
| Secrets | 7 SOPS files, zero drift (37 recipients per rule) | `task checks:sops:drift` |
| Skills | 50, compiled + schema-gated | `nix eval .#agentSkills.count`, `task ops:skills:check` |
| Observation | frieren sentinel: 15-min ledger, health endpoint, gatus body assertion | `task ops:health`, `/var/lib/fleet-sentinel/` |
| Knowledge | qmd (`.md` + `.nix`) + `.#knowledgeGraph` (structure) + sentinel ledger (episodic) | `task ops:kg`, `task ops:ledger` |
| Backups | local + BurgerNAS offsite; restore drill weekly; password in sops | `restic-drill.timer`, `task checks:restic:drill` |
| DNS | frieren pihole+unbound owns the zone, minyx blocky+keepalived is the secondary behind VIP `192.168.3.50` (priority 200/1, unicast peers); delphi crab-hole answers public DNS only, same address | `task checks:dns:failover`, `docs/dns-failover.md` |
| Tailnet routes | `10.99.0.53/32` approved on both via `autoApprovers`; policy mirrored in the repo | `ops:tailnet:routes`, `ops:tailnet:policy` (both rc=0) |
| Tailnet DNS | global `10.99.0.53, 100.97.61.65`, split `frieren.lan → frieren`, Override on | `ops:tailnet:dns` (rc=0) |

## Ledger
### 2026-11-02 — paperless, vaultwarden and anki move off the NAS; the NAS becomes the shelter
- **The shape of an offload is now a module, not a memory.** `services.offloadBridge`
  (`modules/services/offload-bridge.nix`) declares what a moved service still owes the NAS: a nightly
  mirror of every tree to `/srv/backup/offload` with each SQLite database replaced by a `sqlite3 .backup`
  snapshot (a WAL-mode `db.sqlite3` rsync'd beside a stale `-wal` restores into a service that starts and
  answers wrong), an ingest pull for the drop folder the service no longer hosts, and the stop/verify facts
  a cutover needs. `docs/service-offload.md` is the ladder and the procedure.
- **Measured before moving.** paperless ~520 MiB RSS across four units plus tika and gotenberg, 722 MB of
  SQLite + media and **no postgres** (the DB is SQLite) — so the move is a file copy plus one consistent
  dump. vaultwarden 36 MiB / 4.2 MB, `DOMAIN` unchanged so enrolled passkeys survive. anki-sync-server held
  **430 MiB resident for a 4 KB empty store**: the best ratio in the fleet. Its placeholder account was
  plaintext `bob`/`password` in the Nix store; it now reads a 32-character password from sops via
  `passwordFile` (a systemd credential, so no value reaches the store). Proved on the live server:
  `/sync/hostKey` returns an hkey (200) for the sops password and 403 for `password`.
- **delphi is the only host that built.** paperless needed 20 derivations no substituter carries on aarch64
  plus 559 MiB fetched: **~41 min of wall clock on 2 OCPU**, because spacy pulls thinc/blis and those compile
  C++. `wandb` also failed its own suite on this arch and is built with checks off via paperless'
  `extraPythonPackageOverrides` — an overlay that redefines `python3` recurses forever instead. The target
  uses the shared `modules/services/paperless-fork.nix` (moved out of `hosts/frieren/`), because upstream's
  module re-applies a tesseract narrowing on every definition and that would have compiled tesseract too.
  Nothing was compiled on frieren; its config evaluates to a toplevel drvPath (81 s / 4.8 GiB) and is
  unapplied by design.
- **The names stayed.** `docs.frieren.lan`, `vault.frieren.lan` and `anki.frieren.lan` are still frieren's
  vhosts, now proxying delphi's tailnet address directly. Frieren was deployed (2026-11-02) and the
  transitional `offload-tunnel` on delphi is deleted, so the move no longer depends on a live ssh session.
- **Evidence:** `checks:host HOST=delphi` 1947 assertions rc=0; state migrated by
  `scripts/task/offload-migrate.sh` (flock, manifest, `integrity_check`, row-count match, health URL), run
  twice to show the second run is a no-op; the shelter copy verified under `/srv/backup/offload`.

### 2026-11-02 — Ryoku leaves the pilot: a desktop tier ladder
- **Three regimes, one cutoff each.** Ryoku is the high-end tier — **poseidon, eisen, fern**, with fern the
  floor; Dux (`globalModulesNixos`, DMS + greetd) stays the medium tier — aristotle, stark; `profiles.dwlDesktop`
  stays the low end — scratch, netbook, with scratch the ceiling. The ladder is recorded in
  `inventory.toml` (`desktop_environment` + `module_chain`), which is the only place it is written down.
- **The chain swap is the whole change.** `globalModulesRyoku` carries `inputs.ryoku` and no dms/dank-greeter,
  and both hosts import `ryoku-desktop.nix` in place of `base-desktop-environment.nix`. Not alongside it:
  that profile `mkForce`s `xdg.portal.config.niri` to the GTK backend, so keeping both would silently take
  portals away from the shell that owns them, on top of two shells in one session.
- **`sddm.enable = false` was the trap.** Ryoku turns SDDM on with `mkDefault`, so an explicit `false` (left
  over from the DMS-greeter era, where greetd was the DM) wins and the host boots to no display manager at
  all. Both blocks are gone; the module owns the greeter and its theme now.
- **Ryoku pins its session at priority 900** (`ryoku-niri`). poseidon keeps its old flow — autologin into
  niri; eisen keeps its console behaviour with `lib.mkForce "steam"`, because a plain definition loses.
- **`deck-session-switch` restarted greetd only**, so switching back to Gamescope would have become a no-op
  on an SDDM host. It now restarts whichever of greetd/sddm is active (stark keeps greetd).
- **Evidence:** module system + assertions green on every touched host — `checks:host MODE=eval HOST=eisen`
  2019 assertions rc=0 (152 s / 2643 MiB), `poseidon` 2014 rc=0 (307 s / 2668 MiB), `stark` 2002 rc=0 (the
  shared steam profile), `fern` 1979 rc=0 (67 s); `inventory-schema`, `inventory-hosts`, `inventory-modules` build
  clean. Behaviour read back by leaf eval: eisen `{ryoku, sddm, theme="ryoku", session="steam", autologin}`,
  poseidon identical with `session="ryoku-niri"`, fern `session="ryoku-niri", autologin=false`. Build mode
  was not used: on frieren under load it aborted at io pressure 60.9 % after 540 s, and MODE=eval is the
  same evaluation without substituting a closure.
- **Not done:** no host was switched — these are configs; `infra:deploy:host:<host>` is the operator's call.

### 2026-11-01 — the canary is a runbook sandbox, not a second frieren
- **Stripped to what a runbook needs.** `hosts/microvms/frieren-canary.nix` lost the SubZeroClaw
  derivation, its activation-time config seeding and `canary-dummy-api`. What remains is `base.nix`
  plus a login, a tool set and a volume for `/var`; the evaluated unit set is base plumbing + `sshd`
  (`nix eval …config.systemd.services`, 1.64 s / 242 MiB — no `canary-dummy-api`).
- **The route went with the API.** frieren's `/canary/` location, the `canary.frieren.lan` vhost and
  the `/eisen/` proxies on frieren and eisen were EXP-102 dogfooding; `curl 127.0.0.1/canary/` had
  been answering `504` whenever the guest was down, which is its normal state. `vm:canary:agent`
  went with the harness it drove.
- **It cannot be left running.** `vm:canary:run` still boots a transient unit, now with
  `RuntimeMaxSec` (`LIFETIME`, default `2h`) and the cap printed, so an abandoned sandbox stops
  instead of holding 2 GiB of an 8 GiB NAS. `vm:canary:test` asserts the sandbox (hostname, declared
  address, tool set, writable `/var`) and then that no hypervisor or tap survives.
- Evidence: the eval above; `task checks:host HOST=frieren` 19.1 s rc=0, `HOST=eisen` 13.6 s rc=0,
  `HOST=frieren-canary MODE=eval` 1484 assertions rc=0; `task checks:tasks` 497 tasks, parity exact.
  Not run: `task vm:canary:test` — it boots an x86_64 guest, so it belongs on frieren, and it builds
  the new closure there.

### 2026-11-01 — Ryoku landed on fern; dock ethernet declarative; zsh baseline; CPU off the powersave floor
- **Ryoku is live.** `xb9qmd8c…` is `/run/current-system` on fern (the 2026-10-31 entry recorded the port as
  undeployed). Presentation-stage `switch-to-configuration` reported 101 from post-restart units only: the
  `activate-fern` unit, `pipewire` (core-dump in `mod.x11-bell` when X went away at greetd→SDDM) and
  `tailscale-systray`. The switch itself completed.
- **Dock ethernet is declarative and works without `ip`.** `dock-ethernet` came up at `192.168.3.249/24`,
  pinned to `enp4s0f3u1u1i5`, metric 100, proved reachable while Wi-Fi was down. The live generation predates
  `usbEthernetGateway`, so it installs no default route: `ip route get 1.1.1.1` answered "Network is
  unreachable" with the dock up and `wlo1` disconnected.
- **NM does not retry a failed Wi-Fi activation after its own restart.** `wlo1` sat `disconnected` with
  `Activation: failed for connection 'Obi LAN Kenobi'` and exhausted retries; `nmcli connection up` restored
  `.23` and the metric-600 default in seconds. The same post-start path runs `nmcli connection up
  dock-ethernet` for a NIC that is absent at boot — the `No suitable device found … lo` line in the journal.
- **zsh had no configuration at all.** `~/.zshrc` was a 5-line `zsh-newuser-install` stub on a host whose login
  shell is zsh, because `modules/shell/zsh.nix` was commented out of the shell baseline and atuin's zsh
  integration needs `programs.zsh`. Now enabled with 13 aliases and `enableZshIntegration`; `.zshrc` moves
  aside as `.hm-backup`.
- **The APU was pinned at its floor.** `power-profiles-daemon` left `acpi-cpufreq` on `powersave` (1396 MHz of
  2600) on AC with `balanced` selected — `auto-cpufreq` is `mkForce false` on this chain. Measured, 3M-iteration
  loop: **powersave 0.891 s · schedutil 0.476 s · performance 0.469 s**. `cpuFreqGovernor = "schedutil"` with
  `cpufreq.after = [power-profiles-daemon.service]` (ppd does not re-apply on restart — verified).
- **RAM:** the Ryoku shell is `quickshell` at **1512 MiB**, 1677 MiB for the whole desktop set, of 3.4 GiB used.
- **Deployed: fern is on `14cvlhr8…`** (system and HM), switch exit 0, `systemctl --failed` 0. Live proof:
  governor `schedutil` at 2591 MHz with the same 3M loop at **0.469 s**; two defaults, dock `.1` metric 100
  over Wi-Fi's 600; `~/.zshrc` a store symlink carrying atuin and starship; manual `l`/`ls` resolve to eza.
- **Two deploy-time defects, both fixed in the same generation.** The first switch left **HM failed**: `btop.conf`
  and `kando/menus.json` are rewritten at runtime, so their second `.hm-backup` collided with the first (moved
  aside, re-activation green). And `environment.etc."ryoku/phone.json".text` is `types.lines`, so our definition
  **concatenated** with the one phone.nix always writes (`enabled = cfg.enable`) into a two-object file that would
  not parse — now `mkForce`, and `/etc/ryoku/phone.json` parses as one object.
- **Ryoku phone integration, on trial.** `programs.ryoku.phone.enable` cannot evaluate at all: it sets
  `services.udev.packages = [ ryokuNixpkgs.android-udev-rules ]`, `ryokuNixpkgs` is Ryoku's own pin, and that pin
  removed the package ("superseded by built-in systemd uaccess rules"). Wired the same four things directly —
  KDE Connect (ports 1714-1764 open), Avahi, `scrcpy`/`android-tools`/`qt6.qttools` — so the QML's `phone.json`
  is the only state it needs. `phone.webcam.enable` (v4l2loopback) left off: it collides with the dock's
  `boot.extraModprobeConfig`.
- **Gate:** `nix build .#hostChecks.x86_64-linux.fern` rc=0, **1979 assertions** each time (1 m 55 s; cached for
the `mkForce` rebuild).

## Open debt (`task ops:notes`)

1. `cassini`'s darwin assertion (`xdg.desktopEntries`) — dormant, reproducible
   with `MODE=eval`; `minyx`'s kernel conflict is gone (the board evaluates,
   passes its gate and is active since 2026-10-27).
2. Tailnet DNS lists `10.99.0.53`, which eisen/fern/aristotle cannot route
   (`--accept-routes=false` is deliberate), so their failover is nominal; list both
   resolver node addresses instead (`ops:tailnet:dns` reports the set).
3. MQTT broker has no publisher/subscriber (HC-5); 7 of 11 `extraComponents`
   entries are dormant Python dependencies, not enabled components.
4. Sentinel is frieren-local; fleet push is P1 in `ARCHITECTURE.md`.
5. `compile-llm-specs.py` still generates the offline fleet-matrix table (not the
   home card; `~/AGENTS.md` is now `.#homeAgents.<host>`).
