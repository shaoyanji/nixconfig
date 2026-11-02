# Keep an autoUpgrade host's flake inputs out of the nightly garbage collection.
# `nix flake archive` on determinate-nix 3.23.3 has no `--out-link`, so the roots
# are written with `nix-store --add-root`. docs/nix-patterns.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.flakeGcRoot;

  rootScript = pkgs.writeShellApplication {
    name = "flake-gc-root";
    runtimeInputs = [config.nix.package pkgs.jq pkgs.coreutils];
    text = ''
      ref="$1"
      dir="$2"

      archive="$(mktemp)"
      trap 'rm -f "$archive"' EXIT

      # Materialising the archive is what puts the sources and every input in the
      # store; the roots below are what keeps the 03:15 GC from taking them.
      nix flake archive --json "$ref" > "$archive"
      mkdir -p "$dir"

      keep=""
      while IFS= read -r path; do
        name="$(basename "$path")"
        nix-store --add-root "$dir/$name" --indirect --realise "$path" > /dev/null
        keep="$keep $name"
      done < <(jq -r '.. | objects | .path? // empty' "$archive" | sort -u)

      # An input that left the lock file would otherwise keep its old root and
      # hold the path alive for good.
      for link in "$dir"/*; do
        [ -L "$link" ] || continue
        base="$(basename "$link")"
        case " $keep " in
          *" $base "*) ;;
          *) rm -f "$link" ;;
        esac
      done

      echo "rooted $(wc -w <<< "$keep") path(s) under $dir"
    '';
  };
in {
  options.services.flakeGcRoot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.system.autoUpgrade.enable;
      defaultText = lib.literalExpression "config.system.autoUpgrade.enable";
      description = "Root the deployed flake and its inputs so a GC cannot collect them.";
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = config.system.autoUpgrade.flake;
      defaultText = lib.literalExpression "config.system.autoUpgrade.flake";
      description = "Flake reference to archive — the same ref the upgrade evaluates.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "05:00";
      description = ''
        When to (re)root, `HH:MM`. Must be after `system.autoUpgrade` — frieren
        upgrades at 04:00 and delphi at 04:30, so 05:00 covers the fleet.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.flake-gc-root = {
      description = "Root the deployed flake and its inputs against the nightly GC";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        # `nix flake archive` takes no attribute fragment: it archives the flake,
        # which is the source plus its inputs, and that is what the GC eats.
        ExecStart = "${rootScript}/bin/flake-gc-root ${lib.escapeShellArg (builtins.head (lib.splitString "#" cfg.flake))} /nix/var/nix/gcroots/flake/${config.networking.hostName}";
        Nice = 15;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.flake-gc-root = {
      description = "Nightly: keep the deployed flake's inputs out of the GC";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-* ${cfg.schedule}:00";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };
  };
}
