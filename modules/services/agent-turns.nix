# Agent turn coordination: a local xs store plus the only network surface in
# front of it. The store has no network namespace and no address it may bind;
# the shim holds the bearer token, validates the turn schema and answers 405 to
# every write that is not an append, because xs itself has DELETE and /import.
# Design, API, verification and restore procedure: docs/agent-turns.md.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.agentTurns;

  # Upstream publishes a prebuilt arm64 binary per release. Building the crate
  # here would mean compiling Nushell 0.116 on a 2-vCPU guest; the release asset
  # is the same artefact the project's own pipeline produces, pinned by hash.
  xsPackage = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "cross-stream";
    version = "0.14.2";

    src = pkgs.fetchurl {
      url = "https://github.com/cablehead/xs/releases/download/v${version}/cross-stream-v${version}-linux-${arch}.tar.gz";
      hash = hashes.${arch} or (throw "cross-stream: no prebuilt binary for ${arch}");
    };

    sourceRoot = "cross-stream-v${version}";
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      install -Dm755 xs $out/bin/xs
    '';

    meta = with lib; {
      description = "Local-first append-only event stream store";
      homepage = "https://github.com/cablehead/xs";
      license = licenses.mit;
      mainProgram = "xs";
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  };

  sys = pkgs.stdenv.hostPlatform.system;
  arch =
    if sys == "aarch64-linux"
    then "arm64"
    else if sys == "x86_64-linux"
    then "amd64"
    else sys;
  hashes = {
    arm64 = "sha256-APkEWINzhrdG+IjpdQf0e4gyN/yDsDOtpwoptZrKCeE=";
    amd64 = "sha256-Q9YfvvarRYuPYb5mWZqf8K7lfVoObE2MwrRn5nu9UIU=";
  };

  user = import ../global/user.nix;
  stateDir = "/var/lib/${cfg.stateDirectory}";
  storePath = "${stateDir}/store";
  socketPath = "${storePath}/sock";

  waitForSocket = pkgs.writeShellApplication {
    name = "agent-turns-wait-socket";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      for _ in $(seq 1 60); do
        if [ -S "${socketPath}" ]; then
          exit 0
        fi
        sleep 1
      done
      echo "xs socket ${socketPath} missing after 60s" >&2
      exit 1
    '';
  };
in {
  options.services.agentTurns = {
    enable = lib.mkEnableOption "the agent-turn coordination store (xs) and its authenticated shim";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8093;
      description = ''
        Loopback port the shim listens on. The tailnet mount points here; the
        shim never binds a public or tailnet address itself.
      '';
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "xs-agent-turns";
      description = "systemd StateDirectory holding the xs store, the socket and the dedup index.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "xs-agent-turns";
      description = "System user that owns both processes and the state directory.";
    };

    tokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "agent-turns-token";
      description = ''
        sops secret holding the fleet shim bearer token. It is the only credential
        in this design: xs has no authentication of its own, and the shim refuses
        to start without a token file it can read.
      '';
    };

    additionalTokens = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Extra sops secret names whose values are also accepted as bearer tokens,
        one per holder that is not a fleet agent (the netbook's, for instance).
        Separate tokens, not a shared one: revoking an agent removes its secret
        from `sops.yaml`-backed config without touching the fleet credential, and
        the shim's access log names which token authenticated each append.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = xsPackage;
      description = "The xs binary to serve.";
    };

    backup = {
      enable = lib.mkEnableOption "a nightly export of the store, optionally shipped to another host";

      directory = lib.mkOption {
        type = lib.types.str;
        default = "/var/backups/xs-agent-turns";
        description = ''
          Dated dump root. Each run writes one `YYYY-MM-DDTHHMM` directory holding
          `frames.jsonl` and `cas/` — the shape `xs import` restores.
        '';
      };

      startAt = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 03:05:00";
        description = ''
          When the export runs. Any host that copies these dumps has its own
          snapshot to make, so this is earlier than the snapshots and later than
          the previous day's load.
        '';
      };

      retain = lib.mkOption {
        type = lib.types.ints.positive;
        default = 7;
        description = "Days of local dumps to keep. A dump older than this is removed after a successful run.";
      };

      pushTo = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          rsync destination (`user@host:/path/`) to ship the dump tree to, or empty
          to keep the dumps on this host only. The destination is mirrored, so it
          must exist for this dump tree alone: anything else there is deleted.
        '';
      };

      pushKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/home/${user.name}/.ssh/id_ed25519";
        description = ''
          Key the push authenticates with. The unit runs as root because the store
          is 0700 between two service users, and root reading the fleet key is one
          credential decision instead of a second user owning half the store.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # `xs` on PATH for the operator commands in AGENTS.md and for the export
    # hook; the running service uses the same store path either way.
    environment.systemPackages = [cfg.package];

    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "Agent turn coordination store";
    };

    # Every accepted token is a declared secret, so the shim's credential set is
    # whatever this host activated — no directory scan, no unlabelled file.
    sops.secrets = lib.genAttrs ([cfg.tokenSecret] ++ cfg.additionalTokens) (_: {
      owner = cfg.user;
      group = cfg.user;
      mode = "0400";
      # The NixOS plane's file; modules/profiles/base-node.nix sets the same
      # default, and naming it here keeps the secret's home visible at its use.
      sopsFile = ../../modules/secrets.yaml;
      # The shim reads its tokens once, at start. Without this a rotated value
      # reaches /run/secrets and nothing notices until the next reboot.
      restartUnits = ["agent-turns-shim.service"];
    });

    systemd.services.xs-agent-turns = {
      description = "xs event stream store for agent turns (Unix socket only)";
      wantedBy = ["multi-user.target"];
      # No ordering on sops: on this fleet the secrets are installed by the
      # activation script itself, not by a `sops-install-secrets` unit, so a
      # `requires` on that name leaves the unit unstartable.
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = cfg.stateDirectory;
        # Owner-only, socket included: xs has no auth on that socket, so a
        # world-readable one would let any local user DELETE a frame and undo
        # the append-only promise the shim makes.
        StateDirectoryMode = "0700";
        UMask = "0077";
        # `always`: an append that returned has reached the journal, so a turn
        # reported as stored cannot vanish in a power loss.
        ExecStart = "${cfg.package}/bin/xs serve ${storePath} --fsync always";
        Restart = "always";
        RestartSec = 2;

        # No network, ever. The store is a filesystem object; the only client is
        # the shim next door, over the socket in the state directory.
        PrivateNetwork = true;
        RestrictAddressFamilies = ["AF_UNIX"];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        MemoryMax = "512M";
      };
    };

    systemd.services.agent-turns-shim = {
      description = "Authenticated append-only shim in front of the agent-turn store";
      wantedBy = ["multi-user.target"];
      after = ["xs-agent-turns.service"];
      requires = ["xs-agent-turns.service"];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "0700";
        # `After=` is ordering, not readiness: xs prints its first frame before
        # the socket is connectable, and a shim that exits on the race makes the
        # whole switch fail (measured: status 4/NOPERMISSION).
        ExecStartPre = "${waitForSocket}/bin/agent-turns-wait-socket";
        ExecStart = "${pkgs.python3}/bin/python3 ${./agent-turns/shim.py}";
        Environment = [
          "XS_SOCKET=${socketPath}"
          "AGENT_TURNS_TOKENS=${
            lib.concatStringsSep ":" (
              map (name: "${name}=${config.sops.secrets.${name}.path}") ([cfg.tokenSecret] ++ cfg.additionalTokens)
            )
          }"
          "AGENT_TURNS_DB=${stateDir}/dedup.sqlite"
          "AGENT_TURNS_BIND=127.0.0.1"
          "AGENT_TURNS_PORT=${toString cfg.port}"
        ];
        Restart = "always";
        RestartSec = 2;

        RestrictAddressFamilies = ["AF_UNIX" "AF_INET"];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        MemoryMax = "256M";
      };
    };

    systemd.services.xs-agent-turns-backup = lib.mkIf cfg.backup.enable {
      description = "Export the agent-turn store and ship it to the backup host";
      # No sandboxing beyond the default here: the unit reads the 0700 store as
      # root, writes /var/backups and opens one outbound ssh. `ProtectHome` would
      # hide the key it authenticates with.
      path = [cfg.package pkgs.jq pkgs.rsync pkgs.openssh pkgs.findutils pkgs.coreutils pkgs.bash];
      serviceConfig.Type = "oneshot";
      # One run: dump, ship, prune — in that order, so a failed export cannot
      # leave the far side holding a fresh timestamp over yesterday's frames.
      script = ''
        set -euo pipefail
        dir="${cfg.backup.directory}"
        out="$dir/$(date +%Y-%m-%dT%H%M)"

        mkdir -p "$dir"
        bash ${../../scripts/task/xs-agent-turns-export.sh} "$out"
        ${lib.optionalString (cfg.backup.pushTo != "") ''
          # `--delete` is safe because this destination is the mirror of this one
          # tree; `--delay-updates` installs each file at the end of the transfer,
          # so a snapshot taken mid-run cannot catch a half-written dump.
          rsync -a --delete --delay-updates \
            -e "ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${stateDir}/known_hosts -i ${cfg.backup.pushKeyFile}" \
            "$dir/" "${cfg.backup.pushTo}"
        ''}
        find "$dir" -mindepth 1 -maxdepth 1 -type d -name '20??-*' -mtime "+${toString cfg.backup.retain}" -exec rm -rf {} +
      '';
    };

    systemd.timers.xs-agent-turns-backup = lib.mkIf cfg.backup.enable {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.backup.startAt;
        # A host asleep at 03:05 owes itself the dump, not a skipped night.
        Persistent = true;
        RandomizedDelaySec = "120s";
      };
    };
  };
}
