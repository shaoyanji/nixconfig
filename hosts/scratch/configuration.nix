# scratch — Fujitsu ESPRIMO D556 (i5-6500) niri desktop.
{
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;

  # Suckless Wayland: dwl with Catppuccin Mocha sensible defaults
  customDwl = pkgs.dwl.override {
    configH = builtins.readFile ../../modules/config/dwl/config.h;
  };

  # greetd launches the session with XDG_SESSION_TYPE=tty, which is what a
  # greeter is, not what a compositor is: clients that branch on it (portals,
  # GTK, screencast) then take the TTY path. niri exports these itself; dwl
  # does not, so the session gets a wrapper. Both the autologin session and
  # tuigreet's --cmd use it, so a manual login is identical to the autologin.
  dwlSession = pkgs.writeShellScript "dwl-session" ''
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=dwl
    export XDG_CURRENT_DESKTOP=dwl
    exec ${customDwl}/bin/dwl "$@"
  '';
in {
  imports = [
    ./hardware-configuration.nix
    # Full desktop baseline (eisen/poseidon): niri + DMS greeter +
    # portals + fonts, and transitively base-node (SSH, sops, firewall,
    # zram default) + desktop-client (tailscale, avahi, printing,
    # pipewire, bluetooth).
    ../../modules/profiles/base-desktop-environment.nix
  ];

  # /boot is ext4 (legacy BIOS + GRUB) — NOT a vfat ESP, so systemd-boot
  # cannot be used. base-node's boot.nix defaults to systemd-boot; override
  # per the machine's original layout (gist 12006e57e885fc3864e9197826d69276).
  profiles.boot = {
    systemd-boot = false;
    efi = false;
  };
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda"; # legacy BIOS MBR install — adjust if the disk is not sda
  };

  # --- Minimalist Suckless Desktop: dwl (Wayland) + foot + wmenu ---
  programs.niri.enable = lib.mkForce false;
  programs.dms-greeter.enable = lib.mkForce false;
  services.displayManager.sddm.enable = false;

  # Foot terminal with Catppuccin Mocha sensible defaults
  programs.foot = {
    enable = true;
    theme = "catppuccin-mocha";
    settings = {
      main = {
        font = "JetBrainsMono NFM:size=11";
        pad = "12x12 center";
        dpi-aware = "yes";
      };
      cursor = {
        style = "beam";
        blink = "yes";
      };
      # foot 1.28 replaced the single [colors] section with dark/light
      # palettes; [colors] is now rejected outright at parse time.
      colors-dark = {
        alpha = "0.95";
      };
    };
  };

  # X11 dwm fallback available on system
  services.xserver = {
    enable = true;
    windowManager.dwm = {
      enable = true;
      extraSessionCommands = ''
        ${pkgs.slstatus}/bin/slstatus &
        ${pkgs.xorg.xsetroot}/bin/xsetroot -solid "#1e1e2e" &
      '';
    };
    displayManager.startx.enable = true;
  };

  # Screen locker setuid PAM integrations
  programs.slock.enable = true;
  security.pam.services.waylock = {};

  # Direct lightweight autologin into dwl via greetd (with none+dwm registered)
  services.displayManager.defaultSession = lib.mkForce "none+dwm";
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd ${dwlSession}";
        user = "greeter";
      };
      initial_session = {
        command = "${dwlSession}";
        user = user.name;
      };
    };
  };

  # ── Suckless Debloat & Closure Diet ──
  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;
  documentation.doc.enable = false;

  services.udisks2.enable = lib.mkForce false;
  services.accounts-daemon.enable = lib.mkForce false;
  services.printing.enable = lib.mkForce false;
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # Intel HD 530 iGPU — Mesa via modesetting.
  hardware.graphics.enable = true;

  # ── Swap: zram only, 100% of RAM, zstd ──
  # base-node defaults to 50%; scratch has NO disk swap so we take the
  # full 8 GB (compressed ~2-4x in RAM). mkForce overrides base-node.
  zramSwap.memoryPercent = lib.mkForce 100;

  # ── Heavy-write dirs on tmpfs (8 GB RAM budget) ──
  # /tmp on tmpfs (NixOS-managed), capped at 25% of RAM.
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "25%";

  fileSystems."${user.home}/.cache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=512M" "mode=0755" "uid=1000" "gid=100"];
  };

  fileSystems."/var/log" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=128M" "mode=0755" "nosuid" "nodev"];
  };

  fileSystems."/var/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=256M" "mode=1777" "nosuid" "nodev"];
  };

  fileSystems."/var/cache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=256M" "mode=0755" "nosuid" "nodev"];
  };

  # Journals live in RAM only — nothing hits the f2fs SSD.
  services.journald = {
    storage = "volatile";
    settings.Journal.SystemMaxUse = "50M";
  };

  # No core dumps written to disk.
  systemd.coredump.enable = false;

  # Weekly TRIM for the SSD (f2fs supports discard via fstrim).
  services.fstrim.enable = true;

  # ── Writeback tuning: gentle bursts + keep metadata cached ──
  boot.kernel.sysctl = {
    "vm.swappiness" = 100; # prefer zram swap over evicting cache
    "vm.vfs_cache_pressure" = 50; # keep dentries/inodes in RAM → fewer reads
    "vm.dirty_ratio" = 10; # smaller, more frequent writeback
    "vm.dirty_background_ratio" = 5;
  };

  # Quiet early-boot console chatter.
  boot.consoleLogLevel = 3;

  # ── Nix store hygiene: small store = less SSD churn ──
  # GC is inherited from the global nix settings (modules/global/global.nix,
  # `--delete-older-than 10d`); no host-local GC override needed.
  nix.optimise.automatic = true;

  environment.systemPackages = with pkgs; [
    btop # RAM/tmpfs/zram visibility
    # Suckless Wayland (Default Session)
    customDwl
    foot
    wmenu
    waylock
    wl-clipboard
    imv
    # Mod+S / Mod+Print screenshots (niri parity)
    grim
    slurp
    # TPM: identity generation and inspection live on the host
    age-plugin-tpm
    tpm2-tools
    # Suckless X11 Core Toolchain
    dwm
    st
    dmenu
    slstatus
    slock
    nsxiv
    vis
    xclip
  ];

  # --- sops: both planes unseal through the TPM ---
  # base-node gives every host `age.sshKeyPaths = [/etc/ssh/ssh_host_ed25519_key]`
  # and .sops.yaml carries the matching `&<host>host` recipient. This host has
  # no SSH-derived recipient on purpose: the only scratch recipient is the
  # TPM-sealed identity, so root reads the same tpm-identity.txt the user plane
  # does (root can read the 0400 file; `age-plugin-tpm` must be on PATH for the
  # unseal, which is what `age.plugins` puts there).
  sops = {
    age.keyFile = "${user.home}/.config/sops/age/tpm-identity.txt";
    age.sshKeyPaths = lib.mkForce [];
    age.plugins = [pkgs.age-plugin-tpm];
  };

  # --- TPM 2.0 (firmware TPM on the Q150 board) ---
  # Same shape as hosts/fern/configuration.nix and hosts/frieren/hardware.nix:
  # the chip holds the age identity that the user sops plane unseals, so no
  # identity file has to be copied onto the machine. tss-groups devji because
  # /dev/tpmrm0 is root:tss 0660 and `age-plugin-tpm --generate` runs as the
  # user, not as root.
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };
  users.users.${user.name}.extraGroups = ["tss"];

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
