{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/base-desktop-environment.nix
    ../common/laptop.nix
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
        ];

        microvm.hypervisor = "cloud-hypervisor";
        microvm.vcpu = 2;
        microvm.mem = 2048;

        microvm.interfaces = [
          {
            type = "tap";
            id = "microvm1";
            mac = "02:00:00:00:00:01";
          }
        ];

        microvm.shares = [
          {
            proto = "virtiofs";
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }

          {
            proto = "virtiofs";
            tag = "workspace";
            source = "/home/devji/workspace";
            mountPoint = "/home/devji/workspace";
          }

          {
            proto = "virtiofs";
            tag = "agents";
            source = "/home/devji/.agents";
            mountPoint = "/home/devji/.agents";
          }
        ];

        microvm.volumes = [
          {
            mountPoint = "/var";
            image = "var.img";
            size = 4096;
          }
        ];

        # Enable writable nix store overlay so nix-daemon works
        # Uses tmpfs by default (ephemeral), which is fine since we
        # don't build anything in the VM
        microvm.writableStoreOverlay = "/nix/.rw-store";

        # Fix for microvm shutdown hang (issue #170)
        # Without this, systemd tries to unmount /nix/store during shutdown,
        # but umount lives in /nix/store, causing a deadlock
        systemd.mounts = [
          {
            what = "store";
            where = "/nix/store";
            overrideStrategy = "asDropin";
            unitConfig.DefaultDependencies = false;
          }
        ];

        networking.hostName = "testvm";
        networking.firewall.enable = false;

        # Use static IP with systemd-networkd
        networking.useNetworkd = true;
        networking.useDHCP = false;
        networking.tempAddresses = "disabled";
        systemd.network.enable = true;
        systemd.network.networks."10-e" = {
          matchConfig.Name = "e*";
          addresses = [{Address = "192.168.83.10/24";}];
          routes = [{Gateway = "192.168.83.1";}];
        };
        networking.nameservers = ["8.8.8.8" "1.1.1.1"];

        nix = {
          settings = {
            substituters = ["https://cache.nixos.org" "https://nix-community.cachix.org"];
            trusted-public-keys = ["cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
            extra-experimental-features = ["flakes" "nix-command" "pipe-operators"];
          };
        };

        # Override NIX_PATH to use flake
        environment.sessionVariables = lib.mkForce {
          NIX_PATH = "nixpkgs=flake:nixpkgs";
        };

        services.resolved.enable = true;

        services.openssh = {
          enable = true;
          settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = false;
          };
        };
        # programs.nix-ld.enable = true;
        users.users.devji = {
          isNormalUser = true;
          extraGroups = ["wheel" "networkmanager"];
          openssh.authorizedKeys.keys =
            builtins.filter
            (x: x != [])
            (builtins.split "\n"
              (builtins.readFile
                (builtins.fetchurl {
                  url = "https://gist.githubusercontent.com/shaoyanji/8e051ec6548dcf8cebf1cd3e4e668f7d/raw/authorized_keys";
                  sha256 = "sha256:0in2frxx6fs1ddjw5xfacqyp7k445a4idlbq6kqkmrjphvjk3vmx";
                })));
        };

        environment.systemPackages = with pkgs; [
          git
          curl
          wget
          gcc
          kitty
          jq
          htmlq
        ];

        system.stateVersion = "25.05";
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
      #     sddm = {
      #      enable = true;
      #     wayland.enable = true;
      #  };
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
}
