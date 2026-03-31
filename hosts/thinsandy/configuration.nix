{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}: let
  enableHermes = true;
  enableOpenClaw = false;
  enableNullClaw = true;
  enableOpenFang = true;
in {
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/profiles/minimal-desktop.nix
      ../../modules/services/openfang.nix
      ../../modules/services/xs.nix
      ../../modules/services/ai-services-context.nix
      ../../modules/services/hermes-agent-local.nix
      inputs.nix-openclaw.nixosModules.openclaw-gateway
      inputs.sops-nix.nixosModules.sops
      (import ../../modules/profiles/ai-host.nix {
        withOpenclaw = true;
      })
      ./hardware.nix
      ./media-stack.nix
      ./tools.nix
      ./networking.nix
    ]
    ++ lib.optionals enableHermes [
      inputs.hermes-agent.nixosModules.default
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinsandy";
  nixpkgs.overlays =
    []
    ++ lib.optionals enableOpenClaw [
      inputs.nix-openclaw.overlays.default
    ];
  profiles.aiHost = {
    enable = true;
    openclaw.enable = enableOpenClaw;
    nullclaw.enable = enableNullClaw;
  };
  aiServices = {
    # Enable shared context materialization
    context = {
      enable = true;
      serviceNames = ["openclaw" "nullclaw" "hermes" "xs" "openfang"];
    };
    openclawGateway = {
      enable = enableOpenClaw;
      workspaceRoot = "/var/lib/openclaw";
      environmentFile = config.sops.secrets."openclaw".path;
      telegramTokenFile = config.sops.secrets."vanta-telegram".path;
      # Shared context/auth/state mounts
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/openclaw";
    };
    nullclaw = {
      host = "127.0.0.1";
      port = 3001;
      workspaceRoot = "/var/lib/nullclaw";
      environmentFile = config.sops.secrets."nullclaw".path;
      # Shared context/auth/state mounts
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/nullclaw";
    };
    openfang = {
      enable = enableOpenFang;
      package = self.packages.${pkgs.system}.openfang;
      workspaceRoot = "/var/lib/openfang";
      # Experimental: keep startup inert until the operator adds env vars and
      # completes a manual `openfang init` against the service HOME.
      environmentFile = "/var/lib/openfang/.openfang/openfang.env";
      requireEnvironmentFile = true;
      # Shared context/auth/state mounts
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/openfang";
    };
    xs = {
      enable = true;
      package = self.packages.${pkgs.system}.xs;
      workspaceRoot = "/var/lib/xs";
      storePath = "/var/lib/xs/store";
      # Shared context/auth/state mounts
      contextRoot = "/srv/data/ai-services/context";
      sharedDefaultsFile = "/srv/data/ai-services/defaults/shared.env";
      sharedSecretFile = config.sops.secrets."ai-services-shared-env".path or null;
      stateDir = "/srv/data/ai-services/state/xs";
    };
  };
  services.hermes-agent-local = {
    enable = enableHermes;
    stateDir = "/var/lib/hermes";
    settings = {
      model = {
        # provider = "openrouter";
        # default = "qwen/qwen3.6-plus-preview:free";
        provider = "custom";
        default = "qwen/qwen3-coder-480b-a35b-instruct";
      };
      terminal = {
        backend = "local";
        timeout = 180;
      };
      toolsets = ["all"];
    };
    environmentFiles = [config.sops.secrets.hermes.path];
  };

  # Host-level override for Hermes to mount shared context/state
  # (upstream module does not support this natively)
  systemd.services.hermes-agent.serviceConfig =
    {
      BindReadOnlyPaths = [
        "/srv/data/ai-services/context:/var/lib/hermes/.ai-services/context"
        "-/srv/data/ai-services/defaults/shared.env:/var/lib/hermes/.ai-services/defaults/shared.env"
      ];
      BindPaths = [
        "/srv/data/ai-services/state/hermes:/var/lib/hermes/.ai-services/state"
      ];
      EnvironmentFile = [
        "-/srv/data/ai-services/defaults/shared.env"
      ] ++ config.services.hermes-agent.environmentFiles;
    };
  sops.secrets = lib.mkMerge [
    (lib.mkIf enableNullClaw {
      nullclaw = {
        owner = "nullclaw";
        group = "nullclaw";
        mode = "0400";
      };
    })
    (lib.mkIf enableHermes {
      hermes = {
        owner = "hermes";
        group = "hermes";
        mode = "0400";
      };
    })
    {
      # Shared secrets for all AI services (model API keys, etc.)
      ai-services-shared-env = {
        owner = "root";
        group = "root";
        mode = "0444";
      };
    }
  ];

  fileSystems = {
    "/var/lib/openclaw/.openclaw/workspace/share" = {
      device = "/srv/data/openclaw";
      options = ["bind"];
    };
    "/var/lib/openfang/.openfang/skills" = {
      device = "/srv/data/openclaw/skills";
      options = ["bind"];
    };
    "/var/lib/nullclaw/workspace/share" = {
      device = "/srv/data/openclaw";
      options = ["bind"];
    };
    "/var/lib/hermes/workspace/share" = {
      device = "/srv/data/openclaw";
      options = ["bind"];
    };
  };
  system.stateVersion = "25.05";
}
