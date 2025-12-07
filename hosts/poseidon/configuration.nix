{
  inputs,
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
  ];
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;
  boot = {
    #extraModulePackages = with config.boot.kernelPackages; [v4l2loopback.out];
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
  networking.hostName = "poseidon"; # Define your hostname.
  environment = {
    systemPackages = with pkgs; [
      # inputs.nur.legacyPackages."${system}".repos.charmbracelet.crush
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
    #variables = {
    # };
  };
  # services.transfer-sh = {
  #   enable = true;
  #   provider = "local";
  #   settings = {
  #     BASEDIR = "/var/lib/transfer.sh";
  #     LISTENER = ":8080";
  #     TLS_LISTENER_ONLY = false;
  #   };
  # };
  programs.virt-manager.enable = true;

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
