# downloads-sort — run the taxonomy sorter on a timer. It runs the same script
# as `task data:sort` (scripts/task/sort-downloads.sh), so a manual run and the
# timer can never disagree about where a staged item goes.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.downloadsSort;

  # PATH is the only difference between the repo script and this copy: the
  # timer has no interactive shell to inherit tool locations from.
  sorter = pkgs.writeShellScriptBin "sort-downloads" ''
    export PATH="${lib.makeBinPath (with pkgs; [coreutils curl file jq ffmpeg findutils gnused gnugrep gawk])}:$PATH"
    ${builtins.readFile ../../scripts/task/sort-downloads.sh}
  '';
in {
  options.services.downloadsSort = {
    enable = lib.mkEnableOption "periodic sorting of the downloads staging area into the storage taxonomy";

    interval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = ''
        systemd `OnCalendar` expression for the sorter timer. Hourly is a
        staging-cleanup cadence, not a deadline: a finished item waits at most
        one interval, and an in-flight download is never touched.
      '';
    };

    replace = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Pass `--replace` to the sorter, letting a staged file overwrite a
        same-named destination that holds different content. Off by default: a
        same-name conflict is a decision, and the sorter reports it instead.
      '';
    };

    classify = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Pass `--classify`: when the file-kind rules cannot place an item, ask a
        local model (`jev-decide`) to pick a destination from the fixed taxonomy
        list. Needs `classifyPath` and `classifyEnvironment`; without them the
        sorter finds no prompt/key and reports the item as unknown, as before.
      '';
    };

    classifyPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Directory holding `jev-decide`. The sorter is pointed at the binary by
        absolute path rather than given a PATH: systemd defines
        `environment.PATH` for every unit, and a second definition there is a
        conflict, not an override.
      '';
    };

    classifyEnvironment = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Environment file with the model provider key, read by the unit.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.downloads-sort = {
      description = "Sort finished downloads into the storage taxonomy"; # Only when classifying: the sorter's own PATH is set by the wrapper.
      environment = lib.optionalAttrs (cfg.classifyPath != null) {
        CLASSIFY_BIN = "${cfg.classifyPath}/jev-decide";
      };
      serviceConfig = {
        Type = "oneshot";
        # Root on purpose: the sorter reads the aria2 RPC secret to see seeding
        # torrents and normalises ownership to devji:users on what it moves.
        User = "root";
        ExecStart = "${sorter}/bin/sort-downloads --apply${
          lib.optionalString cfg.replace " --replace"
        }${lib.optionalString cfg.classify " --classify"}";
        EnvironmentFile =
          lib.optional (cfg.classifyEnvironment != null) cfg.classifyEnvironment;
        PrivateTmp = true;
        # Exit 1 means "an item needs a human decision" (an unknown kind or a
        # same-name conflict). It is left as a unit failure on purpose — that is
        # the signal — and clears as soon as the item is handled or a rule is
        # added to the sorter.
      };
    };

    systemd.timers.downloads-sort = {
      description = "Scheduled downloads staging sort";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    # The sorter is useful by hand too, next to the other task scripts.
    environment.systemPackages = [sorter];
  };
}
