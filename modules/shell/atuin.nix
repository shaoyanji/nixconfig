# atuin on every host, pointed at the one server; bash, zsh and nushell get the
# Ctrl-R UI. Key: modules/sops.nix · server: modules/services/atuin-server.nix ·
# login/import: .agents/skills/atuin/SKILL.md
{
  lib,
  pkgs,
  ...
}: {
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    # Only links where programs.zsh is enabled (modules/shell/zsh.nix); the
    # silent-stub failure is docs/nix-patterns.md item 15.
    enableZshIntegration = true;

    # The tailnet address, not atuin.frieren.lan: the .lan names only resolve
    # against frieren's resolver. Plain http, because with no session file atuin
    # stays local-only and offline.
    settings = {
      auto_sync = true;
      sync_address = "http://100.97.61.65";
      sync_frequency = "30s";
      update_check = false;
      search_mode = "fuzzy";
      style = "compact";
      filter_mode = "global";
      filter_mode_shell_up_key_binding = "global";
      search = {
        filters = [
          "global"
          "host"
          "session"
          "workspace"
          "directory"
          "session-preload"
        ];
        shells = "all";
      };
    };
  };

  # Automatic login & initial sync oneshot for clients; procedure: .agents/skills/atuin/SKILL.md
  systemd.user.services.atuin-auto-login = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Ensure atuin client is logged in and synced to fleet server";
      After = ["sops-nix.service"];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "atuin-auto-login" ''
        set -euo pipefail
        DATA="''${XDG_DATA_HOME:-$HOME/.local/share}/atuin"
        SECRETS="''${XDG_CONFIG_HOME:-$HOME/.config}/sops-nix/secrets"

        if atuin status >/dev/null 2>&1; then
          atuin sync >/dev/null 2>&1 || true
          exit 0
        fi

        PASS="$SECRETS/atuin-password"
        MNEMONIC="$SECRETS/atuin-mnemonic"
        if [ ! -f "$PASS" ] || [ ! -f "$MNEMONIC" ]; then
          exit 0
        fi

        SYNC_ADDR="$(atuin config get sync_address 2>/dev/null | tail -1)"
        authority="''${SYNC_ADDR#*://}"
        authority="''${authority%%/*}"
        host="''${authority%%:*}"
        port="''${authority##*:}"
        [ "$port" = "$authority" ] && port=80

        if timeout 3 ${pkgs.bash}/bin/bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
          atuin login -u devji -p "$(cat "$PASS")" -k "$(cat "$MNEMONIC")" >/dev/null 2>&1 || true
          if [ ! -e "$DATA/.fleet-seeded" ]; then
            [ -f "$HOME/.config/nushell/history.sqlite3" ] && atuin import nu-hist-db >/dev/null 2>&1 || true
            [ -s "$HOME/.bash_history" ] && atuin import bash >/dev/null 2>&1 || true
            mkdir -p "$DATA"
            touch "$DATA/.fleet-seeded"
          fi
          atuin sync >/dev/null 2>&1 || true
        fi
      ''}";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };

  # Clear an inherited PS0, and its export attribute, before bash-preexec hooks
  # it; mkOrder 1 puts this ahead of the integrations below. Mechanism and
  # evidence: docs/nix-patterns.md item 13.
  programs.bash.initExtra = lib.mkOrder 1 ''
    export -n PS0 2>/dev/null || true
    PS0=
  '';
}
