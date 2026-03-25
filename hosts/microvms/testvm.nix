{
  workspaceSource ? "/home/devji/nixconfig/hosts/microvms/testvm",
  agentsSource ? null,
  configureNetworkd ? false,
  useDevNixDefaults ? false,
  authorizedKeys ? [],
}: {
  lib,
  pkgs,
  ...
}: {
  microvm = {
    vcpu = 2;
    mem = 2048;

    interfaces = [
      {
        type = "tap";
        id = "microvm1";
        mac = "02:00:00:00:00:01";
      }
    ];

    shares =
      [
        {
          proto = "virtiofs";
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }
        {
          proto = "virtiofs";
          tag = "workspace";
          source = workspaceSource;
          mountPoint = "/home/devji/workspace";
        }
      ]
      ++ lib.optionals (agentsSource != null) [
        {
          proto = "virtiofs";
          tag = "agents";
          source = agentsSource;
          mountPoint = "/home/devji/.agents";
        }
      ];

    volumes = [
      {
        mountPoint = "/var";
        image = "var.img";
        size = 4096;
      }
    ];
  };

  networking.hostName = "testvm";
  networking.firewall.enable = false;

  services.openssh =
    {
      enable = true;
    }
    // lib.optionalAttrs useDevNixDefaults {
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

  users.users.devji =
    {
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager"];
    }
    // lib.optionalAttrs (authorizedKeys != []) {
      openssh.authorizedKeys.keys = authorizedKeys;
    };

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
  ];

  system.stateVersion = "25.05";
}
// lib.optionalAttrs configureNetworkd {
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.tempAddresses = "disabled";
  networking.nameservers = ["8.8.8.8" "1.1.1.1"];

  systemd.network.enable = true;
  systemd.network.networks."10-e" = {
    matchConfig.Name = "e*";
    addresses = [{Address = "192.168.83.10/24";}];
    routes = [{Gateway = "192.168.83.1";}];
  };
}
// lib.optionalAttrs useDevNixDefaults {
  microvm.writableStoreOverlay = "/nix/.rw-store";

  systemd.mounts = [
    {
      what = "store";
      where = "/nix/store";
      overrideStrategy = "asDropin";
      unitConfig.DefaultDependencies = false;
    }
  ];

  nix.settings = {
    substituters = ["https://cache.nixos.org" "https://nix-community.cachix.org"];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    extra-experimental-features = ["flakes" "nix-command" "pipe-operators"];
  };

  environment.sessionVariables.NIX_PATH = lib.mkForce "nixpkgs=flake:nixpkgs";
  services.resolved.enable = true;
}
