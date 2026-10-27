# The netbook's rice port: mako → fnott, and the lighter call sites

Alice's userland (`~/.dotfiles`, `~/mako-suite`) was written for niri, fuzzel, mako
and alacritty. The session is already the fleet's (`profiles.dwlDesktop`, 2026-10-27);
this page is the plan for her half — the `netbook-desktop-phase-2` note owns the
decision and the exit criteria, and the numbers below were read out of fnott 1.8.0's
source and today's package closures, not from memory.

It **landed 2026-10-27** (note `netbook-desktop-phase-2`, `DELIVERED`); the page stays
as the mapping — what fnott can and cannot express, and which call sites had to
move — because the code cannot say why a rule exists. The last section records
where the port went differently from this plan.

## Why the daemon swap and the card port are one deploy

Two processes cannot own `org.freedesktop.Notifications`. And fnott's renderer does
not ignore markup it does not know: `notif_layout()` in `notification.c` breaks a run
only on `<b>`, `<i>`, `<u>` and their closers, so a card still sending
`<span foreground=…>` draws those characters. Half a swap therefore reads as "the HUD
broke", not as "half-migrated".

## Three facts that decide the port (fnott 1.8.0)

### 1. Identification is by title, not by app name

`fnottctl list` prints `id: <summary>` — `ctrl.c` writes `notif_get_summary(notif)`,
which is the **raw summary with HTML entities decoded** (`notification.c`). It is not
the rendered template, so `summary-format` cannot smuggle `%a` into the list. Each
card must carry a unique, stable title; the toggle is then:

```sh
fnottctl list | awk -v t='🔋 makobatt' '$0 ~ t {gsub(":", "", $1); print $1; exit}'
fnottctl dismiss <id>        # was: makoctl dismiss -n <id>
fnottctl dismiss all         # was: makoctl dismiss --all
```

Five of the six cards already do this — `🔋 makobatt…`, `💾 makodf…`, `🎯 makokill…`,
`📡 makonet…`, `📊 makotop…`. Only `makofetch`'s `❄️ ${USER}@$(hostname)` carries no
card name and needs one.

### 2. Markup is `<b> <i> <u>`, and nothing else

`<span foreground=…>` is rasterized as literal text. The cards' per-line colours are
genuinely lost; `<b>` survives. Strip the tags in the port — do not rely on the
renderer to drop them.

### 3. No per-app sections

`fnott.ini` has `[main]`, `[low]`, `[normal]`, `[critical]` — three urgency buckets,
not mako's arbitrary `[app-name=…]`. The six per-card blocks (border colour, 380–500 px
width) collapse to one look, or to three if a card picks its urgency. Per-card
*sticky* behaviour survives: the cards already pass the timeout in the `Notify` call.

## The option mapping (the netbook's own mako config)

| mako | fnott.ini | Note |
| :--- | :--- | :--- |
| `font=JetBrainsMono Nerd Font 11` | `title-font`, `summary-font`, `body-font` | fontconfig syntax, `:size=11`, three keys |
| `background-color=#1e1e2ef2` | `background=1e1e2ef2` | RGBA hex, no `#` |
| `text-color=#cdd6f4` | `title-color`, `summary-color`, `body-color` | three keys |
| `border-color`, `border-size`, `border-radius` | same names | no `#` |
| `progress-color=over #313244` | `progress-color` + `progress-style=background\|bar` | no `over` |
| `icons=1`, `max-icon-size=48` | `max-icon-size=48` | `0` disables icons |
| `default-timeout=5000` | `default-timeout=5` | **seconds**, not milliseconds |
| `anchor=top-right` | `anchor=top-right` | |
| `margin=8` | `edge-margin-vertical`/`-horizontal=8` | one key becomes two |
| `padding=12` | `padding-vertical`/`-horizontal=12` | one key becomes two |
| `width=360`, `height=120` | `min-width`/`max-width=360`, `max-height=120` | fnott wraps at `max-width` |
| `max-visible=4` | — | **no equivalent** |
| `markup=1` | always on, `<b> <i> <u>` only | see fact 2 |
| `[urgency=low\|normal\|high]` | `[low]`, `[normal]`, `[critical]` | three named sections |
| `[app-name=makotop]` ×6 | — | see fact 3 |
| `[app-name=…] default-timeout=0` | the card's own `Notify` timeout | already per-call |

`makoctl reload` has no `fnottctl` counterpart (`dismiss`, `actions`,
`dismiss-with-default-action`, `list`, `pause`, `unpause`, `quit` — and `--version`).
The installer's reload block drops that line rather than inventing one.

## Where the look lives

`fnott.ini` is read from `$XDG_CONFIG_HOME/fnott/fnott.ini` first, then
`/etc/xdg/fnott/fnott.ini`. So the fleet ships the baseline declaratively at
`/etc/xdg/fnott/fnott.ini` and her own file, if she ever writes one, still wins. The
daemon is in the profile's package list, and the host starts it from its
`autostart` entry.

## The call sites

`~/.dotfiles`, invocations only (config files for the retired stack are dead weight):
`fuzzel -d -p … -w N -l N` and `fuzzel -d --password` in `ani-app`, `qr-sync`,
`taildrop`, `yt-app`, `web-app`, `hermes-terminal`, `freebuff-terminal` —
`wmenu` takes `-p` (prompt), `-l` (lines), `-P` (masked) and has **no width flag**,
so `-w` drops; omitting `-l` already means one line per entry, which is fuzzel's
`--minimal-lines`. `alacritty -e …` in the same launchers → `foot -e`. The seven
`Notify` senders (`voice-dictate.sh`, `voice-agent.sh`, `quick-keys.sh`, `qr-sync`,
`taildrop`, `hermes-terminal`, `freebuff-terminal`) need no change unless their bodies
carry `<span>`.

`~/mako-suite`, per card: `makoctl` (toggle + dismiss) in all six, fuzzel menus in
`makokill` (7 hits), `makonet` (5), `makobatt` (4), and `swaylock` in `makobatt` (3).
Each card already defines `APP_NAME=` and passes it in the `Notify` call.

## The measured win

Closure sizes from `cache.nixos.org`, x86_64, measured 2026-10-27:

| Leaves | MiB | Arrives | MiB | Already installed |
| :--- | ---: | :--- | ---: | :--- |
| mako 1.11.0 | 326.2 | fnott 1.8.0 | 112.2 | no |
| fuzzel 1.15.0 | 140.3 | wmenu 0.2.0 | 100.4 | yes |
| alacritty 0.17.0 | 240.0 | foot 1.28.0 | 97.4 | yes |
| swaylock 1.8.6 | 140.7 | waylock 1.6.0 | 77.6 | yes |

Notifier only ≈ **214 MiB**; the whole stack ≈ **735 MiB** off a host that has
4.5 GiB free at 82 % full. (`swaylock` is 140.7 MiB, not the 61 MiB a 2026-10-27 note
recorded — measure before quoting.)

## What landed, and where it differs from the plan above

One deploy (2026-10-27, `infra:apply:host:netbook`, 3m24s, 0 failed units), not the
three phases listed here: only one process can own `org.freedesktop.Notifications`,
so the daemon swap and the card port shipped together and the half-state never
existed on the host.

- **The daemon.** `profiles.dwlDesktop` installs `pkgs.fnott` and ships
  `/etc/xdg/fnott/fnott.ini`; the host's `autostart` starts `fnott`. `mako`,
  `fuzzel`, `alacritty` and `swaylock` left `environment.systemPackages` — the
  operator asked for fuzzel to go entirely rather than menu by menu, so "step 4,
  optional" is not a follow-up.
- **The cards** (`~/mako-suite`, commit `15e14a2`): dismiss and liveness on the
  summary, `makofetch`'s title gained its name, menus are `wmenu -p/-l` (`-P` for the
  two password prompts), makobatt locks with `waylock -fork-on-lock`, and the
  per-app styling blocks went with the daemon that read them.
- **The helpers** (`~/.dotfiles`, commit `feb8d6e`): menus and launchers as above;
  the installer stopped installing configs for the retired stack and dropped a
  reload it could not perform.
- **Markup.** The plan said strip the tags by hand; the port put a three-line
  `strip_span` at the notification boundary instead, because the colours are lost
  either way and the tag lists sit inside awk `printf` strings. The first pass
  filtered `$body` only, and makokill sends `body` and `footer` as one argument —
  the operator saw that as literal XML on Mod+Alt+Backspace. Every `Notify` body is
  now filtered at its own call site, and a grim capture of the card shows its table
  and italic footer with no literal markup.
- **Verified.** fnott owns the bus name, a synthetic `Notify` reads back through
  `fnottctl list`, `📊 makotop` appears and dismisses on the same chord, and
  `checks:host HOST=netbook` is green.

## What was declined, with the numbers

Moved here from `.agents/deploy/hosts/netbook.md` when that runbook hit its budget.
Everything declined on this host was declined with a number behind it, measured
2026-10-27 as a per-package closure (`nix path-info -Sh --store
https://cache.nixos.org`, fleet nixpkgs):

| Component | Closure |
| --- | --- |
| niri — the compositor this host ran | 695 MiB |
| dwl — the compositor it runs now | 345 MiB |
| waybar | **1001 MiB** |
| gnome-keyring | **378 MiB** |
| greetd / tuigreet | 60 / 51 MiB |
| foot / wmenu / fnott / swaybg / swayidle / waylock | 97 / 100 / 112 / 128 / 43 / 78 MiB |
| mako — the notifier until 2026-10-27 | 326 MiB |
| firefox (removed 2026-10-27) | 1.46 GiB |

- **Bar: declined.** waybar is not a bar in closure terms — it brings zenity
  (902 MiB) and `sdl2-compat`/sdl3 (~955 MiB) with it, so a status line would have
  cost more than the rest of the session combined, and more than the compositor it
  replaced. If one is ever wanted, the thing to beat is dwl's 345 MiB, not zero.
- **Browser: settled 2026-10-27.** `firefox` cost 1.46 GiB of closure and measured
  **~1.0 GiB RSS** on this 1818 MiB host, so it is gone and the browsers come from
  the NAS AppImage library through the launcher entries instead (zero closure).
- **Secret service: declined.** Nothing on this host implements the freedesktop
  Secret API — the browsers keep their own credential stores — so the keyring would
  have been 378 MiB of idle daemon. Scratch
  has run without one since its dwl conversion.
- **Display manager: declined.** `greetd` + `tuigreet` were 111 MiB to autologin a
  single user, and SDDM is a Qt stack. tty1 autologins through `getty` instead,
  which still gives the session a real logind/seat through PAM, and
  `environment.loginShellInit` execs `/etc/xdg/dwl-session` from the login shell.
  NixOS's `/etc/profile` reads **`/etc/profile.local` and the `loginShellInit`
  slot, not `/etc/profile.d`** — checked against the generated file, because the
  hook that is not read fails silently.

