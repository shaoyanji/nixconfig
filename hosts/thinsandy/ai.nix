{ config
, pkgs
, self
, lib
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.ai.thinsandy;
in
{
  options.ai.thinsandy = {
    hermes.enable = mkEnableOption "Hermes agent (default: false)";
    nullclaw.enable = mkEnableOption "NullClaw agent (default: false)";
    zeroclaw.enable = mkEnableOption "ZeroClaw agent (default: true)";
    xs.enable = mkEnableOption "XS event streaming (default: false)";
    pancakesHarness.enable = mkEnableOption "Pancakes harness (default: false)";
    researchTools.enable = mkEnableOption "Heavy research Python env - neo4j, firecrawl (default: false)";
  };

  imports = [
    ../../modules/services/ai-services-secrets.nix
    ../../modules/services/ai-services-shared-mounts.nix
    ../../modules/services/ai-services-context.nix
    ../../modules/profiles/ollama-cloud-defaults.nix
    ../../modules/services/zeroclaw-deployment.nix
    ../../modules/profiles/ai-host.nix
    ../../modules/services/xs.nix
    ../../modules/services/pancakes-harness.nix
  ];

  config = {
    profiles.aiHost = {
      enable = true;
      nullclaw.enable = cfg.nullclaw.enable;
      zeroclaw.enable = cfg.zeroclaw.enable;
    };

    aiServices.sharedSecrets.enable = true;
    aiServices.sharedMounts = {
      enable = true;
      source = "/srv/data/openclaw";
      services.nullclaw = cfg.nullclaw.enable;
      services.hermes = cfg.hermes.enable;
    };

    aiServices = {
      context.enable = true;
      nullclaw = mkIf cfg.nullclaw.enable {
        enable = true;
        host = "127.0.0.1";
        port = 3001;
        environmentFile = config.sops.secrets."nullclaw".path;
      };
      xs = mkIf cfg.xs.enable {
        enable = true;
        package = self.packages.${pkgs.system}.xs;
        storePath = "/var/lib/xs/store";
      };
      pancakesHarness = mkIf cfg.pancakesHarness.enable {
        enable = true;
        package = self.packages.${pkgs.system}.pancakes-harness;
        backendMode = "xs";
        xsTopicPrefix = "pancakes-harness";
        bind = "127.0.0.1";
        port = 8080;
        modelMode = "mock";
      };
    };

    # --- ZeroClaw ---
    aiServices.zeroclawDeployment = mkIf cfg.zeroclaw.enable {
      enable = true;
      instanceName = "athena";
      listenHost = "127.0.0.1";
      listenPort = 42617;
      workspaceRoot = "/var/lib/zeroclaw-athena";
      environmentFile = config.sops.secrets."ai-services-shared-env".path;
      extraEnvironmentFiles = [
        config.sops.templates."zeroclaw-athena-env".path
      ];
      extraSystemPackages = with pkgs; [
        curl
        git
        jq
        skills
      ];
      protectHome = "read-only";
      bindReadOnlyPaths = {
        "/var/lib/zeroclaw-athena/workspace/share" = "/srv/data/openclaw";
      };
      settings = {
        channels.telegram = {
          enabled = true;
          bot_token = "$TELEGRAM_BOT_TOKEN";
          allowed_users = [
            "8522510655"
            "8207284912"
          ];
        };
      };
    };

    sops.secrets.athena-telegram = mkIf cfg.zeroclaw.enable {
      owner = "zeroclaw-athena";
      group = "zeroclaw-athena";
      mode = "0400";
    };

    sops.templates."zeroclaw-athena-env" = mkIf cfg.zeroclaw.enable {
      content = ''
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder."athena-telegram"}
      '';
    };

    services.ollama = {
      enable = true;
      home = "/srv/data/ollama";
      user = "ollama";
      group = "ollama";
    };

    systemd.services.ollama.unitConfig = {
      RequiresMountsFor = "/srv/data/ollama";
      After = [ "srv-data.mount" "systemd-tmpfiles-setup.service" ];
    };

    systemd.tmpfiles.rules = [
      "d /srv/data/ollama 0755 ollama ollama -"
    ];

    environment.systemPackages = lib.optionals cfg.researchTools.enable [
      (pkgs.python3.withPackages (ps: with ps; [
        neo4j
        pytz
        firecrawl-py
        pydantic
      ]))
    ];
  };
}
