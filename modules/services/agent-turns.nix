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

  stateDir = "/var/lib/${cfg.stateDirectory}";
  storePath = "${stateDir}/store";
  socketPath = "${storePath}/sock";
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
        sops secret holding the shim bearer token. It is the only credential in
        this design: xs has no authentication of its own, and the shim refuses to
        start without a token file it can read.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = xsPackage;
      description = "The xs binary to serve.";
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

    sops.secrets.${cfg.tokenSecret} = {
      owner = cfg.user;
      group = cfg.user;
      mode = "0400";
      # The NixOS plane's file; modules/profiles/base-node.nix sets the same
      # default, and naming it here keeps the secret's home visible at its use.
      sopsFile = ../../modules/secrets.yaml;
    };

    systemd.services.xs-agent-turns = {
      description = "xs event stream store for agent turns (Unix socket only)";
      wantedBy = ["multi-user.target"];
      after = ["sops-install-secrets.service"];
      requires = ["sops-install-secrets.service"];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = cfg.stateDirectory;
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
        ExecStart = "${pkgs.python3}/bin/python3 ${./agent-turns/shim.py}";
        Environment = [
          "XS_SOCKET=${socketPath}"
          "AGENT_TURNS_TOKEN_FILE=${config.sops.secrets.${cfg.tokenSecret}.path}"
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
  };
}
