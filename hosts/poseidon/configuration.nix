{
  inputs,
  self,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ../common/steam.nix
    ../common/base-desktop-environment.nix
    ../common/minimal-desktop.nix
    ../common/laptop.nix
    # Our custom microvm network module
    ../../modules/global/microvm-network.nix
    inputs.microvm.nixosModules.host
  ];

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
          go
          htop
          ollama
          opencode
        ];

        system.stateVersion = "25.05";
      };
    };
  };
  boot = {
    #extraModulePackages = with config.boot.kernelPackages; [v4l2loopback.out];
    # kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;
    kernelPackages = lib.mkForce pkgs.linuxPackages_zen;
    kernelModules = [
      # "libwacom"
      #  "v4l2loopback"
    ];
    #extraModprobeConfig = ''
    #  options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    #'';
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
  networking.hostName = "poseidon";

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

  # NAT for VM network - use wlp4s0 (WiFi) as external interface
  networking.nat = {
    enable = true;
    internalInterfaces = ["microbr"];
    externalInterface = "wlp4s0";
  };
  networking.firewall.trustedInterfaces = ["microbr"];

  environment = {
    systemPackages = with pkgs; [
      btrfs-progs
      (pkgs.wrapOBS {
        plugins = with pkgs.obs-studio-plugins; [
          wlrobs
          obs-backgroundremoval
          obs-pipewire-audio-capture
        ];
      })
      sunshine
      moonlight-qt
    ];
  };
  # services.transfer-sh = {

  users.groups.libvirtd.members = ["devji"];

  virtualisation.libvirtd.enable = true;

  virtualisation.spiceUSBRedirection.enable = true;
  # programs.adb.enable = true;
  users.users.devji.extraGroups = ["adbusers" "kvm" "libvirtd"];
  services.udev.packages = [
    # pkgs.android-udev-rules
  ];
  #  dconf.settings = {
  #    "org/virt-manager/virt-manager/connections" = {
  #      autoconnect = ["qemu:///system"];
  #      uris = ["qemu:///system"];
  #    };
  #  };

  #  users.users.devji.extraGroups = ["libvirtd"];
  # services.qemuGuest.enable = true;
  # services.spice-vdagentd.enable = true; # enable copy and paste between host and guest

  # SUNSHINE:

  # services.sunshine = {
  #   enable = true;
  #   autoStart = true;
  #   capSysAdmin = true;
  #   openFirewall = true;
  # };
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [47984 47989 47990 48010];
    allowedUDPPortRanges = [
      {
        from = 47998;
        to = 48000;
      }
      {
        from = 8000;
        to = 8010;
      }
    ];
  };
}
// {
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      # "crush"
    ];
  # nixpkgs.config.allowUnfree = true;
}
