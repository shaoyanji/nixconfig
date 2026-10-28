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

### 2026-10-28 — resolver holds no swap, keeps its 7 days; Steam cache warm; Pi-hole published
- **Swap was glibc arenas, not query history.** 13 threads → 12 anonymous heaps of 64/128 MiB; `VmSize` 2.1 GB against `VmRSS` 132 MB and `VmSwap` 934 MB. `MALLOC_ARENA_MAX=2` + `MemoryHigh=1.2G` (`hosts/frieren/dns.nix`): VmSize 1,229 MB, swap **934 → 0 MB**, box swap 4.47 → 3.34 GB. `DBimport`/`maxDBdays` are ignored on 6.7.1 (measured), so the imported history is not a knob.
- **Retention back to 7 days.** nixpkgs' deleter ran `date('now','-7 day')` nightly and carried `ConditionFileNotEmpty` in `[Service]` (*Unknown key, ignoring*); replaced by an hourly rolling window + `VACUUM` above 4096 free pages. Oldest row 7.04 days, DB 603 → 576 MB.
- **`pihole.frieren.lan` publishes the admin UI** (was SSH-tunnel only) via `hosts/frieren/reverse-proxy.nix` plus a portal card. FTL 6 serves it at `/`, `/admin/` is a 404, and it stays enabled because `services.pihole-ftl.lists` loads blocklists through its API (module assertion). No password either way.
- **Steam cache warm.** Dota 2 linux depots, 33.42 GiB in 35:27, cache 40 → 45 GB, DNS pin scoped to the prefill namespace (`dnsOverride` still false). Windows added 2026-10-29: **+7.7 GB** (45 → 53 GB) in ~46 min at ~3 MB/s, then the same selection walked all 33.72 GiB in **8:29 at 569 Mbit/s** off this cache — the `%` counter serves the new chunks first and read 18 % while doing all of the real downloading, so the earlier "0.3 GiB" delta from the manifest total was never the transfer size. `prefill.maxRuntime` 3h → 6h, because one cold 33 GiB set is 2–3.4 h on this line.
- **The prefill recipe is code now.** `modules/services/steam-cache.nix` pins `lancache.steamcontent.com` with five `BindReadOnlyPaths` (`nsswitch.conf`, `host.conf`, `hosts`, `resolv.conf`, empty `/var/run/nscd`) built from store paths, and `prefill.enable` only arms the timer — the unit exists whenever the cache does, so a fill is `systemctl start steam-prefill`. `/var/lib/steam-prefill/pf-dota.sh` is deleted; the unit run reported `Up To Date 1` in 5.9 s and `getaddrinfo` inside its namespace returns `192.168.3.25` alone while the host still returns Valve's public set. The `02:00` window is armed (next elapse `02:01:27`), and a warm-cache run moves 77 KB in / 14 KB out.
- Evidence: `pihole.frieren.lan/` 200 `<title>Pi-hole frieren</title>`, card in `/data/services.json`, `checks:host HOST=frieren` rc=0, all three switches exit 0 with the resolver probe green, gatus dns + steam cache ok.

### 2026-10-27 — the preexec hook printed itself in every new terminal
- **The defect.** atuin's bash integration sources bash-preexec, which *appends* its preexec hook to PS0, and bash
prints whatever PS0 holds outside that `${ …; }` form at every prompt with `$_` expanded — so a PS0 inherited from
a parent shell printed the whole zoxide init at the first prompt of a fresh foot window. `modules/shell/atuin.nix`
drops an inherited PS0 and its export attribute before bash-preexec installs its own.
- **Evidence.** With a poisoned PS0 exported: the deployed `.bashrc` prints the blob, the new one prints nothing,
PS0 reads back canonical, and a child shell's env carries no PS0. `checks:host` green for delphi, scratch `MODE=eval`.

### 2026-10-27 — scratch is current again, and `activate-host` was broken without `TOP=`
- **The defect.** `activate-host.sh` tested `$top` against each substituter ~30 lines before resolving it, so
under `set -u` every caller that does not pass `TOP=` died at that loop — `infra:apply:host:*` and the fleet
loop, the two paths that exist because they have no gate of their own to resolve it. Only `infra:deploy:host:*`
worked. The cache block now sits after the toplevel, which also restores the preserved-host promise of no eval
and no cache query before the status read, and `--check` runs for the first time.
- **Scratch, five days behind** (generation 15, 2026-10-22), needed three things: its `trusted-public-keys`
predated the shaoyanji cachix key, harmonia had no toplevel, and `nix copy --from` one cache cannot complete when
a path (`nix-direnv`) lives only on `cache.nixos.org`. `nix-store --realise` of the toplevel **on frieren** (no
compile) plus the normal deploy landed it, and the new generation carries the key.
- **Evidence.** `checks:host HOST=scratch` 5.06 s / 697 MiB rc=0; deployed `6pz4lsqi` == current; 0 failed units;
53 AppImage entries with `xdg-mime query default text/html` → `appimage-helium.desktop`.
- **Docs debloat, same day.** Three runbooks were past the 400-line budget with nothing enumerating them
(`docs/dns-failover.md` 618 → 399, `delphi.md` 520 → 267, `netbook.md` 449 → 399, detail to
`docs/delphi-install.md` / `docs/netbook-rice-port.md`); `docs-budget.sh` derives the runbook class now.

### 2026-10-27 — the netbook's rice runs fnott: daemon swap and userland in one deploy
- **Why one deploy.** Two processes cannot own `org.freedesktop.Notifications`, so shipping the swap before the
  cards were ported would have looked like a broken HUD: they identified themselves through `makoctl list`'s app
  name, and fnott renders only `<b> <i> <u>`. `profiles.dwlDesktop` installs `pkgs.fnott` and ships
  `/etc/xdg/fnott/fnott.ini` (fnott has no per-app sections, so the cards' border colours went with mako);
  `hosts/netbook/configuration.nix` starts `fnott` and its mako/fuzzel/alacritty/swaylock block is gone.
- **Her repos, edited in place (authorised 2026-10-27).** `~/mako-suite` `15e14a2`: dismiss and card liveness
  moved from mako's app name to a unique summary (`fnottctl list` prints `id: <summary>`; `makofetch`'s title
  gained its name), menus are `wmenu -p/-l/-P`, makobatt locks with `waylock -fork-on-lock`, and bodies pass
  through a `strip_span` at the notification boundary. `~/.dotfiles` `feb8d6e`: the helpers launch
  `wmenu`/`foot`, the installer stopped installing configs for the retired stack, and the niri config's spawn
  lines moved with them.
- **The bug a static read missed.** The first pass filtered `$body`, but makokill sends `body` and `footer` as
  one argument — the operator saw literal `<span foreground=…>` XML on Mod+Alt+Backspace. Every `Notify` body
  now filters at its own call site, and a grim capture of the card (the region, not the desktop) shows the
  table and italic footer with no literal markup: the check is a rendering, not a grep of the source.
- **Evidence.** `infra:apply:host:netbook` 3m24s, current == deployed, 0 failed units. Live: fnott owns the bus
  name (`busctl --user status` → PID), a synthetic `Notify` reads back through `fnottctl list`, `📊 makotop`
  appears and dismisses on the same chord, the four retired packages no longer resolve on the session PATH,
  and `checks:host HOST=netbook` is green. Scratch shares the profile: closure warmed from `d77499af` by CI
  (6m44s), deploy still pending.

### 2026-10-27 — the netbook's session ran stock dwl; sessions are `programs.dwl` now
- **The defect.** `profiles.dwlDesktop` handed the session to a hand-rolled `writeShellApplication`
  that listed `pkgs.dwl` in `runtimeInputs` while the *keymap* build went to `systemPackages`. A wrapper's
  PATH wins inside the session, so the deployed compositor was upstream's `config.h`: no bind in this repo
  existed, on either host, and nothing looked wrong — stock dwl renders, spawns and tiles. Evidence:
  `/proc/<dwl>/exe` was `3b7ph6qz…-dwl-0.9` (= plain `pkgs.dwl`), referenced only by `dwl-session`,
  while the spliced `8rsfl73qq…` was referenced only by `system-path` — and evaluating
  `pkgs.dwl.override {configH = <repo splice>}` from `modules/config/dwl/config.h` +
  `hosts/netbook/dwl-keybinds.h` yields exactly `8rsfl73qq…`. So the host's own `Mod+D` did nothing.
- **The fix is the declarative route.** The session is nixpkgs' `programs.dwl`: the profile passes
  `package` (the spliced keymap) and `extraSessionCommands` (exports, wallpaper, idle/lock, the host's
  autostart lines), and the module's `/etc/xdg/dwl-session` execs `lib.getExe cfg.package` — an absolute
  store path no PATH can shadow. `modules/config/dwl/dwl-session.sh` is gone; one `dwl-0.9` remains in the
  closure.
- **A second defect, found by putting the first one live.** The clients start from a hook that runs
  *before* dwl, so the wrapper waits for the socket — and a killed session leaves its socket **file**
  behind. Restarting `getty@tty1` made it treat that file as proof: `swaybg`, `swayidle` and `mako` all
  exited, while `makobatt -s` and `taildrop --daemon` survived. The wait now runs `swayidle` as a canary and
  proceeds only if it is still up 0.3 s later.
- Deployed as generation 71 (`0fyzq71w…`): current == deployed, loader default on it, 0 failed units,
  4/1817 MiB RAM used, `/` 44 %. Session restarted and read back: compositor = the spliced path with the
  host keymap in the binary, all five clients up, `WAYLAND_DISPLAY=wayland-0`, and a `Notify` through
  their cards' call shape read back from `makoctl list` as `App name: buffy-check`.
- **Scratch** shares this profile and was offline; its closure is warmed by CI (`d77499af`, 6m44s) and its
  deploy is still pending.

### 2026-10-27 — netbook and scratch: one dwl session, and the desktop's bloat measured out
- `5f07866a` lifted the dwl session into `profiles.dwlDesktop`, so scratch stopped keeping a host-local copy
  and netbook stopped running niri. Both now get the same keymap, launcher, wallpaper and lock; the launcher is
  `fleet-menu` (XDG entries *and* `$PATH` in one menu — the `j4-dmenu-desktop` + `wmenu-run` pair each listed
  half), and its first version dropped any entry carrying a `[Desktop Action …]` group, which is most real apps.
- `ea152738` removed what measuring said was not needed: waybar (closure **1001 MiB** against dwl's 345 MiB —
  it drags zenity at 902 MiB), gnome-keyring (**378 MiB**, no consumer: firefox keeps its own NSS store and
  nautilus has no gvfs here), greetd + tuigreet (**111 MiB** to autologin one user). SDDM was already off on
  both and is now vetoed in the profile, so no adopter can inherit it.
- The session starts without a display manager: `getty` autologins tty1 (still a real logind session, seat and
  runtime dir, through PAM) and `environment.loginShellInit` execs dwl. It has to be that option — NixOS's
  `/etc/profile` reads `/etc/profile.local` and the `loginShellInit` slot and never `/etc/profile.d`, so the
  obvious version of this fails silently. Verified by reading both hosts' generated `/etc/profile` and running
  its guard against stubbed `id`/`tty`.
- Evidence: `checks:host` green for both (1846 and 1541 assertions), `checks:quick` green, `.#checks.<sys>.knobs`
  14/14 with `dwl-desktop` registered. **Not deployed: both hosts are offline** (netbook 2d, scratch 19h). CI is
  warming both closures. The one thing eval cannot prove is the autologin itself; recovery if dwl never starts
  is ssh, which never depended on a greeter.

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
