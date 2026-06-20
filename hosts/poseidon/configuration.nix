{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;
  obsConfig = {
    enable = false;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
    ];
  };
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ../../modules/profiles/steam.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
    inputs.microvm.nixosModules.host

    ../../modules/services/ai-services-secrets.nix
    ../../modules/services/zeroclaw-deployment.nix
    ../../modules/profiles/ai-host.nix
    (import ../../modules/profiles/microvm-host.nix {
      inherit pkgs;
      natExternalInterface = "wlp4s0";
    })
  ];

  aiServices.sharedSecrets.enable = true;

  profiles.aiHost = {
    enable = true;
    nullclaw.enable = false;
    zeroclaw.enable = true;
  };

  aiServices.zeroclawDeployment = {
    enable = true;
    listenHost = "127.0.0.1";
    listenPort = 42617;
    workspaceRoot = "/var/lib/zeroclaw";
    environmentFile = config.sops.secrets."ai-services-shared-env".path;
    extraEnvironmentFiles = [
      config.sops.templates."zeroclaw-zeroclaw-env".path
    ];
    extraSystemPackages = with pkgs; [
      curl
      git
      jq
      skills
      worktrunk
    ];
    protectHome = "read-only";
    # Mount shared NAS data into workspace (only on non-NAS hosts)
    bindReadOnlyPaths = {
      "${config.aiServices.zeroclawDeployment.workspaceRoot}/workspace/share" = "/Volumes/data/openclaw";
    };
    settings = {
      channels.telegram = {
        enabled = true;
        bot_token = "$TELEGRAM_BOT_TOKEN";
        allowed_users = ["8207284912"];
      };
    };
  };

  sops.secrets.poseidon-telegram = {
    owner = "zeroclaw-zeroclaw";
    group = "zeroclaw-zeroclaw";
    mode = "0400";
  };

  sops.templates."zeroclaw-zeroclaw-env" = {
    content = ''
      TELEGRAM_BOT_TOKEN=${config.sops.placeholder."poseidon-telegram"}
    '';
  };

  # Use microbr bridge for VMs (configured by microvm-host.nix)
  microvm.vms = {
    testvm = {
      config = {
        imports = [
          inputs.microvm.nixosModules.microvm
          (import ../microvms/testvm.nix {
            workspaceSource = "${user.home}/workspace";
            agentsSource = "${user.home}/.agents";
            configureNetworkd = true;
            useDevNixDefaults = true;
            authorizedKeys = config.ssh.authorizedKeys.keys;
          })
        ];
        microvm.hypervisor = "cloud-hypervisor";
        microvm.vsock.cid = 10;

        environment.systemPackages = with pkgs; [
          curl
          git
          jq
          yq-go
          go
          skills
          worktrunk
        ];
      };
    };
  };
  boot = {
    kernelPackages = lib.mkForce pkgs.linuxPackages;
    kernelModules = [];
  };
  networking.hostName = "poseidon";

  environment = {
    systemPackages = with pkgs;
      [
        btrfs-progs
      ]
      ++ lib.optionals obsConfig.enable [
        (pkgs.wrapOBS {inherit (obsConfig) plugins;})
      ];
  };

  # users.groups.libvirtd.members = [ "devji" ];
  # virtualisation.libvirtd.enable = true;
  # virtualisation.spiceUSBRedirection.enable = true;
  # users.users.devji.extraGroups = [ "adbusers" "kvm" "libvirtd" ];
  services.udev.packages = [];

  # services.avahi.publish.enable = true;
  # services.avahi.publish.userServices = true;

  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home; # Sync themes with user's DankMaterialShell config
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

  system.stateVersion = "25.11";
  nixpkgs.config.nvidia.acceptLicense = true;
}
