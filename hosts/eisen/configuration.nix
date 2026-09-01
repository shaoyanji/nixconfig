# eisen — Xeon E5-2673 v3 + RX 5700 + 64 GB RAM gaming desktop.
#
# Hardware:
#   CPU:  Intel Xeon E5-2673 v3 (Haswell-EP, 12c/24t, no iGPU)
#   GPU:  AMD Radeon RX 5700 (Navi 10, 8 GB VRAM, VCN 2.0)
#   RAM:  64 GB DDR4
#   SSD:  128 GB NVMe (BTRFS: @root, @nix, @persist, @log, @snapshots)
#   Boot: UEFI (systemd-boot on /dev/disk/by-uuid/34F9-8033)
#
# Role:  Full desktop (poseidon-style) with Steam gaming.
#        niri compositor with DankMaterialShell greeter (DMS) provides the
#        desktop; Steam runs under the upstream gamescope-session, which is
#        safe on the RX 5700's modern Vulkan ICD (unlike kellerbench's
#        Kepler card, where cage is required).  Sunshine GameStream for
#        Moonlight clients.  RX 5700 VCN 2.0 handles H.264/H.265 encode for
#        streaming and ffmpeg transcoding.
#
# History: previously a pure cage + steam -gamepadui kiosk (steamos.nix
#          auto-login).  The specialisation AND greetd dual-session
#          experiments both hung boot at graphical.target, so the DMS
#          greeter path (as on poseidon) replaces greetd auto-login.
#
# Storage: /mnt/steam = sda (931.5G HDD, btrfs+zstd) — Steam library, live.
# Future:  16 TB HDD → /mnt/media (media library) when the drive arrives.
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [
    ./hardware-configuration.nix
    ./amd-rx-5700.nix
    ../../modules/profiles/steam.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/nas-client.nix
    ../../modules/profiles/sunshine.nix
  ];

  networking.hostName = "eisen";

  # --- Desktop (poseidon-style): niri compositor + DankMaterialShell greeter ---
  # The previous cage-kiosk specialisation and greetd dual-session experiments
  # both hung boot at graphical.target, so the DMS greeter path (as on
  # poseidon) is used instead of greetd auto-login.
  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home; # Sync themes with user's DankMaterialShell config
  };

  # --- Steam under gamescope ---
  # The RX 5700's modern Vulkan ICD fully supports gamescope's compositor
  # (unlike kellerbench's Kepler + legacy_580 card, where gamescope's
  # wlserver crashes with "Creating headless backend").  steam.nix enables
  # programs.steam.gamescopeSession, so greetd/DMS can launch the upstream
  # gamescope-session script directly.
  programs.gamescope.enable = true;

  # --- Bluetooth (wireless controllers in Steam) ---
  hardware.bluetooth.enable = true;

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
    options = ["compress=zstd" "noatime" "autodefrag" "nofail"];
  };

  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-label/storage";
    fsType = "btrfs";
    options = ["compress=zstd" "noatime" "autodefrag" "nofail"];
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
