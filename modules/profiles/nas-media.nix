# NAS media offload CLI suite (yt-frieren, yt-pod, yt-play, yt-audio).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.nasMedia;

  isNasServer = builtins.elem "nas-server" (config.fleet.inventory.hosts.${config.networking.hostName}.software.traits or []);

  profileFlag =
    if cfg.mpvProfile != "" && cfg.mpvProfile != "default"
    then "--profile=${cfg.mpvProfile}"
    else "";

  ytFrieren = pkgs.writers.writeBashBin "yt-frieren" ''
    set -euo pipefail

    usage() {
      cat <<'USAGE_EOF'
    yt-frieren — Offload YouTube download to ${cfg.nasHost} NAS (1080p H.264 MP4)

    Usage:
      yt-frieren [OPTIONS] <URL> [extra yt-dlp args...]

    Options:
      -p, --play       Auto-play in mpv as soon as download finishes
      -b, --bg         Run download in background and return immediately
      -h, --help       Show this help message

    Target:
      Downloads are executed on ${cfg.nasHost} via SSH and saved to
      ${cfg.mountPoint}/${cfg.videoSubdir} (shared NAS storage pool).
      H.264 MP4 is prioritized and enforced via post-processing for smooth playback.
      A desktop notification appears on completion with an interactive play button.
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
      echo "yt-frieren: offloading download to ${cfg.nasHost} in background..."
      nohup "$0" --no-bg ''${auto_play:+-p} "$url" "''${extra_args[@]}" >/dev/null 2>&1 &
      echo "yt-frieren: background job started (PID: $!). Notification will alert on completion."
      exit 0
    fi

    echo "==> Offloading download to ${cfg.nasHost} NAS..."
    echo "==> Target directory: ${cfg.mountPoint}/${cfg.videoSubdir}"

    title="YouTube Video"
    filepath=""

    while IFS= read -r line; do
      if [[ "$line" =~ ^YT_TITLE:(.*)$ ]]; then
        title="''${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^YT_FILE:(.*)$ ]]; then
        filepath="''${BASH_REMATCH[1]}"
      else
        echo "$line"
      fi
    done < <(${pkgs.openssh}/bin/ssh -T ${cfg.nasHost} bash -s -- "$url" "''${extra_args[@]}" << 'REMOTESH'
    set -euo pipefail
    URL="$1"
    shift || true
    OUTDIR="${cfg.mountPoint}/${cfg.videoSubdir}"
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
      exec ${pkgs.mpv}/bin/mpv ${profileFlag} "$filepath"
    fi

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
        exec ${pkgs.mpv}/bin/mpv ${profileFlag} "$filepath"
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
    yt-pod — Offload YouTube podcast / audio download to ${cfg.nasHost} NAS (MP3)

    Usage:
      yt-pod [OPTIONS] <URL> [extra yt-dlp args...]

    Options:
      -p, --play       Auto-listen in mpv as soon as download finishes
      -b, --bg         Run download in background and return immediately
      -h, --help       Show this help message

    Target:
      Downloads are executed on ${cfg.nasHost} via SSH and saved to
      ${cfg.mountPoint}/${cfg.audioSubdir} (shared NAS storage pool).
      Audio is extracted to high-quality MP3 with embedded metadata/thumbnail.
      A desktop notification appears on completion with an interactive play button.
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
      echo "yt-pod: offloading audio download to ${cfg.nasHost} in background..."
      nohup "$0" --no-bg ''${auto_play:+-p} "$url" "''${extra_args[@]}" >/dev/null 2>&1 &
      echo "yt-pod: background job started (PID: $!). Notification will alert on completion."
      exit 0
    fi

    echo "==> Offloading audio download to ${cfg.nasHost} NAS..."
    echo "==> Target directory: ${cfg.mountPoint}/${cfg.audioSubdir}"

    title="YouTube Audio"
    filepath=""

    while IFS= read -r line; do
      if [[ "$line" =~ ^YT_TITLE:(.*)$ ]]; then
        title="''${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^YT_FILE:(.*)$ ]]; then
        filepath="''${BASH_REMATCH[1]}"
      else
        echo "$line"
      fi
    done < <(${pkgs.openssh}/bin/ssh -T ${cfg.nasHost} bash -s -- "$url" "''${extra_args[@]}" << 'REMOTESH'
    set -euo pipefail
    URL="$1"
    shift || true
    OUTDIR="${cfg.mountPoint}/${cfg.audioSubdir}"
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
      exec ${pkgs.mpv}/bin/mpv ${profileFlag} "$@"
    fi
    latest=$(ls -td "${cfg.mountPoint}/${cfg.videoSubdir}"/* 2>/dev/null | grep -E '\.(mp4|mkv|webm)$' | head -n 1 || true)
    if [[ -n "$latest" && -f "$latest" ]]; then
      echo "Playing newest download: $latest"
      exec ${pkgs.mpv}/bin/mpv ${profileFlag} "$latest"
    else
      echo "No videos found in ${cfg.mountPoint}/${cfg.videoSubdir}"
      exit 1
    fi
  '';

  ytAudio = pkgs.writers.writeBashBin "yt-audio" ''
    if [[ $# -gt 0 ]]; then
      exec ${pkgs.mpv}/bin/mpv --no-video "$@"
    fi
    latest=$(ls -td "${cfg.mountPoint}/${cfg.audioSubdir}"/* 2>/dev/null | grep -E '\.(mp3|m4a|opus|flac)$' | head -n 1 || true)
    if [[ -n "$latest" && -f "$latest" ]]; then
      echo "Playing newest podcast: $latest"
      exec ${pkgs.mpv}/bin/mpv --no-video "$latest"
    else
      echo "No podcasts found in ${cfg.mountPoint}/${cfg.audioSubdir}"
      exit 1
    fi
  '';
in {
  options.profiles.nasMedia = {
    enable = lib.mkEnableOption "NAS media offload CLI suite (yt-frieren, yt-pod, yt-play, yt-audio)";

    nasHost = lib.mkOption {
      type = lib.types.str;
      default = "frieren";
      description = "Target NAS host running yt-dlp over SSH";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/data";
      description = "Root of the shared NAS mount";
    };

    videoSubdir = lib.mkOption {
      type = lib.types.str;
      default = "video/yt/mp4";
      description = "Subdirectory inside mountPoint for video downloads";
    };

    audioSubdir = lib.mkOption {
      type = lib.types.str;
      default = "video/yt/mp3";
      description = "Subdirectory inside mountPoint for podcast/audio downloads";
    };

    mpvProfile = lib.mkOption {
      type = lib.types.str;
      default =
        if
          (builtins.elem "gpu-low" (config.fleet.inventory.hosts.${config.networking.hostName}.software.traits or []))
          || (config.networking.hostName == "aristotle")
        then "fast"
        else "default";
      description = "Default MPV profile for playback ('fast' on low-power hardware, 'default' otherwise)";
    };
  };

  config = lib.mkIf (cfg.enable && !isNasServer) {
    environment.systemPackages = [
      pkgs.libnotify
      ytFrieren
      ytPod
      ytPlay
      ytAudio
    ];

    environment.shellAliases = {
      yt-dlpify = "yt-frieren";
    };
  };
}
