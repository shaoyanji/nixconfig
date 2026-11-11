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
      # sops-nix writes the credentials this unit reads and one HM activation
      # starts both. `After=` alone lost that race on aristotle (2026-11-11): the
      # unit ran three seconds before sops-nix, found no secrets and exited 0.
      Wants = ["sops-nix.service"];
      After = ["sops-nix.service"];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Retry instead of reporting a hollow success — a missing secret, a failed
      # login or a failed sync now leaves a failed unit behind.
      Restart = "on-failure";
      RestartSec = 10;
      ExecStart = "${pkgs.writeShellScript "atuin-auto-login" ''
        set -euo pipefail
        DATA="''${XDG_DATA_HOME:-$HOME/.local/share}/atuin"
        SECRETS="''${XDG_CONFIG_HOME:-$HOME/.config}/sops-nix/secrets"

        # atuin 18 wants a session id even for a headless `sync`. Without one it
        # dies in database.rs; with the old `|| true` it then wrote the seed
        # marker and reported success (measured on aristotle 2026-11-11).
        export ATUIN_SESSION="''${ATUIN_SESSION:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "atuin-auto-login-$$-$RANDOM")}"

        if atuin status >/dev/null 2>&1; then
          atuin sync >/dev/null 2>&1 || exit 1
          exit 0
        fi

        PASS="$SECRETS/atuin-password"
        MNEMONIC="$SECRETS/atuin-mnemonic"
        # A fresh activation can start this before the user-level sops-nix unit
        # has written the secrets: wait for them rather than exiting 0.
        waited=0
        while [ "$waited" -lt 30 ] && { [ ! -f "$PASS" ] || [ ! -f "$MNEMONIC" ]; }; do
          sleep 1
          waited=$((waited + 1))
        done
        if [ ! -f "$PASS" ] || [ ! -f "$MNEMONIC" ]; then
          echo "atuin-auto-login: no credentials after 30s — sops-nix did not land" >&2
          exit 1
        fi

        SYNC_ADDR="$(atuin config get sync_address 2>/dev/null | tail -1)"
        authority="''${SYNC_ADDR#*://}"
        authority="''${authority%%/*}"
        host="''${authority%%:*}"
        port="''${authority##*:}"
        [ "$port" = "$authority" ] && port=80

        if timeout 3 ${pkgs.bash}/bin/bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
          atuin login -u devji -p "$(cat "$PASS")" -k "$(cat "$MNEMONIC")" >/dev/null 2>&1 ||
            { echo "atuin-auto-login: login to $SYNC_ADDR failed" >&2; exit 1; }
          if [ ! -e "$DATA/.fleet-seeded" ]; then
            [ -f "$HOME/.config/nushell/history.sqlite3" ] && atuin import nu-hist-db >/dev/null 2>&1 || true
            [ -s "$HOME/.bash_history" ] && atuin import bash >/dev/null 2>&1 || true
            mkdir -p "$DATA"
            touch "$DATA/.fleet-seeded"
          fi
          atuin sync >/dev/null 2>&1 || { echo "atuin-auto-login: sync to $SYNC_ADDR failed" >&2; exit 1; }
        else
          echo "atuin-auto-login: cannot reach $host:$port ($SYNC_ADDR)" >&2
          exit 1
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
