#!/usr/bin/env bash
# The dwl session. Config, exported by modules/profiles/dwl-desktop.nix:
# DWL_WALLPAPER (a colour, an absolute image path, or empty).
set -euo pipefail

# fleet-menu opens Terminal=true entries with this, so the session is what names it.
export TERMINAL="${TERMINAL:-foot}"

# greetd starts a session as a TTY, which is what a greeter is rather than what a
# compositor is: clients branching on XDG_SESSION_TYPE (portals, GTK, screencast)
# take the tty path instead. niri exports these for itself; dwl does not.
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=dwl
export XDG_CURRENT_DESKTOP=dwl

# dwl creates the Wayland socket itself, and swaybg exits immediately if it
# connects before that happens, so it waits in the background while the
# compositor takes the terminal in the foreground.
(
  for _ in $(seq 1 200); do
    for sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/wayland-*; do
      if [ -S "$sock" ]; then
        case "${DWL_WALLPAPER:-}" in
          "") ;;
          /*) swaybg -m fill -i "$DWL_WALLPAPER" & ;;
          *) swaybg -c "$DWL_WALLPAPER" & ;;
        esac
        # dwl has no idle protocol of its own, so swayidle locks on inactivity and
        # before suspend rather than turning the display off.
        swayidle -w timeout 600 'waylock' before-sleep 'waylock' &
        exit 0
      fi
    done
    sleep 0.1
  done
) &

exec dwl "$@"
