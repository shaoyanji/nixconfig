#!/usr/bin/env bash
# fleet-menu — one launcher over XDG desktop entries AND $PATH binaries.
#
# Neither half alone is a usable menu: j4-dmenu-desktop lists only .desktop
# entries, which on scratch meant nothing but the AppImage launchers, and
# wmenu-run lists only $PATH. A dmenu-compatible program returns just the selected
# *line*, so the line has to stay human-readable and the command has to live
# beside it — entries go into a side map (`Name<TAB>Exec<TAB>terminal`), and a
# selection that is not in the map is a binary name and is executed as one.
#
# Vars: DMENU= (program), MENU_FONT=, TERMINAL= (for Terminal=true entries),
# TTL_MINUTES= (cache). Menu input comes from the dwl session's keybind.
set -euo pipefail

DMENU=${DMENU:-wmenu}
MENU_FONT=${MENU_FONT:-JetBrainsMono Nerd Font 11}
TERMINAL=${TERMINAL:-foot}
TTL_MINUTES=${TTL_MINUTES:-5}

CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/fleet-menu
MENU_FILE=$CACHE_DIR/menu
MAP_FILE=$CACHE_DIR/map

data_dirs() {
  printf '%s\n' \
    "${XDG_DATA_HOME:-$HOME/.local/share}" \
    /run/current-system/sw/share \
    "/etc/profiles/per-user/${USER}/share"
  printf '%s\n' "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' '\n'
}

# One awk pass over every .desktop file, flushed on each section boundary so a
# file with several groups cannot emit a stale name. `%f`/`%U`-style field codes
# are dropped: a launcher with no file arguments cannot honour them.
#
# EVERY group switch flushes, including the one that closes `[Desktop Entry]`.
# Only clearing `active` there drops the whole entry, and most real apps carry a
# `[Desktop Action …]` group — the first version of this passed its fixture only
# because the fixture was a single-group file (measured: probe.desktop with one
# action group was absent from both the menu and the map).
gen_entries() {
  local -a files=()
  local dir file
  while IFS= read -r dir; do
    [ -d "$dir/applications" ] || continue
    while IFS= read -r file; do files+=("$file"); done \
      < <(find "$dir/applications" -maxdepth 1 -name '*.desktop' 2>/dev/null | sort)
  done < <(data_dirs)

  [ ${#files[@]} -gt 0 ] || return 0

  awk -v menu="$MENU_FILE.new" -v map="$MAP_FILE.new" '
    function flush() {
      if (active && name != "" && exec != "" && type == "Application" && !nodisplay) {
        gsub(/%[a-zA-Z]/, "", exec)
        sub(/[[:space:]]+$/, "", exec)
        if (exec != "" && name !~ /\t/) {
          print name > menu
          printf "%s\t%s\t%d\n", name, exec, terminal > map
        }
      }
      name = ""; exec = ""; type = ""; nodisplay = 0; terminal = 0; active = 0
    }
    FNR == 1 { flush() }
    /^\[Desktop Entry\]/ { flush(); active = 1; next }
    /^\[/ { flush(); active = 0; next }
    active && /^Name=/ && !/^Name\[/ { if (name == "") name = substr($0, 6) }
    active && /^Exec=/ && !/^Exec\[/ { if (exec == "") exec = substr($0, 6) }
    active && /^Type=/ { if (type == "") type = substr($0, 6) }
    active && /^NoDisplay=true/ { nodisplay = 1 }
    active && /^Terminal=true/ { terminal = 1 }
    END { flush() }
  ' "${files[@]}"
}

# $PATH names, like dmenu_path: a profile is symlinks into the store, so the test
# has to accept links, and the listing is cached because walking a NixOS $PATH on
# a Celeron is the difference between a launcher and a stutter.
gen_binaries() {
  local dir
  printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r dir; do
    [ -d "$dir" ] || continue
    find "$dir" -maxdepth 1 \( -type f -o -type l \) -executable -printf '%f\n' 2>/dev/null
  done | LC_ALL=C sort -u
}

rebuild_cache() {
  mkdir -p "$CACHE_DIR"
  : >"$MENU_FILE.new"
  : >"$MAP_FILE.new"
  gen_entries
  gen_binaries >>"$MENU_FILE.new"
  LC_ALL=C sort -u -o "$MENU_FILE.new" "$MENU_FILE.new"
  mv "$MENU_FILE.new" "$MENU_FILE"
  mv "$MAP_FILE.new" "$MAP_FILE"
}

fresh() {
  [ -s "$MENU_FILE" ] || return 1
  [ -z "$(find "$MENU_FILE" -mmin +"$TTL_MINUTES" 2>/dev/null)" ]
}

main() {
  fresh || rebuild_cache

  local -a flags=()
  case "$DMENU" in
    *wmenu)
      flags=(-i -f "$MENU_FONT" -N 1e1e2e -n cdd6f4 -M 313244 -m cdd6f4 -S cba6f7 -s 11111b)
      ;;
  esac

  local sel
  sel=$("$DMENU" "${flags[@]}" <"$MENU_FILE") || exit 0
  [ -n "$sel" ] || exit 0

  local line exec_cmd is_terminal
  if line=$(awk -F'\t' -v want="$sel" '$1 == want {print; exit}' "$MAP_FILE") && [ -n "$line" ]; then
    IFS=$'\t' read -r _ exec_cmd is_terminal <<<"$line"
    if [ "$is_terminal" = "1" ]; then
      exec "$TERMINAL" -e "$exec_cmd"
    fi
    exec sh -c "$exec_cmd"
  fi

  exec "$sel"
}

main "$@"
