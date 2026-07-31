# eisen — Xeon E5-2673 v3 + RX 5700 + 64 GB RAM streaming/gaming rig.
#
# Hardware:
#   CPU:  Intel Xeon E5-2673 v3 (Haswell-EP, 12c/24t, no iGPU)
#   GPU:  AMD Radeon RX 5700 (Navi 10, 8 GB VRAM, VCN 2.0)
#   RAM:  64 GB DDR4
#   SSD:  128 GB NVMe (BTRFS: @root, @nix, @persist, @log, @snapshots)
#   Boot: UEFI (systemd-boot on /dev/disk/by-uuid/34F9-8033)
#
# Role:  Headless 4K gaming console + media transcoding host.
#        Steam Big Picture via cage + Sunshine GameStream for Moonlight
#        clients.  RX 5700 VCN 2.0 handles H.264/H.265 encode for
#        Sunshine streaming and ffmpeg transcoding workloads.
#
# Future: 16 TB HDD (media library) + 1 TB SSD (Steam library).
#         Add fileSystems entries and mount points when drives arrive.
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./amd-rx-5700.nix
    ../../modules/profiles/steamos.nix
    ../../modules/profiles/sunshine.nix
    ../../modules/profiles/base-node.nix
  ];

  networking.hostName = "eisen";

  # X server is required so XWayland can host any legacy X11-only windows
  # that Steam spawns inside cage's Wayland surface.  No desktop
  # environment is configured — greetd auto-logs devji into
  # gamescope-session (cage + steam -gamepadui) which is the entire
  # user-facing UI.
  services.xserver.enable = true;

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

  # Power profile: Xeon E5-2673 v3 TDP is 120 W.  The CPU governor
  # defaults to "powersave" which is fine for a streaming box (most
  # heavy lifting is on the GPU).  If latency-sensitive workloads
  # (competitive shooters at >120 fps) need more CPU responsiveness,
  # switch to "performance" via:
  #   powerManagement.cpuFreqGovernor = "performance";

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
