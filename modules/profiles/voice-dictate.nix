# Voice dictation: press the hotkey, speak, press it again, and the transcript
# is typed into the focused window.
#
# Two things this profile owns that the shell script it replaces could not:
#    #   1. The key is decrypted from the fleet's sops plane at use time, not read
#      from a plaintext file in $HOME. The encrypted file is a store path (it is
#      already in this flake), so the script carries no secret and the value
#      never enters the nix store. Decryption needs an identity, which every
#      host has: TPM-sealed on netbook, SSH-derived elsewhere.
#   2. The body is a `writeShellApplication`, so shellcheck runs on it at build
#      and the interpreter's inputs are the closure rather than whatever $PATH
#      the niri session happened to inherit.
#
# The script decrypts once per cache window instead of once per keystroke: on
# netbook the identity is unsealed from the TPM, and paying that on every
# dictation would be worse than the transcription itself. The cache lives in
# $XDG_RUNTIME_DIR (tmpfs, 0600, gone at logout), never on disk.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.voiceDictate;

  keyPathJson = builtins.toJSON cfg.keyPath;
  sounds = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo";

  voiceDictate = pkgs.writeShellApplication {
    name = "voice-dictate";
    runtimeInputs = with pkgs; [
      curl
      coreutils
      gnused
      pipewire
      sops
      systemd # busctl: free desktops have no libnotify CLI, mako is the server
      wl-clipboard
      wtype
    ];
    text = ''
      set -euo pipefail

      sounds=${lib.escapeShellArg sounds}
      sops_file=${lib.escapeShellArg "${cfg.sopsFile}"}
      key_path=${lib.escapeShellArg keyPathJson}
      model=${lib.escapeShellArg cfg.model}
      prompt=${lib.escapeShellArg cfg.prompt}
      key_cache_seconds=${toString cfg.keyCacheSeconds}
      watchdog_seconds=${toString cfg.recordSeconds}

      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/voice-dictate"
      install -d -m 700 "$state_dir"
      audio="$state_dir/input.wav"
      pid_file="$state_dir/record.pid"
      err_file="$state_dir/last.err"
      key_cache="$state_dir/groq.key"

      notify() {
        busctl --user call org.freedesktop.Notifications \
          /org/freedesktop/Notifications org.freedesktop.Notifications \
          Notify "susssasa{sv}i" "voice-dictate" 0 "" "$1" "$2" 0 0 "''${3:-3000}" \
          >/dev/null 2>&1 || true
      }

      play_sound() {
        [ -f "$sounds/$1.oga" ] || return 0
        pw-play "$sounds/$1.oga" >/dev/null 2>&1 &
      }

      # Groq key: env override, then the tmpfs cache, then sops. A failed
      # decryption must say why — "key not found" hid a broken identity for
      # hours on the host this replaces.
      groq_key() {
        if [ -n "''${GROQ_API_KEY:-}" ]; then
          printf '%s' "$GROQ_API_KEY"
          return 0
        fi
        if [ -s "$key_cache" ]; then
          age=$(( $(date +%s) - $(stat -c %Y "$key_cache") ))
          if [ "$age" -lt "$key_cache_seconds" ]; then
            cat "$key_cache"
            return 0
          fi
        fi
        if ! key=$(sops decrypt --extract "$key_path" "$sops_file" 2>"$err_file"); then
          return 1
        fi
        (umask 077 && printf '%s' "$key" >"$key_cache")
        printf '%s' "$key"
      }

      stop_recorder() {
        local pid
        pid=$(cat "$pid_file" 2>/dev/null || true)
        [ -n "$pid" ] || return 0
        # pw-record finalises the WAV on SIGINT, so the signal must land on the
        # recorder and not be swallowed by a wrapper. setsid made it a session
        # leader, so the group form reaches it either way.
        kill -INT -- "-$pid" 2>/dev/null || kill -INT "$pid" 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          kill -0 "$pid" 2>/dev/null || break
          sleep 0.05
        done
      }

      if [ -f "$pid_file" ]; then
        stop_recorder
        rm -f "$pid_file"
        play_sound bell
        notify "Voice Dictation" "⏳ Transcribing..." 2000

        if ! api_key=$(groq_key); then
          play_sound dialog-error
          notify "Voice Dictation Error" \
            "no Groq key: sops could not decrypt $sops_file ($(head -c 160 "$err_file" 2>/dev/null))" 8000
          exit 1
        fi
        if [ ! -s "$audio" ]; then
          play_sound dialog-error
          notify "Voice Dictation Error" "No audio recorded." 3000
          exit 1
        fi

        # --fail-with-body: a 4xx must end the run with its error, never be
        # typed into the focused window as if it were speech.
        if ! text=$(curl -sS --fail-with-body -m 60 --retry 2 \
          -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
          -H "Authorization: Bearer $api_key" \
          -F "file=@$audio" \
          -F "model=$model" \
          -F "prompt=$prompt" \
          -F "response_format=text" 2>"$err_file"); then
          play_sound dialog-error
          notify "Voice Dictation Error" \
            "transcription failed: $(head -c 180 "$err_file")" 8000
          rm -f "$audio"
          exit 1
        fi

        text=$(printf '%s' "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        # Belt and braces: an error body that slipped past --fail is not speech.
        case "$text" in
          \{*\"error\"*) text="" ;;
        esac

        if [ -n "$text" ]; then
          printf '%s' "$text" | wl-copy
          printf '%s' "$text" | wl-copy --primary 2>/dev/null || true
          play_sound complete
          notify "Voice Dictation" "✍️ Pasted: $text" 3000
          sleep 0.05
          wtype -s 5 -- "$text"
        else
          play_sound dialog-warning
          notify "Voice Dictation" "No speech detected." 2000
        fi
        rm -f "$audio"
      else
        rm -f "$audio"
        # One recording at a time: a second hotkey press stops the first rather
        # than opening a second microphone stream over it.
        setsid pw-record --format s16 --rate 16000 --channels 1 "$audio" &
        echo "$!" >"$pid_file"
        (
          sleep "$watchdog_seconds"
          if [ -f "$pid_file" ]; then
            stop_recorder
            rm -f "$pid_file"
            notify "Voice Dictation" "recording stopped after ''${watchdog_seconds}s — press again to transcribe" 4000
          fi
        ) >/dev/null 2>&1 &
        play_sound message-new-instant
        notify "Voice Dictation" "🎙️ Recording... (press ''${VOICE_DICTATE_HOTKEY:-the hotkey} again to transcribe & paste)" 3000
      fi
    '';
  };
in {
  options.profiles.voiceDictate = {
    enable = lib.mkEnableOption "voice dictation (Groq Whisper) with the key read from sops";

    package = lib.mkOption {
      type = lib.types.package;
      default = voiceDictate;
      defaultText = lib.literalMD "the packaged `voice-dictate` script";
      description = "The voice-dictate CLI.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../secrets.yaml;
      defaultText = lib.literalMD "`modules/secrets.yaml`";
      description = ''
        Encrypted sops file holding the Groq key; only its ciphertext enters the
        closure. This must be a TRACKED file: `modules/secrets/` is a submodule and
        is absent from the flake source, so a path into it evaluates to nothing
        (see the same note on delphi's `deepseek/api/key`).
      '';
    };

    keyPath = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["groq"];
      description = "Path of the key inside `sopsFile`, as used by `sops decrypt --extract`.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "whisper-large-v3";
      description = "Groq transcription model.";
    };

    prompt = lib.mkOption {
      type = lib.types.str;
      default = "Unix shell commands, /etc/nixos, --help, git status, code symbols: / \\ _ - = 0 ; : , paths, functions";
      description = "Hint passed to the model so technical dictation is spelled as written.";
    };

    keyCacheSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 900;
      description = "How long a decrypted key may stay in `$XDG_RUNTIME_DIR` before sops runs again.";
    };

    recordSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 45;
      description = "Watchdog: never leave the microphone open longer than this.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];
  };
}
