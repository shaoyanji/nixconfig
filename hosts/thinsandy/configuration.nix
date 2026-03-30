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
    openclawGateway = {
      enable = enableOpenClaw;
      workspaceRoot = "/var/lib/openclaw";
      environmentFile = config.sops.secrets."openclaw".path;
      telegramTokenFile = config.sops.secrets."vanta-telegram".path;
    };
    nullclaw = {
      host = "127.0.0.1";
      port = 3001;
      workspaceRoot = "/var/lib/nullclaw";
      environmentFile = config.sops.secrets."nullclaw".path;
    };
    openfang = {
      enable = enableOpenFang;
      package = self.packages.${pkgs.system}.openfang;
      workspaceRoot = "/var/lib/openfang";
      # Experimental: keep startup inert until the operator adds env vars and
      # completes a manual `openfang init` against the service HOME.
      environmentFile = "/var/lib/openfang/.openfang/openfang.env";
      requireEnvironmentFile = true;
    };
    xs = {
      enable = true;
      package = self.packages.${pkgs.system}.xs;
      workspaceRoot = "/var/lib/xs";
      storePath = "/var/lib/xs/store";
    };
  };
  services.hermes-agent = {
    enable = enableHermes;
    package = inputs.hermes-agent.packages.${pkgs.system}.default.overrideAttrs (old: {
      version = "0.6.0";
    });
    stateDir = "/var/lib/hermes";
    settings = {
      model = {
        provider = "openrouter";
        default = "nvidia/nemotron-3-super-120b-a12b:free";
      };
      terminal = {
        backend = "local";
        timeout = 180;
      };
      toolsets = ["all"];
    };
    environmentFiles = [config.sops.secrets.hermes.path];
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
  ];

  fileSystems = {
    "/var/lib/openclaw/.openclaw/workspace/share" = {
      device = "/srv/data/openclaw";
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
