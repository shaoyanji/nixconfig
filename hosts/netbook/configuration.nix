# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the GRUB 2 boot loader.
  # boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.supportedFilesystems = [ "f2fs" "nfs" ];
  hardware.enableRedistributableFirmware = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.tmp.cleanOnBoot = true;
  services.fstrim.enable = true;
  fileSystems = {
    "/Volumes/data" = {
      device = "192.168.3.25:/data";
      fsType = "nfs";
      options = [ "noatime" "nfsvers=4" "rw" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 2049 ];
  services.tailscale.enable = true;

  boot.kernelParams = [
    # "fsck.mode=skip"
    # "nomodeset"
    # "console=tty1"
    # "quiet" "loglevel=3"
  ];
  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.vfs_cache_pressure" = 150;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };
  boot.consoleLogLevel = 3;
  nix.optimise.automatic = true;
  # nix.optimise.interval = "weekly";
  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    options = "--delete-older-than-30d";
  };
  nix.settings = {
    auto-optimise-store = true;
  };
  services.journald.extraConfig = "SystemMaxUse=50M";
  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  zramSwap = {
    priority = 100;
    enable = true;
    memoryPercent = 100;
    algorithm = "lz4";
  };
  powerManagement.enable = true;
  services.tlp.enable = true;
  services.thermald.enable = true;
  services.earlyoom.enable = true;
  services.upower.enable = true;
  services.libinput.enable = true;
  networking.hostName = "netbook"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";
  # users.users.root.initialPassword = "nixos";
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;




  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.alice = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnNR7isgO8VDY76XzwyH3mOg1/DQo8dZgqQOfziw0DQ devji@nixos"
    ];
    packages = with pkgs; [
      tree
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # programs.firefox.enable = true;

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
  security.polkit.enable = true; # polkit
  services.gnome.gnome-keyring.enable = true; # secret service
  security.pam.services.swaylock = { };

  # programs.waybar.enable = true; # top bar
  # services.displayManager.sddm.enable = true;
  # services.displayManager.sddm.wayland.enable = true;
  # services.displayManager.autoLogin = {
  # enable=true;
  # user="alice";

  # };
  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    git
    curl
    helix
    wget
    uv
    eget
    waybar
    playerctl
    brightnessctl
    pavucontrol
    swaylock
    polkit_gnome
    bibata-cursors
    # quickshell
    alacritty
    fuzzel
    mako
    swayidle
    swaybg
    nautilus
    # crush
    nixd
    nixfmt
    btop
    fastfetch
    # librewolf
    firefox
    tmux
    lowfi
    grim
    wl-clipboard
    imv
    # mpv
    # nushell
    rsync
    mupdf
    # freetube
    # yt-dlp
    # yewtube
    fzf
    jq
    gum
    ripgrep
    fd
    bat
    eza
    zoxide
    duf
    tldr
    unzip
    zip
    file
    # youtubeSupport=false keeps mpv's wrapper from pinning the stale
    # nixpkgs yt-dlp into its PATH; the current yt-dlp comes from
    # /home/alice/.local/bin/yt-dlp (standalone binary, self-updates with
    # `yt-dlp --update`).
    (mpv.override { youtubeSupport = false; })
    aria2
    # ani-cli prefers curl-impersonate (hianime sits behind Cloudflare)
    curl-impersonate
    # VAAPI diagnostics (vainfo)
    libva-utils
    xwayland-satellite # xwayland support
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };

  # Fonts for the desktop (bar icons, emoji).
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
  ];

  # Bluetooth radio is present (hci0); enable the stack.
  hardware.bluetooth.enable = true;

  # VAAPI driver for the Gen8 iGPU (N3060): H.264 hardware decode for mpv.
  hardware.graphics.extraPackages = [ pkgs.intel-vaapi-driver ];

  # Run prebuilt, non-Nix dynamically linked binaries (tools dropped in
  # ~/.local/bin, pip/venv wheels with C extensions, downloaded release
  # tarballs) through nix-ld's loader. Extra libs can be added via
  # programs.nix-ld.libraries if something complains about a missing .so.
  programs.nix-ld.enable = true;

  # Keep ~/.local/bin on PATH for the session and login shells.
  environment.localBinInPath = true;


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      TrustedUserCAKeys = "${pkgs.writeText "trusted-user-ca" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhAN2tuJ4f8kCbCWehJL+fp5VYrTUQpn2ZWK9RC7XM1 SSH User CA @ aristotle 20260706\n"}";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}

