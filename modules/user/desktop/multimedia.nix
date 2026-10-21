{
  config,
  osConfig ? {},
  pkgs,
  lib,
  ...
}: let
  cfg = config.profiles.graphics;

  # Determine host and GPU from fleet inventory
  hostName = osConfig.networking.hostName or (config.networking.hostName or null);
  invHost =
    if hostName != null
    then (osConfig.fleet.inventory.hosts.${hostName} or (config.fleet.inventory.hosts.${hostName} or null))
    else null;
  gpuDesc = invHost.hardware.gpu or "";

  # Auto-detection of tier based on GPU description and host identity
  detectedTier =
    if
      builtins.elem hostName ["aristotle" "netbook"]
      || lib.strings.hasInfix "4400" gpuDesc
      || lib.strings.hasInfix "3000" gpuDesc
      || lib.strings.hasInfix "Braswell" gpuDesc
      || lib.strings.hasInfix "N3060" gpuDesc
    then "low"
    else if
      builtins.elem hostName ["eisen" "poseidon" "ares"]
      || lib.strings.hasInfix "RX 5700" gpuDesc
      || lib.strings.hasInfix "RTX" gpuDesc
      || lib.strings.hasInfix "Navi" gpuDesc
    then "high"
    else "medium"; # Default for UHD 620 (frieren, fern), Intel Graphics, modern iGPUs
in {
  options.profiles.graphics = {
    enable =
      lib.mkEnableOption "hardware-scoped graphics and multimedia profile"
      // {
        default = true;
      };

    tier = lib.mkOption {
      type = lib.types.enum ["low" "medium" "high"];
      default = detectedTier;
      description = ''
        Graphics hardware capability tier:
        - "low": Legacy / power-constrained iGPUs (e.g. Haswell Intel HD 4400 on aristotle).
                 VA-API H.264/MPEG2 hardware decode only (no VP9/AV1). Caps streaming video to 1080p
                 and forces H.264/AVC to protect low-power dual-core CPUs from software decode thrashing.
        - "medium": Modern iGPUs / APUs (e.g. Kaby Lake R Intel UHD 620 on frieren/fern).
                    Hardware VP9 & HEVC 10-bit decode up to 4K (3840x2160), spline36 scaling.
        - "high": High-performance discrete GPUs (e.g. AMD RX 5700 on eisen, NVIDIA RTX on poseidon).
                  Vulkan-based gpu-next renderer, auto-safe hwdec, deband, ewa_lanczossharp scaling,
                  unrestricted 4K/8K streaming.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Declarative mpv with hardware-tier acceleration and Wayland integration
    programs.mpv = {
      enable = true;
      scripts = with pkgs.mpvScripts; [
        mpris # Media key and playerctl integration with Niri / Wayland
        uosc # Modern, lightweight, fast Wayland-friendly UI
        thumbfast # Fast on-the-fly thumbnail generation
      ];

      # Tier-differentiated mpv.conf settings
      config = lib.mkMerge [
        # --- Baseline Common Configuration ---
        {
          keep-open = "yes";
          save-position-on-quit = "yes";
          screenshot-directory = "~/Pictures/Screenshots";
          screenshot-format = "webp";
          screenshot-webp-lossless = "yes";
          volume = 100;
          volume-max = 150;
        }

        # --- Low Tier (Haswell / Intel HD 4400: Aristotle) ---
        # Haswell Gen 7.5 has hardware VA-API for H.264/AVC, VC-1, MPEG-2.
        # It has NO hardware decode for VP9 or AV1.
        # CRUCIAL: ytdl-format forces H.264 (avc1) <= 1080p so YouTube streams are hardware-decoded
        # by the VA-API engine instead of melting the 15W dual-core i5-4300U CPU with software VP9/AV1 decoding.
        (lib.mkIf (cfg.tier == "low") {
          vo = "gpu";
          gpu-context = "wayland";
          hwdec = "vaapi";
          hwdec-codecs = "all";
          scale = "spline36";
          dscale = "mitchell";
          cscale = "bilinear";
          interpolation = "no";
          deband = "no";
          ytdl-format = "bestvideo[vcodec^=avc1][height<=?1080]+bestaudio/best[vcodec^=avc1][height<=?1080]/best[height<=?1080]";
        })

        # --- Medium Tier (Kaby Lake R / UHD 620: Frieren & Fern) ---
        # UHD 620 has hardware QuickSync VA-API for H.264, HEVC 8/10-bit, VP9 Profile 0/2 up to 4K60.
        # Connected to 4K TV on Frieren.
        (lib.mkIf (cfg.tier == "medium") {
          vo = "gpu";
          gpu-context = "wayland";
          hwdec = "vaapi";
          scale = "spline36";
          cscale = "spline36";
          dscale = "mitchell";
          ytdl-format = "bestvideo[height<=?2160]+bestaudio/best[height<=?2160]/best";
        })

        # --- High Tier (Navi 10 / RX 5700: Eisen, RTX: Poseidon) ---
        # Discrete desktop GPU with high compute & VRAM.
        # Uses gpu-next with Vulkan, high-quality profile, debanding, sharp scaling.
        (lib.mkIf (cfg.tier == "high") {
          vo = "gpu-next";
          gpu-api = "vulkan";
          hwdec = "auto-safe";
          profile = "high-quality";
          scale = "ewa_lanczossharp";
          cscale = "ewa_lanczossharp";
          deband = "yes";
          ytdl-format = "bestvideo+bestaudio/best";
        })
      ];
    };

    # Declarative yt-dlp configuration matching the graphics tier
    programs.yt-dlp = {
      enable = true;
      settings = lib.mkMerge [
        {
          output = "%(title)s [%(id)s].%(ext)s";
          embed-metadata = true;
          embed-thumbnail = true;
          concurrent-fragments = 4;
        }
        (lib.mkIf (cfg.tier == "low") {
          # Prioritize H.264 1080p for hardware playback on legacy/low-power machines
          format = "bestvideo[vcodec^=avc1][height<=?1080]+bestaudio/best[vcodec^=avc1][height<=?1080]/best[height<=?1080]";
        })
        (lib.mkIf (cfg.tier == "medium") {
          format = "bestvideo[height<=?2160]+bestaudio/best[height<=?2160]/best";
        })
        (lib.mkIf (cfg.tier == "high") {
          format = "bestvideo+bestaudio/best";
        })
      ];
    };
  };
}
