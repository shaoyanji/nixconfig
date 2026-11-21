# appimage-menu — the AppImage library as a menu of names. Body lives here, not
# a loose .sh (writeShellApplication lints at build). Consumers:
# modules/profiles/dwl-desktop.nix, hosts/scratch/configuration.nix.
# Library reads nothing until a pick — flake/policies.nix#library-content-is-not-scheduled.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "appimage-menu";
  runtimeInputs = [pkgs.appimage-run];
  text = ''
    set -euo pipefail

    DIR="''${APPIMAGE_DIR:-/Volumes/data/appimages}"

    if [ ! -d "$DIR" ]; then
      echo "appimage-menu: no library at $DIR" >&2
      exit 1
    fi

    shopt -s nullglob
    images=("$DIR"/*.AppImage)
    shopt -u nullglob

    if [ ''${#images[@]} -eq 0 ]; then
      echo "appimage-menu: no *.AppImage in $DIR" >&2
      exit 1
    fi

    names=()
    for img in "''${images[@]}"; do
      base="''${img##*/}"
      names+=("''${base%.AppImage}")
    done

    picker=""
    if [ -n "''${APPIMAGE_MENU_PICKER:-}" ]; then
      command -v "$APPIMAGE_MENU_PICKER" >/dev/null 2>&1 && picker="$APPIMAGE_MENU_PICKER"
    else
      for candidate in wmenu dmenu; do
        if command -v "$candidate" >/dev/null 2>&1; then
          picker="$candidate"
          break
        fi
      done
    fi

    if [ -z "$picker" ]; then
      echo "appimage-menu: no menu picker (wmenu or dmenu)" >&2
      exit 1
    fi

    prompt="appimage: "
    choice="$(printf '%s\n' "''${names[@]}" | "$picker" -i -p "$prompt")"

    [ -n "''${choice:-}" ] || exit 0

    exec appimage-run "$DIR/$choice.AppImage"
  '';
}
