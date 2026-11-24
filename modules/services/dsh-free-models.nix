# The free-model relay as a durable unit: dsh's cordis profile composes its
# web app with the dsh-our-free-model plugin, which fronts free upstream lanes
# (DeepSeek V4.1 Flash, Kimi K3, the our-free-model roster) behind an
# OpenAI-compatible gateway. On clanker this was proven in a tmux that dies
# with the box's ~30-minute auto-suspend; on delphi it is a unit, a tailnet
# mount and a sentinel watch instead.
#
# Serves two loopback origins: the dashboard on `webPort` and the gateway on
# `gatewayPort` (8326 is dsh's own default for the openai-gateway component —
# the option exists so a tailnet mount pins it in one place). The gateway
# mints its API key on first run under ~/.dsh/openai-gateway/api-key.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.dshFreeModels;
  home = "/home/${cfg.user}";
in {
  options.services.dshFreeModels = {
    enable = lib.mkEnableOption "the dsh free-model gateway (OpenAI-compatible relay + dashboard)";

    user = lib.mkOption {
      type = lib.types.str;
      description = "Unix user the service runs as (owns its `.dsh` home and working directory).";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 18900;
      description = "Loopback port the dashboard binds; the tailnet mount proxies to it.";
    };

    gatewayPort = lib.mkOption {
      type = lib.types.port;
      default = 8326;
      description = ''
        Port the OpenAI-compatible gateway binds, dsh's own default. Not a dsh
        flag — the gateway picks it; the option exists so mounts, firewall and
        notes agree on the number.
      '';
    };

    profile = lib.mkOption {
      type = lib.types.str;
      default = "free";
      description = "dsh profile name; state lives under ~/.dsh/profiles/<profile>.";
    };

    trustedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Authorities (host or host:port) the web fence accepts from the proxy.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llm-agents.dsh;
      description = "dsh build, pinned through the flake's llm-agents overlay.";
    };

    plugin = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fetchFromGitHub {
        owner = "Ebony-Vinyl";
        repo = "dsh-our-free-model";
        rev = "8f3182b78938344436cc50c34dbfe947136cce9f";
        hash = "sha256-C3rqzTElBSSSg9jqY5T3SU4AtyvrLukpLEHBSSM0nRA=";
      };
      description = ''
        The our-free-model plugin source. `dsh plugin add` links it into the
        profile (a `link:` dep), so a store path is enough — no npm install is
        vendored or needed.
      '';
    };

    # Mirrors services.dshWeb: the stock bundles resolve paid lanes only when a
    # credential is present; the sops-rendered env file stays optional.
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional EnvironmentFile (rendered from sops) holding model credentials.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    systemd.services.dsh-free-models = {
      unitConfig.X-Fleet-Role = "daemon";
      description = "dsh free-model gateway (OpenAI relay + dashboard)";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];

      # HOME picks the `.dsh` (profiles, gateway key, plugin state). PATH is an
      # explicit override for the same reason as services.dshWeb — and it must
      # also carry pnpm/node, because `dsh plugin` forwards to pnpm and pnpm to
      # node.
      environment = {
        HOME = home;
        PATH = lib.mkForce "${pkgs.pnpm}/bin:${pkgs.nodejs}/bin:/run/current-system/sw/bin:${home}/.nix-profile/bin";
      };

      serviceConfig =
        {
          User = cfg.user;
          WorkingDirectory = home;
          # The supported install: `dsh plugin` is pnpm in the profile dir, and
          # `add <dir>` writes a link: dep — idempotent across restarts.
          ExecStartPre = "${cfg.package}/bin/dsh plugin --profile ${cfg.profile} add ${cfg.plugin}";
          ExecStart = lib.concatStringsSep " " ([
              "${cfg.package}/bin/dsh"
              "--profile"
              cfg.profile
              "--no-open"
              "--host"
              "127.0.0.1"
              "--port"
              (toString cfg.webPort)
            ]
            ++ lib.concatMap (h: ["--trusted-host" h]) cfg.trustedHosts);
          Restart = "always";
          RestartSec = 3;
          # Same budget the retired dsh-web carried: this box is 2 OCPU and the
          # relay shares it with nginx and the sentinel.
          CPUWeight = 200;
          IOWeight = 200;
          MemoryHigh = "1200M";
          MemoryMax = "1500M";
        }
        // lib.optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = cfg.environmentFile;
        };
    };
  };
}
