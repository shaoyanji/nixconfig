{config, pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
    (import ./disko.nix {device = "/dev/mmcblk0";})
  ];

  boot.supportedFilesystems = ["f2fs" "nfs"];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  # Use stable LTS kernel — latest is too large for 24GB eMMC
  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.vfs_cache_pressure" = 150;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };
  boot.consoleLogLevel = 3;

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    options = "--delete-older-than-30d";
  };

  services.journald.extraConfig = "SystemMaxUse=50M";

  zramSwap = {
    enable = true;
    memoryPercent = 100;
    algorithm = "lz4";
  };

  fileSystems."/Volumes/data" = {
    device = "192.168.3.25:/data";
    fsType = "nfs";
    options = ["noatime" "nfsvers=4" "rw" "x-systemd.automount" "x-systemd.idle-timeout=600"];
  };

  networking.firewall.allowedTCPPorts = [2049];
  networking.hostName = "netbook";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Berlin";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  users.users.alice = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    packages = with pkgs; [tree];
  };

  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${config.programs.niri.package}/bin/niri-session";
        user = "alice";
      };
    };
  };

  systemd.user.services.niri.enableDefaultPath = false;
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.swaylock = {};

  environment.systemPackages = with pkgs; [
    git curl wget helix
    alacritty fuzzel swaybg
    tmux btop fastfetch
    grim wl-clipboard
    mpv rsync
    # lightweight browser alternative — firefox is too large for 24GB eMMC
    # librewolf
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  services.openssh.enable = true;
  system.stateVersion = "26.05";
}
