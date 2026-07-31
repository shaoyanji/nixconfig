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
# Future: 16 TB HDD (media library) + 1 TB SSD (Steam library).
#         Add fileSystems entries and mount points when drives arrive.
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
  ];

  networking.hostName = "eisen";

  # X server is required so XWayland can host legacy X11-only windows
  # that Steam spawns inside cage (console mode) and niri (workstation
  # mode).  Both compositors rely on XWayland for legacy app support.
  services.xserver.enable = true;

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

  # --- Placeholder: future /mnt/media (16 TB HDD) ---
  # Uncomment and adjust when the drive is installed:
  #
  # fileSystems."/mnt/media" = {
  #   device = "/dev/disk/by-uuid/<UUID>";
  #   fsType = "ext4";  # or btrfs / xfs
  #   options = [ "defaults" "noatime" ];
  # };
  #
  # --- Placeholder: future /mnt/steam (1 TB SSD Steam library) ---
  # fileSystems."/mnt/steam" = {
  #   device = "/dev/disk/by-uuid/<UUID>";
  #   fsType = "ext4";
  #   options = [ "defaults" "noatime" ];
  # };

  # --- CPU governor: performance for low-latency 4K gaming ---
  # The Xeon E5-2673 v3 defaults to powersave. For competitive Dota 2 at
  # 4K with simultaneous Sunshine encoding, the CPU needs to ramp quickly.
  # Cost is ~20 W extra at idle (120 W TDP chip, so mostly irrelevant).
  powerManagement.cpuFreqGovernor = "performance";

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

  systemd.tmpfiles.rules = [
    "d ${user.home}/.steam/steam/steamapps/shadercache 0755 devji users - -"
  ];

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
