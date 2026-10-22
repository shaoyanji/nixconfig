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
  # Fork, not inheritance: see [[flake/policies.nix#desktop-fork-not-disable]].
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/boot.nix
    ../../modules/profiles/nas-client.nix
  ];

  # Replaces the fleet userland default; see [[flake/policies.nix#desktop-fork-not-disable]].
  fleet.hmUserModules = [
    ../../modules/user/base.nix
    ../../modules/user/desktop/appimage-launchers.nix
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

  # Media keys in config.h spawn wpctl/playerctl.
  services.displayManager.sddm.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  # Reachability is infrastructure, not part of the desktop.
  services.tailscale.enable = true;

  # Needed by appimage-launchers' .desktop entries.
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # dwl/foot/wmenu name the font, they do not ship it.
  fonts = {
    packages = [pkgs.nerd-fonts.jetbrains-mono];
    fontconfig.defaultFonts.monospace = ["JetBrainsMono Nerd Font Mono" "JetBrainsMono NFM"];
  };

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
      # foot 1.28 rejects the old single [colors] section.
      colors-dark = {
        alpha = "0.95";
      };
    };
  };

  security.pam.services.waylock = {};
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

  documentation.enable = false;
  documentation.nixos.enable = false;
  documentation.man.enable = false;
  documentation.doc.enable = false;

  hardware.graphics.enable = true;

  # No disk swap; base-node's 50% default is overridden.
  zramSwap.memoryPercent = lib.mkForce 100;

  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "25%";

  fileSystems."${user.home}/.cache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=512M" "mode=0755" "uid=1000" "gid=100"];
  };

  # Its own budget: appimage-run never evicts extractions (notes: appimage-run-cache-tmpfs).
  fileSystems."${user.home}/.cache/appimage-run" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=3G" "mode=0700" "uid=1000" "gid=100" "nosuid" "nodev"];
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

  services.journald = {
    storage = "volatile";
    settings.Journal.SystemMaxUse = "50M";
  };

  systemd.coredump.enable = false;
  services.fstrim.enable = true;

  boot.kernel.sysctl = {
    "vm.swappiness" = 100; # prefer zram swap over evicting cache
    "vm.vfs_cache_pressure" = 50; # keep dentries/inodes in RAM → fewer reads
    "vm.dirty_ratio" = 10; # smaller, more frequent writeback
    "vm.dirty_background_ratio" = 5;
  };

  boot.consoleLogLevel = 3;
  nix.optimise.automatic = true;

  environment.systemPackages = with pkgs; [
    btop
    customDwl
    foot
    wmenu
    j4-dmenu-desktop
    waylock
    wl-clipboard
    imv
    grim
    slurp
    playerctl
    brightnessctl
    age-plugin-tpm
    tpm2-tools
  ];
  # Referenced by config.h: j4-dmenu-desktop (Mod+A/Mod+Space), grim+slurp
  # (Mod+S/Mod+Print), playerctl/brightnessctl (media keys).

  # TPM-only recipient; base-node's sshKeyPaths would need an `&scratchhost`
  # entry that deliberately does not exist. See docs/sops-rekey.md.
  sops = {
    age.keyFile = "${user.home}/.config/sops/age/tpm-identity.txt";
    age.sshKeyPaths = lib.mkForce [];
    age.plugins = [pkgs.age-plugin-tpm];
  };

  # /dev/tpmrm0 is root:tss 0660 and --generate runs as the user.
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };
  users.users.${user.name}.extraGroups = ["tss"];

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
