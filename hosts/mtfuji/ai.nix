{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}: let
  enableNullClaw = true;
  enableOpenClaw = false;
  enableHermes = false;
  enableOpenFang = false;
  enableXS = false;
  enablePancakesHarness = false;
in {
  imports = [
    ../../modules/services/hermes-ai-mounts.nix
    ../../modules/services/ai-services-secrets.nix
    ../../modules/services/ai-services-shared-mounts.nix
    ../../modules/services/nullclaw-deployment.nix
    ../../modules/services/xs.nix
    ../../modules/services/openfang.nix
    ../../modules/services/pancakes-harness.nix
    ../../modules/services/ai-services-context.nix
    inputs.nix-openclaw.nixosModules.openclaw-gateway
    inputs.hermes-agent.nixosModules.default
    ../../modules/profiles/hermes-defaults.nix
    ../../modules/profiles/ollama-cloud-defaults.nix
    (import ../../modules/profiles/ai-host.nix {
      withOpenclaw = true;
    })
  ];

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

  aiServices.hermesMounts.enable = enableHermes;
  aiServices.sharedSecrets.enable = true;
  aiServices.sharedMounts = {
    enable = true;
    source = "/Volumes/data/openclaw";
    services.nullclaw = enableNullClaw;
    services.hermes = enableHermes;
  };

  # --- AI Services Configuration ---
  aiServices = {
    context.enable = true;
    nullclawDeployment = {
      enable = true;
      mode = "env-file";
      listenHost = "127.0.0.1";
      listenPort = 3001;
      workspaceRoot = "/var/lib/nullclaw";
      environmentFile = config.sops.secrets."nullclaw".path;
    };
    openfang = {
      enable = enableOpenFang;
      package = self.packages.${pkgs.system}.openfang;
      environmentFile = "/var/lib/openfang/.openfang/openfang.env";
      requireEnvironmentFile = true;
    };
    xs = {
      enable = enableXS;
      package = self.packages.${pkgs.system}.xs;
      storePath = "/var/lib/xs/store";
    };
    pancakesHarness = {
      enable = enablePancakesHarness;
      package = self.packages.${pkgs.system}.pancakes-harness;
      backendMode = "xs";
      xsTopicPrefix = "pancakes-harness";
      bind = "127.0.0.1";
      port = 8080;
      modelMode = "mock";
    };
  };

  # --- Hermes Agent ---
  services.hermes-agent = lib.mkIf enableHermes {
    enable = true;
    environmentFiles = [
      config.sops.secrets."ai-services-shared-env".path
    ];
  };

  # --- AI Services Filesystem Mounts (host-specific only) ---
  fileSystems = {
    "/var/lib/nullclaw" = {
      device = "/dev/disk/by-uuid/3829936d-db07-4b77-b89a-46a2476578ce";
      fsType = "btrfs";
      options = ["subvol=nix/nullclaw" "compress=zstd" "noatime"];
    };
    "/var/lib/ollama" = {
      device = "/dev/disk/by-uuid/3829936d-db07-4b77-b89a-46a2476578ce";
      fsType = "btrfs";
      options = ["subvol=nix/ollama" "compress=zstd" "noatime"];
    };
    "/var/lib/hermes" = {
      device = "/dev/disk/by-uuid/3829936d-db07-4b77-b89a-46a2476578ce";
      fsType = "btrfs";
      options = ["subvol=nix/hermes" "compress=zstd" "noatime"];
    };
  };

  services.ollama.enable = true;

  environment.systemPackages = with pkgs; [
    skills
    go-task
  ];
}
