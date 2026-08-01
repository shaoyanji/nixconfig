# eisen — Xeon E5-2673 v3 + RX 5700 + 64 GB RAM dual-role machine.
#
# Hardware:
#   CPU:  Intel Xeon E5-2673 v3 (Haswell-EP, 12c/24t, no iGPU)
#   GPU:  AMD Radeon RX 5700 (Navi 10, 8 GB VRAM, VCN 2.0)
#   RAM:  64 GB DDR4
#   SSD:  128 GB NVMe (BTRFS: @root, @nix, @persist, @log, @snapshots)
#   Boot: UEFI (systemd-boot on /dev/disk/by-uuid/34F9-8033)
#
# Role:  Dual-specialization machine via greetd session switching.
#        - Console mode (default): Steam Big Picture via cage, auto-login
#          on boot.  Sunshine GameStream for Moonlight clients.
#        - Workstation mode: exit Steam → niri desktop auto-launches
#          with full role:heim tooling (kitty, zen, dev, AI agents).
#        RX 5700 VCN 2.0 handles H.264/H.265 encode for Sunshine
#        streaming and ffmpeg transcoding workloads.
#
# Storage: /mnt/steam = sda (931.5G HDD, btrfs+zstd) — Steam library, live.
# Future:  16 TB HDD → /mnt/media (media library) when the drive arrives.
{ config, lib, pkgs, ... }:
let
  user = import ../../modules/global/user.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./amd-rx-5700.nix
    ../../modules/profiles/steamos.nix
    ../../modules/profiles/sunshine.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/nas-client.nix
  ];

  networking.hostName = "eisen";

  # X server is required so XWayland can host legacy X11-only windows
  # that Steam spawns inside cage (console mode) and niri (workstation
  # mode).  Both compositors rely on XWayland for legacy app support.
  services.xserver.enable = true;

  # --- Bluetooth (wireless controllers in Steam + niri) ---
  hardware.bluetooth.enable = true;

  # --- Wayland environment (workstation mode) ---
  # Force Electron/Chromium and Qt apps to use native Wayland instead
  # of falling back to X11/XWayland.  base-node.nix sets TERM; these
  # are merged additively by the NixOS module system.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_QPA_PLATFORMTHEME = "kde";
    XDG_MENU_PREFIX = "plasma-";
  };

  # --- Niri compositor (workstation mode) ---
  # Installs the niri Wayland compositor and its session wrapper
  # (`niri-session`) at the NixOS level, which greetd uses as the
  # fallback session when Steam exits.  Home-manager config for niri
  # (keybinds, theming, DMS integration) comes from role:heim via
  # the globalModulesNixos module chain.
  programs.niri.enable = true;

  # --- XDG Desktop Portal (needed by niri for file dialogs, screenshots) ---
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
      xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [ "kde" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" "gtk" ];
    };
    config.niri = lib.mkForce {
      default = [ "kde" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "kde" "gtk" ];
    };
  };

  # --- greetd dual-session: Steam kiosk → niri desktop ---
  # Overrides steamos.nix's permanent auto-login.  greetd's
  # `initial_session` runs once on boot (Steam Big Picture).  When
  # Steam/cage exits, greetd falls back to `default_session` which
  # launches a full niri desktop.  Exiting niri relaunches niri.
  #
  # To switch modes:
  #   Console → Workstation: exit Steam Big Picture (Steam menu → Exit)
  #   Workstation → Console: run `steam -gamepadui` from niri, or
  #     `sudo systemctl restart greetd` to reboot the session stack.
  services.greetd = {
    enable = true;
    settings = lib.mkForce {
      initial_session = {
        user = "devji";
        command = "gamescope-session";
      };
      default_session = {
        user = "devji";
        command = "niri-session";
      };
    };
  };

  # --- Tailscale mesh networking ---
  # Enables the eisen host on the tailnet so Moonlight clients can stream
  # from outside the LAN (via Tailscale IPs / MagicDNS).  Routing features
  # are set to "both" so eisen can act as an exit node and subnet router
  # if needed later.  DNS through the pi-hole at thinsandy (100.73.225.35)
  # keeps ad-blocking consistent across the tailnet.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    extraUpFlags = [
      "--dns=100.73.225.35"
      "--accept-dns=true"
    ];
  };

  # --- 4K transcoding tooling ---
  # ffmpeg-full is in amd-rx-5700.nix for VAAPI-accelerated encode/decode.
  # When Jellyfin is deployed, add jellyfin-ffmpeg for its bundled codecs.
  environment.systemPackages = with pkgs; [
    libva-utils # vainfo — check VCN encode/decode surface list
    jq # JSON wrangling
    htop # system monitor
    btop # prettier system monitor
  ];

  # --- Storage drives ---
  #
  # /mnt/steam: sda — 931.5G HDD (formerly the Proxmox install), formatted
  # as a single btrfs partition labeled `steam` (btrfs+zstd).  Mounted
  # by-label so no UUID needs tracking, with `nofail` so a missing label
  # never blocks boot into emergency mode.  After first mount, own it once:
  #   sudo chown devji:users /mnt/steam
  # Then add it in Steam: Settings → Storage → Add Drive → /mnt/steam.
  #
  # /mnt/media (FUTURE): 16 TB HDD → media library.  When the drive
  # arrives: mkfs.btrfs -L media /dev/sdX, then uncomment the block
  # below and add it to autoScrub.
  #
  # fileSystems."/mnt/media" = {
  #   device = "/dev/disk/by-label/media";
  #   fsType = "btrfs";
  #   options = [ "compress=zstd" "noatime" "autodefrag" ];
  # };

  fileSystems."/mnt/steam" = {
    device = "/dev/disk/by-label/steam";
    fsType = "btrfs";
    options = [ "compress=zstd" "noatime" "autodefrag" "nofail" ];
  };

  # tmpfs shadercache dir.  The /mnt/steam mountpoint is created by the
  # mount unit itself; ownership is set once via chown after first mount.
  systemd.tmpfiles.rules = [
    "d ${user.home}/.steam/steam/steamapps/shadercache 0755 devji users - -"
  ];

  # --- Btrfs auto-scrub (monthly) ---
  # The NVMe root and the Steam library are btrfs.  Monthly scrub
  # detects and repairs bit rot using checksums.  Add /mnt/media when
  # that drive is provisioned.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [
      "/"
      "/mnt/steam"
    ];
  };

  # --- CPU governor: performance for low-latency 4K gaming ---
  # The Xeon E5-2673 v3 defaults to powersave. For competitive Dota 2 at
  # 4K with simultaneous Sunshine encoding, the CPU needs to ramp quickly.
  # Cost is ~20 W extra at idle (120 W TDP chip, so mostly irrelevant).
  powerManagement.cpuFreqGovernor = "performance";

  # --- scx_rusty CPU scheduler ---
  # scx (sched_ext) rusty is a BPF-based scheduler optimized for
  # interactive desktop responsiveness.  On a 12c/24t Xeon running both
  # gaming (Steam/Sunshine) and workstation workloads (niri/kitty/dev),
  # rusty keeps the foreground compositor and game threads responsive
  # while background tasks (builds, ffmpeg) use the remaining cores.
  services.scx = {
    enable = true;
    scheduler = "scx_rusty";
  };

  # --- Steam shader cache on tmpfs (16 GB RAM disk) ---
  # Dota 2 and other Vulkan/OpenGL titles compile shaders on first launch.
  # Keeping the cache in RAM eliminates NVMe wear and reduces stutter from
  # shader compilation during gameplay.  16 GB leaves 48 GB for page cache
  # and active game data — more than enough for any single game.
  fileSystems."${user.home}/.steam/steam/steamapps/shadercache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=16G"
      "mode=0755"
      "uid=1000"
      "gid=100"
    ];
  };

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
