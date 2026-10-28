#!/usr/bin/env bash
# Pick an AppImage from the shared library by NAME and launch it.
#
# The library is a directory listing and nothing more: names come from the glob,
# no image is opened, hashed, extracted or cached, and nothing runs until the
# user picks an entry. A launch is the only event that touches image bytes, so a
# library full of fresh images costs one readdir — never a LAN-wide transfer.
#
# Picker: $APPIMAGE_MENU_PICKER, else the first of fuzzel, wmenu, dmenu. fuzzel
# on the desktop profiles, wmenu on the low-end ones, no configuration to drift.
#
# Exit: 0 = launched or cancelled, 1 = no library / no menu.
set -euo pipefail

DIR="${APPIMAGE_DIR:-/Volumes/data/appimages}"

if [ ! -d "$DIR" ]; then
  echo "appimage-menu: no library at $DIR" >&2
  exit 1
fi

shopt -s nullglob
images=("$DIR"/*.AppImage)
shopt -u nullglob

if [ ${#images[@]} -eq 0 ]; then
  echo "appimage-menu: no *.AppImage in $DIR" >&2
  exit 1
fi

names=()
for img in "${images[@]}"; do
  base="${img##*/}"
  names+=("${base%.AppImage}")
done

picker=""
if [ -n "${APPIMAGE_MENU_PICKER:-}" ]; then
  command -v "$APPIMAGE_MENU_PICKER" >/dev/null 2>&1 && picker="$APPIMAGE_MENU_PICKER"
else
  for candidate in fuzzel wmenu dmenu; do
    if command -v "$candidate" >/dev/null 2>&1; then
      picker="$candidate"
      break
    fi
  done
fi

if [ -z "$picker" ]; then
  echo "appimage-menu: no menu picker (fuzzel, wmenu or dmenu)" >&2
  exit 1
fi

prompt="appimage: "
case "$picker" in
  fuzzel) choice="$(printf '%s\n' "${names[@]}" | fuzzel --dmenu --prompt "$prompt")" ;;
  rofi) choice="$(printf '%s\n' "${names[@]}" | rofi -dmenu -i -p "$prompt")" ;;
  *) choice="$(printf '%s\n' "${names[@]}" | "$picker" -i -p "$prompt")" ;;
esac

[ -n "${choice:-}" ] || exit 0

exec appimage-run "$DIR/$choice.AppImage"
