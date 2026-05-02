{
  inputs,
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  obsConfig = {
    enable = false;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
    ];
  };
in
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
    ../../modules/services/ai-services-secrets.nix
    ../../modules/services/nullclaw-deployment.nix
    ../../modules/profiles/ai-host.nix
    (import ../../modules/profiles/microvm-host.nix {
      inherit pkgs;
      natExternalInterface = "wlp4s0";
    })
  ];

  aiServices.sharedSecrets.enable = true;

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

  # Use microbr bridge for VMs (configured by microvm-host.nix)
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
    kernelPackages = lib.mkForce pkgs.linuxPackages_zen;
    kernelModules = [];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
  networking.hostName = "poseidon";

  environment = {
    systemPackages = with pkgs; [
      btrfs-progs
    ]
    ++ lib.optionals obsConfig.enable [
      (pkgs.wrapOBS { plugins = obsConfig.plugins; })
    ]
    ++ [
      # sunshine       # Disabled until sunshine setup is restored
      # moonlight-qt
    ];
  };

  # users.groups.libvirtd.members = [ "devji" ];
  # virtualisation.libvirtd.enable = true;
  # virtualisation.spiceUSBRedirection.enable = true;
  # users.users.devji.extraGroups = [ "adbusers" "kvm" "libvirtd" ];
  services.udev.packages = [];

  # services.avahi.publish.enable = true;
  # services.avahi.publish.userServices = true;
  systemd.user.services.niri-flake-polkit.enable = false;

  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/devji"; # Sync themes with user's DankMaterialShell config
  };

  networking.firewall = {
    enable = true;
    # Sunshine ports — re-enable when sunshine is active
    # allowedTCPPorts = [ 47984 47989 47990 48010 ];
    # allowedUDPPortRanges = [
    #   { from = 47998; to = 48000; }
    #   { from = 8000; to = 8010; }
    # ];
  };
}
// {
  system.stateVersion = "25.11";
  nixpkgs.config = {
    nvidia.acceptLicense = true;
    cudaSupport = true;
  };
}
