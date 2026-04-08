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
    ../../modules/config/authorized-keys.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ../../modules/profiles/steam.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/minimal-desktop.nix
    ../../modules/profiles/laptop.nix
    # Our custom microvm network module
    ../../modules/global/microvm-network.nix
    inputs.microvm.nixosModules.host

    inputs.sops-nix.nixosModules.sops
    ../../modules/services/nullclaw-deployment.nix
    (import ../../modules/profiles/ai-host.nix {})
  ];

  sops.secrets.ai-services-shared-env = {
    owner = "root";
    group = "root";
    mode = "0444";
  };

  profiles.aiHost = {
    enable = true;
    nullclaw.enable = true;
  };

  aiServices.nullclawDeployment = {
    enable = true;
    mode = "env-file";
    listenHost = "127.0.0.1";
    listenPort = 3001;
    workspaceRoot = "/var/lib/nullclaw";
    environmentFile = config.sops.secrets."ai-services-shared-env".path;
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
          go
          htop
          kitty
          opencode
        ];
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
  systemd.user.services.niri-flake-polkit.enable = false;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

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
  system.stateVersion = "25.11";
  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
    cudaSupport = true;
  };
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      # "crush"
    ];
  # nixpkgs.config.allowUnfree = true;
}
