{
  self,
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;

  ytFrieren = pkgs.writers.writeBashBin "yt-frieren" ''
    set -euo pipefail

    usage() {
      cat <<'USAGE_EOF'
    yt-frieren — Offload YouTube download to frieren NAS (1080p H.264 MP4)

    Usage:
      yt-frieren [OPTIONS] <URL> [extra yt-dlp args...]

    Options:
      -p, --play       Auto-play in mpv as soon as download finishes
      -b, --bg         Run download in background and return immediately
      -h, --help       Show this help message

    Target:
      Downloads are executed on frieren via SSH and saved to
      /Volumes/data/video/yt/mp4 (NFS-shared with Aristotle).
      Hardware-accelerated Haswell H.264 profile is prioritized.
      A desktop notification appears on completion with a "Play in MPV" button.
    USAGE_EOF
      exit 0
    }

    auto_play=0
    bg_mode=0
    url=""
    extra_args=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h|--help)
          usage
          ;;
        -p|--play)
          auto_play=1
          shift
          ;;
        -b|--bg)
          bg_mode=1
          shift
          ;;
        --no-bg)
          bg_mode=0
          shift
          ;;
        -*)
          extra_args+=("$1")
          shift
          ;;
        *)
          if [[ -z "$url" ]]; then
            url="$1"
          else
            extra_args+=("$1")
          fi
          shift
          ;;
      esac
    done

    if [[ -z "$url" ]]; then
      echo "yt-frieren: error: YouTube URL is required" >&2
      usage
    fi

    if [[ "$bg_mode" -eq 1 ]]; then
      echo "yt-frieren: offloading download to frieren in background..."
      nohup "$0" --no-bg ''${auto_play:+-p} "$url" "''${extra_args[@]}" >/dev/null 2>&1 &
      echo "yt-frieren: background job started (PID: $!). Notification will alert on completion."
      exit 0
    fi

    echo "==> Offloading download to frieren NAS..."
    echo "==> Target directory: /Volumes/data/video/yt/mp4"

    title="YouTube Video"
    filepath=""

    # Run remote download on frieren over SSH
    while IFS= read -r line; do
      if [[ "$line" =~ ^YT_TITLE:(.*)$ ]]; then
        title="''${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^YT_FILE:(.*)$ ]]; then
        filepath="''${BASH_REMATCH[1]}"
      else
        echo "$line"
      fi
    done < <(${pkgs.openssh}/bin/ssh -T frieren bash -s -- "$url" "''${extra_args[@]}" << 'REMOTESH'
    set -euo pipefail
    URL="$1"
    shift || true
    OUTDIR="/Volumes/data/video/yt/mp4"
    mkdir -p "$OUTDIR"

    TITLE=$(yt-dlp --ignore-config --simulate --print title "$URL" 2>/dev/null || echo "YouTube Video")
    echo "YT_TITLE:$TITLE"

    yt-dlp \
      --ignore-config \
      --format-sort "vcodec:h264,res:1080,acodec:m4a" \
      --recode-video mp4 \
      --merge-output-format mp4 \
      --concurrent-fragments 4 \
      --embed-metadata \
      --embed-thumbnail \
      --output "$OUTDIR/%(title)s [%(id)s].%(ext)s" \
      --exec 'echo YT_FILE:{}' \
      "$@" \
      "$URL"
    REMOTESH
    )

    if [[ -z "$filepath" ]]; then
      echo "yt-frieren: download completed, but could not determine output path."
      exit 0
    fi

    echo ""
    echo "==> Download complete: $filepath"

    if [[ "$auto_play" -eq 1 ]]; then
      echo "==> Auto-playing in mpv..."
      exec ${pkgs.mpv}/bin/mpv --profile=fast "$filepath"
    fi

    # Send interactive notification via libnotify
    action=$(${pkgs.libnotify}/bin/notify-send \
      -a "yt-frieren" \
      -i video-x-generic \
      -t 60000 \
      -A "play=▶ Play in MPV" \
      -A "folder=📂 Open Folder" \
      "Download Complete" \
      "$title" 2>/dev/null || true)

    case "$action" in
      play|default|0)
        echo "==> Notification clicked: launching mpv..."
        exec ${pkgs.mpv}/bin/mpv --profile=fast "$filepath"
        ;;
      folder|1)
        exec xdg-open "$(dirname "$filepath")"
        ;;
    esac
  '';

  ytPod = pkgs.writers.writeBashBin "yt-pod" ''
    set -euo pipefail

    usage() {
      cat <<'USAGE_EOF'
    yt-pod — Offload YouTube podcast / audio download to frieren NAS (MP3)

    Usage:
      yt-pod [OPTIONS] <URL> [extra yt-dlp args...]

    Options:
      -p, --play       Auto-listen in mpv as soon as download finishes
      -b, --bg         Run download in background and return immediately
      -h, --help       Show this help message

    Target:
      Downloads are executed on frieren via SSH and saved to
      /Volumes/data/video/yt/mp3 (NFS-shared with Aristotle).
      Audio is extracted to high-quality MP3 with embedded metadata/thumbnail.
      A desktop notification appears on completion with a "Listen in MPV" button.
    USAGE_EOF
      exit 0
    }

    auto_play=0
    bg_mode=0
    url=""
    extra_args=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        -h|--help)
          usage
          ;;
        -p|--play)
          auto_play=1
          shift
          ;;
        -b|--bg)
          bg_mode=1
          shift
          ;;
        --no-bg)
          bg_mode=0
          shift
          ;;
        -*)
          extra_args+=("$1")
          shift
          ;;
        *)
          if [[ -z "$url" ]]; then
            url="$1"
          else
            extra_args+=("$1")
          fi
          shift
          ;;
      esac
    done

    if [[ -z "$url" ]]; then
      echo "yt-pod: error: YouTube URL is required" >&2
      usage
    fi

    if [[ "$bg_mode" -eq 1 ]]; then
      echo "yt-pod: offloading audio download to frieren in background..."
      nohup "$0" --no-bg ''${auto_play:+-p} "$url" "''${extra_args[@]}" >/dev/null 2>&1 &
      echo "yt-pod: background job started (PID: $!). Notification will alert on completion."
      exit 0
    fi

    echo "==> Offloading audio download to frieren NAS..."
    echo "==> Target directory: /Volumes/data/video/yt/mp3"

    title="YouTube Audio"
    filepath=""

    # Run remote download on frieren over SSH
    while IFS= read -r line; do
      if [[ "$line" =~ ^YT_TITLE:(.*)$ ]]; then
        title="''${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^YT_FILE:(.*)$ ]]; then
        filepath="''${BASH_REMATCH[1]}"
      else
        echo "$line"
      fi
    done < <(${pkgs.openssh}/bin/ssh -T frieren bash -s -- "$url" "''${extra_args[@]}" << 'REMOTESH'
    set -euo pipefail
    URL="$1"
    shift || true
    OUTDIR="/Volumes/data/video/yt/mp3"
    mkdir -p "$OUTDIR"

    TITLE=$(yt-dlp --ignore-config --simulate --print title "$URL" 2>/dev/null || echo "YouTube Audio")
    echo "YT_TITLE:$TITLE"

    yt-dlp \
      --ignore-config \
      -x \
      --audio-format mp3 \
      --audio-quality 0 \
      --concurrent-fragments 4 \
      --embed-metadata \
      --embed-thumbnail \
      --output "$OUTDIR/%(title)s [%(id)s].%(ext)s" \
      --exec 'echo YT_FILE:{}' \
      "$@" \
      "$URL"
    REMOTESH
    )

    if [[ -z "$filepath" ]]; then
      echo "yt-pod: download completed, but could not determine output path."
      exit 0
    fi

    echo ""
    echo "==> Audio ready: $filepath"

    if [[ "$auto_play" -eq 1 ]]; then
      echo "==> Auto-listening in mpv..."
      exec ${pkgs.mpv}/bin/mpv --no-video "$filepath"
    fi

    # Send interactive notification via libnotify
    action=$(${pkgs.libnotify}/bin/notify-send \
      -a "yt-pod" \
      -i audio-x-generic \
      -t 60000 \
      -A "play=▶ Listen in MPV" \
      -A "folder=📂 Open Folder" \
      "Podcast Ready" \
      "$title" 2>/dev/null || true)

    case "$action" in
      play|default|0)
        echo "==> Notification clicked: launching mpv..."
        exec ${pkgs.mpv}/bin/mpv --no-video "$filepath"
        ;;
      folder|1)
        exec xdg-open "$(dirname "$filepath")"
        ;;
    esac
  '';

  ytPlay = pkgs.writers.writeBashBin "yt-play" ''
    if [[ $# -gt 0 ]]; then
      exec ${pkgs.mpv}/bin/mpv --profile=fast "$@"
    fi
    latest=$(ls -td /Volumes/data/video/yt/mp4/* 2>/dev/null | grep -E '\.(mp4|mkv|webm)$' | head -n 1 || true)
    if [[ -n "$latest" && -f "$latest" ]]; then
      echo "Playing newest download: $latest"
      exec ${pkgs.mpv}/bin/mpv --profile=fast "$latest"
    else
      echo "No videos found in /Volumes/data/video/yt/mp4"
      exit 1
    fi
  '';

  ytAudio = pkgs.writers.writeBashBin "yt-audio" ''
    if [[ $# -gt 0 ]]; then
      exec ${pkgs.mpv}/bin/mpv --no-video "$@"
    fi
    latest=$(ls -td /Volumes/data/video/yt/mp3/* 2>/dev/null | grep -E '\.(mp3|m4a|opus|flac)$' | head -n 1 || true)
    if [[ -n "$latest" && -f "$latest" ]]; then
      echo "Playing newest podcast: $latest"
      exec ${pkgs.mpv}/bin/mpv --no-video "$latest"
    else
      echo "No podcasts found in /Volumes/data/video/yt/mp3"
      exit 1
    fi
  '';
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    self.modules."profiles.base-desktop-environment"
    self.modules."profiles.laptop"
  ];

  boot.supportedFilesystems = ["nfs"];
  ssh.ca.enableClient = true;

  fileSystems."/Volumes/data" = {
    device = "192.168.3.25:/data";
    fsType = "nfs";
    options = ["nfsvers=4" "soft" "rw" "intr"];
  };

  # Inbound ICMP ping allowed for diagnostics and network health audits
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [2049];

  # Hardware video acceleration for Intel HD Graphics 4400 (Haswell Gen 7.5).
  # Uses legacy i965 intel-vaapi-driver (modern intel-media-driver iHD only supports Gen 8+ / Broadwell+).
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
  };

  # Tailscale: disable accepting subnet routes on Aristotle to preserve native LAN routing
  # (prevents table 52 from hijacking direct LAN traffic and causing asymmetric routing drops, matching fern and eisen)
  services.tailscale.extraSetFlags = lib.mkForce [
    "--accept-dns=true"
    "--accept-routes=false"
  ];

  # Declarative Fleet DNS: Pi-hole on frieren (192.168.3.25 LAN / 100.97.61.65 Tailscale)
  # Scoped specifically to ~lan and ~frieren.lan routing domains.
  # NetworkManager accepts DHCP DNS on all connections (Wi-Fi, ethernet) so public Wi-Fi /
  # captive portals work normally without getting trapped on unroutable private nameservers.
  networking.nameservers = ["192.168.3.25" "100.97.61.65"];
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "192.168.3.25 100.97.61.65";
      FallbackDNS = "1.1.1.1 8.8.8.8";
      Domains = ["~lan" "~frieren.lan"];
    };
  };

  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };

  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home;
  };

  environment.systemPackages = with pkgs; [
    libnotify
    libva-utils
    dmidecode
    ytFrieren
    ytPod
    ytPlay
    ytAudio
  ];

  environment.shellAliases = {
    yt-dlpify = "yt-frieren";
  };

  system.stateVersion = "26.05";
}
