# The DeepSeek Harness Web UI as a worker service, published under a path
# prefix by whatever reverse proxy fronts this host.
#
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.dshWeb;
  home = "/home/${cfg.user}";
in {
  options.services.dshWeb = {
    enable = lib.mkEnableOption "the DeepSeek Harness Web UI on this host";

    user = lib.mkOption {
      type = lib.types.str;
      description = "Unix user the harness runs as (owns its `.dsh` home and working directory).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3080;
      description = "Loopback port the harness binds; the reverse proxy points at it.";
    };

    path = lib.mkOption {
      type = lib.types.str;
      default = "/deepseek/";
      description = "Public mount prefix, with leading and trailing slash. The proxy strips it.";
    };

    publicUrl = lib.mkOption {
      type = lib.types.str;
      description = ''
        Browser-visible root that reaches this mount, e.g.
        `https://host.example/deepseek/`. Advertised only — trust is
        `trustedHosts`.
      '';
    };

    trustedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Authorities (host or host:port) the /api fence accepts from the proxy.";
    };

    # Pinned through the flake's llm-agents overlay so the worker and every
    # client launcher agree on one build rather than each resolving its own.
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llm-agents.dsh;
    };

    # The DeepSeek account grant is a browser sign-in, not a model credential:
    # a turn on the stock profile resolves to the `deepseek-official` route,
    # which wants `DEEPSEEK_API_KEY` (upstream's own error says so). The host
    # renders that key from sops into this file so the unit never carries it in
    # the store or on a command line.
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional EnvironmentFile (rendered from sops) holding the model credential.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.path && lib.hasSuffix "/" cfg.path;
        message = "services.dshWeb.path must start and end with '/': it is a proxy mount prefix, not a URL path.";
      }
      {
        assertion = lib.hasPrefix "http" cfg.publicUrl && lib.hasSuffix "/" cfg.publicUrl;
        message = "services.dshWeb.publicUrl must be an absolute http(s) root ending in '/'.";
      }
      {
        assertion = cfg.trustedHosts != [];
        message = "services.dshWeb.trustedHosts must name the proxy's authority, or every /api call is fenced as cross-site.";
      }
    ];

    # Readable tokenised URL (journald) for the client launcher and the operator.
    users.users.${cfg.user}.extraGroups = ["systemd-journal"];

    # `dsh` on PATH too: the harness's own shell tooling and an operator's
    # ad-hoc `dsh` session should be the same binary the service runs.
    environment.systemPackages = [cfg.package];

    systemd.services.dsh-web = {
      description = "DeepSeek Harness Web UI (dsh web)";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];

      # HOME decides which `.dsh` (credentials, profiles, storages) is used.
      # PATH is inherited by the agent's bash, and the systemd module already
      # defines a minimal one (coreutils/sed/grep/systemd) for every unit — a
      # plain second definition is a hard conflict at build time, which is why
      # this is an explicit override: the agent needs the system profile (git,
      # ripgrep, the harness's own tooling), not a shell that can only cat.
      environment = {
        HOME = home;
        PATH = lib.mkForce "/run/current-system/sw/bin:${home}/.nix-profile/bin";
      };

      serviceConfig =
        {
          User = cfg.user;
          WorkingDirectory = home;
          ExecStart = lib.concatStringsSep " " ([
              "${cfg.package}/bin/dsh"
              "web"
              "--no-open"
              "--host"
              "127.0.0.1"
              "--port"
              (toString cfg.port)
              "--public-url"
              cfg.publicUrl
            ]
            ++ lib.optional (cfg.trustedHosts != []) "--trusted-host"
            ++ cfg.trustedHosts);
          Restart = "always";
          RestartSec = 3;
        }
        // lib.optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = cfg.environmentFile;
        };
    };
  };
}
