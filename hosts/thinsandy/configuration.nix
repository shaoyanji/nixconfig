{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/minimal-desktop.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Use the GRUB 2 boot loader.
  #boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  #boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking.hostName = "thinsandy"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # 1. enable vaapi on OS-level
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "intel-ocl"
    ];
  nixpkgs.config.packageOverrides = pkgs: {
    # Only set this if using intel-vaapi-driver
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override {enableHybridCodec = true;};
  };
  users.users.immich.extraGroups = ["video" "render"];
  services = {
    immich = {
      enable = true;
      port = 2283;
      accelerationDevices = null;
    };
    sonarr = {
      enable = true;
      openFirewall = true;
    };

    readarr = {
      enable = true;
      openFirewall = true;
    };
    transmission = {
      enable = true; #Enable transmission daemon

      package = pkgs.transmission_4;
      openRPCPort = true; #Open firewall for RPC
      settings = {
        #Override default settings
        rpc-bind-address = "0.0.0.0"; #Bind to own IP
        rpc-whitelist = "127.0.0.1,100.66.146.18,100.80.205.35,100.107.85.117,100.76.219.97,100.80.247.12,100.89.170.84,100.120.134.106";
        download-dir = "/Volumes/data/arr";
        # download-dir = "${config.services.transmission.home}/Downloads";
      };
    };
    lidarr = {
      enable = true;
      openFirewall = true;
    };

    prowlarr = {
      enable = true;
      openFirewall = true;
    };

    radarr = {
      enable = true;
      openFirewall = true;
    };
  };
  systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD"; # Or "i965" if using older driver
  environment.sessionVariables = {LIBVA_DRIVER_NAME = "iHD";}; # Same here
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # For Broadwell (2014) or newer processors. LIBVA_DRIVER_NAME=iHD
      # intel-vaapi-driver # For older processors. LIBVA_DRIVER_NAME=i965
      libva-vdpau-driver # Previously vaapiVdpau
      # intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      # OpenCL support for intel CPUs before 12th gen
      # see: https://github.com/NixOS/nixpkgs/issues/356535
      intel-compute-runtime-legacy1
      vpl-gpu-rt # QSV on 11th gen or newer
      # intel-media-sdk # QSV up to 11th gen #security
      intel-ocl # OpenCL support
    ];
  };
  # 2. do not forget to enable jellyfin
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };
  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    go
    btrfs-progs
    f2fs-tools
    docker
    ethtool
    networkd-dispatcher
    powertop
  ];

  powerManagement.powertop.enable = true;
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
    daemon.settings = {
      # data-root = "/some-place/to-store-the-docker-data";
    };
  };
  #  services.k3s = {
  #    enable = true;
  #    role = "server";
  #    tokenFile = "${config.sops.secrets."local/k3s/token".path}";
  #    clusterInit = true;
  #  };
  #  networking.firewall.allowedTCPPorts = [
  #    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
  #    #    2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
  #    #    2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  #  ];

  #  networking.firewall.allowedUDPPorts = [
  #    8472 # k3s, flannel: required if using multi-node for inter-node networking
  #  ];
  system.stateVersion = "25.05"; # Did you read the comment?
}
