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
  ];

  services.ollama = {
    enable = true;
    # acceleration = "cuda";
    host = "0.0.0.0";
    openFirewall = true;
    environmentVariables = {
      OLLAMA_ORIGINS = "moz-extension://*,chrome-extension://*,safari-web-extension://*";
    };
    # models = "/Volumes/data/ollama";
  };
  # Use microbr bridge for VMs
  microvm.network = {
    enable = true;
    bridgeName = "microbr";
    externalInterface = "eno1";
  };
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

  # NetworkManager bridge configuration using NixOS options
  networking.networkmanager.ensureProfiles.profiles = {
    "microbr" = {
      connection = {
        id = "microbr";
        type = "bridge";
        interface-name = "microbr";
        autoconnect = true;
      };
      bridge = {
        stp = false;
        forward-delay = 0;
      };
      ipv4 = {
        method = "manual";
        address1 = "192.168.83.1/24";
      };
      ipv6 = {
        method = "disabled";
      };
    };
  };

  # Auto-add microvm* interfaces to microbr bridge
  environment.etc."NetworkManager/dispatcher.d/10-microvm-bridge".text = ''
    #!/usr/bin/env bash
    INTERFACE="$1"
    ACTION="$2"
    if [[ "$ACTION" == "up" ]] && [[ "$INTERFACE" == microvm* ]]; then
      sleep 1
      if ! ${pkgs.iproute2}/bin/ip link show "$INTERFACE" | grep -q "master microbr"; then
         ${pkgs.iproute2}/bin/ip link set "$INTERFACE" master microbr
      fi
    fi
  '';
  environment.etc."NetworkManager/dispatcher.d/10-microvm-bridge".mode = "0755";

  # NAT for VM network - use wlp3s0 (WiFi) as external interface
  networking.nat = {
    enable = true;
    internalInterfaces = ["microbr"];
    externalInterface = "wlp3s0";
  };
  networking.firewall.trustedInterfaces = ["microbr"];
  # end of microvm config

  home-manager.users.devji.home.sessionVariables.EDITOR = lib.mkForce "nvim";
  boot = {
    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
  };
  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    grub = {
      device = "nodev";
      #      enableCryptodisk = true;
      #      useOSProber = true;
      enable = true;
    };
  };
  networking.hostName = "ancientace"; # Define your hostname.
  #services.xserver.videoDrivers = ["amdgpu"];

  hardware.graphics.extraPackages = [
    #    pkgs.mesa.opencl
  ];
  #  system.stateVersion = "24.11"; # Did you read the comment?
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
