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

  # The harness runs on the worker (`services.dshWeb`), which publishes it under
  # its own TLS ingress at /deepseek/; this is the client half. Shared with the
  # hosts that install it directly (frieren), so there is one definition of what
  # `dsh-remote` means and one place to change it.
  dshRemote = import ../../scripts/dsh-remote.nix {inherit pkgs;};

  # Local entry, only where the harness is actually installed (tier "full").
  dshLocal = pkgs.writeShellApplication {
    name = "dsh-local";
    runtimeInputs = [pkgs.llm-agents.dsh];
    text = ''
      set -euo pipefail
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
    home.packages = [dshRemote] ++ lib.optional (config.profiles.ai.tier == "full") dshLocal;

    home.file =
      {
        ".local/share/icons/hicolor/256x256/apps/deepseek.png".source = iconFile;
        ".local/share/applications/dsh-remote.desktop".text = desktop "DeepSeek Harness (Remote)" "Open the harness running on the worker" "dsh-remote" "ai;agent;dsh;deepseek;remote;browser";
      }
      // lib.optionalAttrs (config.profiles.ai.tier == "full") {
        ".local/share/applications/dsh.desktop".text = desktop "DeepSeek Harness" "Start the local harness and open its web UI" "dsh-local" "ai;agent;dsh;deepseek;local";
      };
  }
