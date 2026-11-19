# `dsh` desktop launchers: open the agent deck in the best terminal available.
{
  pkgs,
  lib,
  config,
  ...
}: let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  # DeepSeek's square mark, fetched at build into the store — no binary in git.
  # The favicon is an ICO; XDG icon lookup does not index ICO containers, so it
  # is converted once here and the PNG is what gets installed.
  iconIco = pkgs.fetchurl {
    url = "https://www.deepseek.com/favicon.ico";
    hash = "sha256-MKRCDm5Nyxf9feVgxQBDRsK8jNlx0tX17hUyZgPlEyE=";
  };
  iconFile = pkgs.runCommand "deepseek.png" {nativeBuildInputs = [pkgs.imagemagick];} ''
    magick ${iconIco} -resize 256x256 $out
  '';

  # The remote client half retired with the worker's harness —
  # modules/user/ai/dsh-launcher.shadow.nix; it revives when the service does.
  # The `dsh` CLI itself stays: scripts/dispatch.sh routes to it.

  # Local entry, only where the harness is actually installed (tier "full").
  # `dsh web` prints a tokenised URL and opens it; the bare port answers 401 by
  # design and two instances fight over it, so a live listener means "already
  # running" rather than "start another".
  dshLocal = pkgs.writeShellApplication {
    name = "dsh-local";
    runtimeInputs = [pkgs.llm-agents.dsh pkgs.iproute2 pkgs.gawk pkgs.gnugrep];
    text = ''
      set -euo pipefail
      port="''${DSH_PORT:-3080}"
      if ss -ltnH 2>/dev/null | awk '{print $4}' | grep -qE "[:.]''${port}$"; then
        echo "dsh web is already serving on port $port." >&2
        echo "Its tokenised URL is in the terminal that started it." >&2
        exit 0
      fi
      TITLE="DeepSeek Harness (local)"
      if command -v kitty >/dev/null 2>&1; then
        exec kitty --title "$TITLE" -e dsh web
      elif command -v alacritty >/dev/null 2>&1; then
        exec alacritty -T "$TITLE" -e dsh web
      else
        exec "''${TERMINAL:-xterm}" -e dsh web
      fi
    '';
  };

  desktop = label: comment: exec: keywords: ''
    [Desktop Entry]
    Type=Application
    Name=${label}
    GenericName=Agent Harness
    Comment=${comment}
    Exec=${exec}
    Icon=deepseek
    Terminal=false
    Categories=Development;Utility;
    Keywords=${keywords};
  '';
in
  lib.mkIf (config.profiles.ai.enable && isLinux) {
    home.packages = lib.optional (config.profiles.ai.tier == "full") dshLocal;

    home.file =
      {
        ".local/share/icons/hicolor/256x256/apps/deepseek.png".source = iconFile;
      }
      // lib.optionalAttrs (config.profiles.ai.tier == "full") {
        ".local/share/applications/dsh.desktop".text = desktop "DeepSeek Harness" "Start the local harness and open its web UI" "dsh-local" "ai;agent;dsh;deepseek;local";
      };
  }
