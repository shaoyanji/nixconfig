#!/usr/bin/env bash
# Integrate the AppImages of a shared library into the user's application menu.
#
# The library lives on the NAS (56 images, 6.9 GB on frieren) and is shared by
# several clients, so nothing is copied: every entry points at the AppImage where
# it already is. Metadata comes from the image's own squashfs via `unsquashfs
# -cat` — the image is never executed, which matters for a folder of
# unmaintained binaries.
#
# Neither DMS nor fuzzel needs a plugin: both read XDG desktop entries, and the
# entries written here land in ~/.local/share/applications.
#
# Exit: 0 = done (including "nothing to do"), 1 = library unreadable,
# 2 = usage error.
set -euo pipefail

APPIMAGE_DIR="${APPIMAGE_DIR:-}"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/appimage-icons"
DRY_RUN=0
QUIET=0

usage() {
  cat <<'EOF'
usage: appimage-integrate [--dir DIR] [--dry-run] [--quiet]

  --dir DIR    AppImage library (default: $APPIMAGE_DIR, else
               ~/Applications/appimages, else /Volumes/data/appimages)
  --dry-run    Print what would be written, touch nothing
  --quiet      Only print the summary
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      APPIMAGE_DIR="${2:?--dir needs a value}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "appimage-integrate: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

say() { [ "$QUIET" = 1 ] || echo "$*"; }

if [ -z "$APPIMAGE_DIR" ]; then
  for candidate in "$HOME/Applications/appimages" /Volumes/data/appimages; do
    if [ -d "$candidate" ]; then
      APPIMAGE_DIR="$candidate"
      break
    fi
  done
fi

if [ -z "$APPIMAGE_DIR" ] || [ ! -d "$APPIMAGE_DIR" ]; then
  say "appimage-integrate: no AppImage library (looked at \$APPIMAGE_DIR, ~/Applications/appimages, /Volumes/data/appimages)"
  exit 0
fi
if [ ! -r "$APPIMAGE_DIR" ]; then
  echo "appimage-integrate: $APPIMAGE_DIR is not readable" >&2
  exit 1
fi

# What this machine can execute. The ELF header decides, not the file name: the
# library carries a file called ShannonCalculator-aarch64.AppImage that is
# actually x86-64, and zen-aarch64.AppImage that really is aarch64.
case "$(uname -m)" in
  x86_64) host_arch="x86-64" ;;
  aarch64 | arm64) host_arch="ARM aarch64" ;;
  armv7l) host_arch="ARM" ;;
  *) host_arch="$(uname -m)" ;;
esac

records="$(mktemp)"
stage="$(mktemp -d)"
trap 'rm -rf "$records" "$stage"' EXIT

if [ "$DRY_RUN" = 0 ]; then
  mkdir -p "$APPS_DIR" "$ICON_DIR"
fi

integrated=0
skipped_arch=0
skipped_type=0
failed=0
from_filename=0

for app in "$APPIMAGE_DIR"/*.AppImage; do
  [ -e "$app" ] || continue
  base="$(basename "$app")"

  arch="$(timeout 20 file -b "$app" 2>/dev/null | cut -d, -f2 | sed 's/^ *//')"
  case "$arch" in
    *"$host_arch"*) ;;
    *)
      say "skip (arch ${arch:-unknown}): $base"
      skipped_arch=$((skipped_arch + 1))
      continue
      ;;
  esac

  # Type lives in the ELF padding bytes (AI\x02). Only type 2 is a squashfs;
  # type 1 (ISO9660) is dead upstream and not worth a second code path.
  img_type="$(LC_ALL=C readelf -h "$app" 2>/dev/null | awk 'NR==2{print $12}')"
  if [ "$img_type" != "02" ]; then
    say "skip (type ${img_type:-unknown}): $base"
    skipped_type=$((skipped_type + 1))
    continue
  fi

  # The squashfs starts after the section header table — the same arithmetic the
  # AppImage runtime (and nixpkgs' appimage-exec.sh) use.
  offset="$(LC_ALL=C readelf -h "$app" 2>/dev/null |
    awk 'NR==13{e_shoff=$5} NR==18{e_shentsize=$5} NR==19{e_shnum=$5} END{print e_shoff+e_shentsize*e_shnum}')"
  if [ -z "$offset" ] || [ "$offset" = "0" ]; then
    say "skip (no squashfs offset): $base"
    failed=$((failed + 1))
    continue
  fi

  listing="$(timeout 30 unsquashfs -o "$offset" -ll "$app" 2>/dev/null || true)"
  if [ -z "$listing" ]; then
    say "skip (unreadable squashfs): $base"
    failed=$((failed + 1))
    continue
  fi

  # `-ll` prints the destination prefix; members are relative to it.
  members="$(printf '%s\n' "$listing" | awk 'NF >= 6 {print $6}' | sed 's|^squashfs-root/||')"
  desk="$(printf '%s\n' "$members" | grep -E '^[^/]+\.desktop$' | head -1 || true)"
  icon=""
  if printf '%s\n' "$members" | grep -qx '\.DirIcon'; then
    target="$(printf '%s\n' "$listing" | awk '$6 == "squashfs-root/.DirIcon" {print $8}' |
      sed 's|^squashfs-root/||' | head -1)"
    if [ -n "$target" ] && printf '%s\n' "$members" | grep -qxF "$target"; then
      icon="$target"
    fi
  fi
  if [ -z "$icon" ]; then
    icon="$(printf '%s\n' "$members" | grep -E '^[^/]+\.(png|svg)$' | head -1 || true)"
  fi

  name=""
  comment=""
  categories=""
  terminal="false"
  if [ -n "$desk" ]; then
    text="$(timeout 30 unsquashfs -o "$offset" -cat "$app" "$desk" 2>/dev/null || true)"
    if [ -n "$text" ]; then
      # Bare keys only: `Name[de]=` must not win over `Name=`.
      field() { printf '%s\n' "$text" | sed -n -E "s/^$1=//p" | head -1; }
      name="$(field Name)"
      comment="$(field Comment)"
      categories="$(field Categories)"
      terminal="$(field Terminal)"
      [ -n "$terminal" ] || terminal="false"
    fi
  fi
  if [ -z "$name" ]; then
    # No embedded entry: name it after the file (minus version and arch tags) so
    # the app is still reachable from the launcher.
    name="$(printf '%s' "${base%.AppImage}" |
      sed -E 's/[-_.]?v?[0-9]+(\.[0-9]+)+.*$//; s/[-_.](x86[_-]?64|amd64|aarch64|arm64|arm)([-_.].*)?$//I; s/[-_.]+$//')"
    from_filename=$((from_filename + 1))
  fi

  icon_tmp=""
  if [ -n "$icon" ]; then
    icon_tmp="$stage/icon.$integrated.${icon##*.}"
    if ! timeout 30 unsquashfs -o "$offset" -cat "$app" "$icon" > "$icon_tmp" 2>/dev/null ||
      [ ! -s "$icon_tmp" ]; then
      icon_tmp=""
    fi
  fi

  # Version only orders duplicate builds of the same app; it never reaches the
  # entry.
  version="$(printf '%s' "$base" | grep -oE '[0-9]+(\.[0-9]+)+' | tail -1 || true)"
  [ -n "$version" ] || version="0"

  printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\n' \
    "$name" "$version" "$base" "$icon_tmp" "$comment" "$categories" "$terminal" >> "$records"
done

# Newest build of a name wins; two builds of one app never produce two entries.
winners="$(sort -t "$(printf '\037')" -k1,1 -k2,2V "$records" |
  awk -F'\037' '{last[$1] = $0} END {for (n in last) print last[n]}' | sort)"

written=""
while IFS="$(printf '\037')" read -r name version base icon_tmp comment categories terminal; do
  [ -n "$name" ] || continue
  slug="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  [ -n "$slug" ] || slug="$(printf '%s' "${base%.AppImage}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g')"
  entry="$APPS_DIR/appimage-$slug.desktop"
  icon_final=""
  if [ -n "$icon_tmp" ] && [ -s "$icon_tmp" ]; then
    icon_final="$ICON_DIR/$slug.${icon_tmp##*.}"
    [ "$DRY_RUN" = 1 ] || cp "$icon_tmp" "$icon_final"
  fi
  if [ "$DRY_RUN" = 1 ]; then
    say "would write $entry  (Exec=$APPIMAGE_DIR/$base${icon_final:+, Icon=$icon_final})"
  else
    {
      echo "[Desktop Entry]"
      echo "Type=Application"
      echo "Name=$name"
      [ -n "$comment" ] && echo "Comment=$comment"
      echo "Exec=\"$APPIMAGE_DIR/$base\""
      [ -n "$icon_final" ] && echo "Icon=$icon_final"
      echo "Terminal=${terminal:-false}"
      [ -n "$categories" ] && echo "Categories=$categories"
      echo "X-AppImage-Integrator=appimage-integrate"
    } > "$entry"
    chmod 0644 "$entry"
  fi
  written="$written $slug"
  integrated=$((integrated + 1))
done <<EOF
$winners
EOF

# Drop entries and icons for images that left the library.
if [ "$DRY_RUN" = 0 ]; then
  for stale in "$APPS_DIR"/appimage-*.desktop; do
    [ -e "$stale" ] || continue
    slug="$(basename "$stale" .desktop)"
    slug="${slug#appimage-}"
    case " $written " in
      *" $slug "*) ;;
      *)
        say "remove stale entry: $(basename "$stale")"
        rm -f "$stale"
        ;;
    esac
  done
  for stale in "$ICON_DIR"/*; do
    [ -e "$stale" ] || continue
    slug="$(basename "$stale")"
    slug="${slug%.*}"
    case " $written " in
      *" $slug "*) ;;
      *) rm -f "$stale" ;;
    esac
  done
fi

echo "appimage-integrate: $integrated integrated from $APPIMAGE_DIR" \
  "(skipped: $skipped_arch wrong arch, $skipped_type unsupported type, $failed unreadable;" \
  "$from_filename named from filename)"
