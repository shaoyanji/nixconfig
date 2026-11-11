# Agent turns -> a desktop notification. The xs turn log is coordination state on
# delphi; this is the reader that says a turn landed while you are looking at
# another window. One poller per machine, because a libnotify toast is a
# session-bus call and delphi has no session to put it on: delphi serves the log,
# the devices with a compositor do the toasting.
#
# A NixOS module rather than a Home Manager one on purpose: the netbook runs
# alice's `~/.dotfiles` with no home-manager generation, so an HM unit would
# reach every device except the one this was written for.
#
# The turn log is newest-first and every event carries a client UUID. The mark
# file holds the newest id that was actually toasted, so a machine that was off
# overnight toasts what is new instead of replaying the night, and a send that
# fails leaves the mark where it was. docs/agent-turns.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.xsNotify;

  toast = pkgs.writeShellApplication {
    name = "xs-notify";
    runtimeInputs = with pkgs; [
      curl
      jq
      libnotify
      coreutils
      gnugrep
    ];
    text = ''
      token_file="''${XS_TOKEN_FILE:-$HOME/.config/agent-turns/token}"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/agent-turns"
      mark_file="$state_dir/notified-frame"
      mkdir -p "$state_dir"

      token="''${AGENT_TURNS_TOKEN:-}"
      if [ -z "$token" ] && [ -r "$token_file" ]; then
        token=$(cat "$token_file")
      fi
      [ -n "$token" ] || exit 0

      # A poll that cannot reach the shim is not an error to report every two
      # minutes; the next tick is the retry, and the mark has not moved.
      resp=$(curl -sS --max-time 15 \
        -H "Authorization: Bearer $token" \
        ${lib.escapeShellArg "${cfg.url}/v1/events?limit=20"}) || exit 0
      [ -n "$resp" ] || exit 0

      mark=$(cat "$mark_file" 2>/dev/null || true)
      rows=$(printf '%s' "$resp" | jq -r \
        --arg mark "$mark" \
        --arg repos ${lib.escapeShellArg cfg.repos} \
        --arg ignore ${lib.escapeShellArg cfg.ignoreSources} '
          .events
          | map(select(.kind == "turn"))
          | map(select(($ignore == "") or ((.source // "") | test($ignore) | not)))
          | map(select(($repos == "") or ((.subject // "") | test($repos))))
          | . as $e
          | ($e | map(.id) | index($mark)) as $i
          | (if $i == null then $e else $e[0:$i] end)
          | reverse
          | .[]
          | [.id, (.subject // ""), (.source // ""), (.outcome // ""), (.action // "")] | @tsv') || exit 0

      delivered=0
      failed=0
      while IFS=$(printf '\t') read -r id subject source outcome action; do
        [ -n "$id" ] || continue
        body="$source"
        if [ -n "$outcome" ]; then body="$source · $outcome"; fi
        if [ -n "$action" ]; then body="$action"; fi
        if notify-send --app-name="agent turns" \
          --urgency=${lib.escapeShellArg cfg.urgency} \
          --category="im.received" \
          "$subject" "$body"; then
          delivered=$((delivered + 1))
          printf '%s\n' "$id" >"$mark_file"
        else
          failed=$((failed + 1))
        fi
      done <<<"$rows"

      if [ "$delivered" -gt 0 ] || [ "$failed" -gt 0 ]; then
        printf 'xs-notify: %s toasted, %s failed\n' "$delivered" "$failed"
      fi
    '';
  };
in {
  options.services.xsNotify = {
    enable = lib.mkEnableOption "desktop notifications for new agent turns (xs)";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://delphi.cloudforest-kardashev.ts.net:8449";
      description = "Base URL of the tailnet xs shim — not loopback, the serve front is the tailnet.";
    };

    intervalMinutes = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Poll period. A read costs no model budget.";
    };

    repos = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Regex on the subject's `<repo>` half; empty toasts every repo.";
    };

    ignoreSources = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Regex on `source`; turns from this agent are not toasted.";
    };

    urgency = lib.mkOption {
      type = lib.types.enum ["low" "normal" "critical"];
      default = "low";
      description = "libnotify urgency for a turn.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [toast];

    # NixOS keys, not Home Manager ones: `unitConfig`/`serviceConfig`, and no
    # `after = ["graphical-session.target"]`, which dwl never activates — the
    # oneshot would wait for a target that does not exist. A notify-send with no
    # session bus fails, leaves the mark alone and retries on the next tick.
    systemd.user.services.xs-notify = {
      description = "Toast new agent turns from the xs log";
      unitConfig = {
        # No token, no reader: the timer keeps ticking and the service is
        # skipped, so a machine that is not a holder has no red unit.
        ConditionPathExists = "%h/.config/agent-turns/token";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${toast}/bin/xs-notify";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    systemd.user.timers.xs-notify = {
      description = "Poll the xs turn log every ${toString cfg.intervalMinutes} minutes";
      timerConfig = {
        OnCalendar = "*:0/${toString cfg.intervalMinutes}";
        Persistent = true;
      };
      wantedBy = ["timers.target"];
    };
  };
}
