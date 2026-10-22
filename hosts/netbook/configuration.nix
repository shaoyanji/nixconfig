# Alice's travel netbook — fleet nixpkgs, LTS kernel (newer initrds could not
# mount this eMMC root), no global chain, deployed by push. Rationale and the
# boot test: `.agents/deploy/hosts/netbook.md`.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # The fleet's deploy key (frieren's `devji` identity). alice logs in with it,
  # and root accepts the same key so `nix copy --to ssh://root@…` can push a
  # closure over the LAN — `PermitRootLogin` stays `prohibit-password`, so this
  # grants keys only. One literal, used twice.
  deployKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnNR7isgO8VDY76XzwyH3mOg1/DQo8dZgqQOfziw0DQ devji@nixos";
in {
  users.users.root.openssh.authorizedKeys.keys = [deployKey];
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Shared profiles instead of copies. `boot.nix` owns the loader switches —
    # this box's firmware variables are read-only, so it opts out through the
    # profile's own option rather than hand-rolling `systemd-boot.enable`.
    # `nas-client.nix` owns /Volumes/data: LAN first, tailnet fallback, a
    # recovery timer and the gc-root guard — strictly more than the two-line
    # fstab entry it replaces, and what a travel laptop actually needs.
    ../../modules/profiles/boot.nix
    ../../modules/profiles/nas-client.nix
  ];

  profiles.boot.efi = false;

  boot.supportedFilesystems = ["f2fs" "nfs"];
  hardware.enableRedistributableFirmware = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  # Measured 2026-10-22: the loader stage took 13.1 s of a 47.3 s boot, of which
  # 5 s was this countdown. The menu holds ONE entry, so nobody is choosing —
  # but it holds two while the trimmed initrd (below) is unproven, and this is
  # the only window in which the previous generation can be picked. 10 s until
  # the new initrd has booted once, then 1 s.
  boot.loader.timeout = 10;

  # f2fs mounts with `discard` on by default in this kernel, which issues a
  # synchronous TRIM per delete on a device that measures ~67 IOPS at 4 KiB.
  # fstrim.timer (enabled below) covers the same ground once a week, in bulk.
  fileSystems."/".options = ["nodiscard"];

  # eMMC has no seek cost, so the block-layer scheduler only adds latency. The
  # kernel recommends none for devices with their own queueing; measured
  # 4 KiB direct writes here cost 15 ms each, so nothing else is vying for it.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="mmcblk*", ATTR{queue/scheduler}="none"
  '';
  boot.tmp.cleanOnBoot = true;
  services.fstrim.enable = true;
  services.tailscale.enable = true;

  boot.kernelParams = [
    # Experiment, 2026-10-22: the kernel applies PTI here although Braswell is
    # generally listed as not Meltdown-affected — it cannot confirm it, there is
    # no RDCL_NO bit on this part. Benchmark before the change: 3000 fork+exec
    # took 22.7 s (7.6 ms each). Re-run after a boot with this set; if the delta
    # is not real, delete this line rather than keep a security cost for noise.
    "pti=off"
    # "fsck.mode=skip"
    # "nomodeset"
    # "console=tty1"
    # "quiet" "loglevel=3"
  ];
  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    # zram is the swap device that actually gets used (1.8 GiB, 3.76:1 measured),
    # and decompressing 8 pages to satisfy a 1-page fault is wasted CPU on a
    # 2-core Celeron. 0 = one page per read.
    "vm.page-cluster" = 0;
    "vm.vfs_cache_pressure" = 150;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };
  # Verbose on purpose: this machine has no serial port, and at the old level 3
  # a failing boot was indistinguishable from a frozen screen — generation 50
  # died with nothing on the console to read.
  boot.consoleLogLevel = 7;
  nix.optimise.automatic = true;
  # nix.optimise.interval = "weekly";
  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    # Nix 2.31 wants `--delete-older-than 30d` (space); the hyphenated form this
    # machine shipped with is not a flag, so every run exited 1 and generations
    # piled up until the eMMC was 84 %% full. Measured: `nix-collect-garbage
    # --help` lists the space-separated form only.
    options = "--delete-older-than 30d";
  };
  nix.settings = {
    # This host only receives closures (`nix copy` from frieren); it never builds
    # or imports by hand. auto-optimise hashes every path written, i.e. it taxes
    # each deploy on the slowest device in the fleet. The weekly nix.optimise
    # timer below still dedupes, and 15 GiB free makes that a disk question, not
    # an emergency.
    auto-optimise-store = lib.mkForce false;
    # Flakes on, because this host is now a fleet host rather than a channel
    # island: deploys resolve `.#nixosConfigurations.netbook`.
    experimental-features = ["nix-command" "flakes"];
    # The LAN cache is 3.4 ms away and answers 200 from here (measured), but the
    # image shipped with cache.nixos.org only — so nothing it already had on the
    # NAS was ever used, and every rebuild went to the WAN.
    # cache.nixos.org is added by the module (and appears twice if listed here).
    substituters = [
      "http://192.168.3.25:5000"
      "https://shaoyanji.cachix.org"
      "https://cache.numtide.com"
    ];
    trusted-public-keys = [
      "frieren.lan-1:BUg+1UmfYlF0XCbC0+ZyWQOY1DpQJhj/wa2q76NTFOg="
      "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
    trusted-substituters = ["http://192.168.3.25:5000"];
  };
  services.journald.settings.Journal = {SystemMaxUse = "50M";};
  # LTS, not latest: the newest kernel (`linuxPackages_latest`) could not mount
  # the f2fs root on this eMMC — the failure that pinned the whole host to 25.11.
  boot.kernelPackages = pkgs.linuxPackages;
  # NixOS 26.11 defaults `boot.initrd.systemd.enable` to TRUE, so following the
  # fleet nixpkgs silently swapped the scripted busybox stage-1 this box has
  # booted for a year for systemd-initrd. Generation 50 (systemd-initrd +
  # 6.18.56) produced no journal entry at all: it never reached stage-2. The
  # scripted stage-1 is the variant generation 49 proves on this hardware.
  boot.initrd.systemd.enable = false;
  # The probe wrote the whole superset (SATA, NVMe, vendor HID) into
  # `availableKernelModules` on an eMMC-only box, and the default module set was
  # added on top. The loader reads this image off vfat at ~4.8 MiB/s, so every
  # byte here is boot time: 25.8 MiB measured before this change. Keep the eMMC
  # path, the filesystem, and enough input/USB to reach a rescue shell.
  boot.initrd.includeDefaultModules = lib.mkForce false;
  boot.initrd.availableKernelModules = lib.mkForce [
    "sdhci_acpi"
    "mmc_block"
    "sd_mod"
    "usb_storage"
    "xhci_pci"
    "usbhid"
    "hid_generic"
    "i8042"
    "atkbd"
    "rtsx_pci_sdmmc"
  ];

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
  # Firmware TPM (Intel PTT, ACPI MSFT0101) — the netbook's sops identity. The
  # chip is only useful once `tss` owns /dev/tpmrm0, and the sealed identity is
  # generated ON this host as alice, so alice needs the group. Procedure and
  # traps: docs/sops-rekey.md § TPM-sealed identity. The sealed key lives at
  # ~alice/.config/sops/age/tpm-identity-netbook.txt with `keys.txt` symlinked
  # to it, so plain `sops -d` finds the TPM identity with no env var and no
  # keyFile to configure. Its recipient is `.sops.yaml`'s `&tpmnetbook` — the
  # one identity here that is not derived from an SSH key. No sops-nix plane
  # is wired yet, so it is used by hand.
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };

  users.users.alice = {
    isNormalUser = true;
    extraGroups = ["wheel" "tss"]; # wheel = sudo, tss = /dev/tpmrm0

    openssh.authorizedKeys.keys = [deployKey];
    packages = with pkgs; [
      tree
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # programs.firefox.enable = true;

  programs.niri.enable = true;
  # niri's module ships `default = "gnome;gtk"` and pulls
  # xdg-desktop-portal-gnome, so a 20 MiB GTK4/GNOME stack stays resident for
  # interfaces this compositor cannot serve (the GNOME portal's ScreenCast
  # needs mutter). GTK implements the file chooser, Access and Notification
  # these machines actually use; Secret stays on gnome-keyring (enabled below).
  xdg.portal.config.niri = lib.mkForce {
    default = "gtk";
    "org.freedesktop.impl.portal.Access" = "gtk";
    "org.freedesktop.impl.portal.Notification" = "gtk";
    "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
  };
  xdg.portal.extraPortals = lib.mkForce [
    pkgs.gnome-keyring
    pkgs.xdg-desktop-portal-gtk
  ];

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
  security.pam.services.swaylock = {};

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
    age-plugin-tpm # unseals the TPM-sealed sops identity
    tpm2-tools
    sops # the other half: `SOPS_AGE_KEY_FILE=~/… sops -d`

    git
    curl
    helix
    wget
    uv
    eget
    sqlite
    typst
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
    (mpv.override {youtubeSupport = false;})
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
  hardware.graphics.extraPackages = [pkgs.intel-vaapi-driver];

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
