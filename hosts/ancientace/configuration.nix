{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../modules/config/authorized-keys.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
    ../../modules/global/microvm-network.nix
    inputs.microvm.nixosModules.host
    (import ../../modules/profiles/microvm-host.nix {
      inherit pkgs;
      natExternalInterface = "wlp3s0";
    })
    (import ../../modules/profiles/grub-boot.nix {inherit lib; device = "nodev";})
  ];

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    openFirewall = true;
    environmentVariables = {
      OLLAMA_ORIGINS = "moz-extension://*,chrome-extension://*,safari-web-extension://*";
    };
  };

  # microvm-host.nix provides microvm.network, bridge profile, NAT, and firewall.
  microvm.vms = {
    testvm = {
      config = {
        imports = [
          inputs.microvm.nixosModules.microvm
          (import ../microvms/testvm.nix {
            workspaceSource = "/home/devji/workspace";
            agentsSource = "/home/devji/.agents";
            configureNetworkd = true;
            useDevNixDefaults = true;
            authorizedKeys = config.ssh.authorizedKeys.keys;
          })
        ];
        microvm.hypervisor = "cloud-hypervisor";
        microvm.vsock.cid = 10;

        environment.systemPackages = with pkgs; [
          gcc
          kitty
          jq
          htmlq
        ];
      };
    };
  };

  home-manager.users.devji.home.sessionVariables.EDITOR = lib.mkForce "nvim";
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  networking.hostName = "ancientace";

  hardware.graphics.extraPackages = [];
  services = {
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      #    xserver.digimend.enable = true;
    };

    btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = ["/"];
    };
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    f2fs-tools
    #    # config.boot.kernelPackages.digimend
  ];
  services.thermald.enable = true;
  system.stateVersion = "25.11";
}
