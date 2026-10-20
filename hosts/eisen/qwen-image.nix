# Qwen-Image-2.1-Turbo — image generation / editing on Eisen.
{
  config,
  lib,
  pkgs,
  ...
}: let
  imageDir = "/mnt/storage/image/models";
  port = 8282;

  # stable-diffusion.cpp, pinned to a commit with Qwen-Image 2.1 support.
  # nixpkgs' stable-diffusion-cpp pins 656a135 (2026-09-18), which predates
  # sd.cpp's day-0 Qwen-Image 2.1 support (2026-09-20). Override the src to
  # f0aac52 (2026-10-17 master) and keep nixpkgs' build (CMake + ggml +
  # Vulkan). fetchSubmodules=true is REQUIRED (ggml is a submodule; without
  # it cmake/ggml.cmake fails on get_target_property). vulkanSupport=true
  # via .override (adds the Vulkan buildInputs + SD_VULKAN=ON; nixpkgs
  # defaults to CPU-only). sha256 is fakeHash — the build error prints the
  # correct hash for the submodule-inclusive fetch; update it and rebuild.
  sdCpp = (pkgs.stable-diffusion-cpp.override {vulkanSupport = true;}).overrideAttrs (_old: {
    version = "2026-10-17-f0aac52";
    src = pkgs.fetchFromGitHub {
      owner = "leejet";
      repo = "stable-diffusion.cpp";
      rev = "f0aac524d3f29140e60ba78f3cfb16d6acea87db";
      fetchSubmodules = true;
      sha256 = "sha256-8Kjey4MaifK/GDEJ3dyamCmPq7AdtAxf+Zid6CKXFvQ=";
    };
  });

  # Idempotent, resumable weight fetch — runs only when the file is absent.
  # Same pattern as llm-server.nix mkFetch.
  mkFetch = {
    file,
    url,
  }: {
    description = "Fetch ${file} if missing";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    unitConfig.ConditionPathExists = "!${file}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "fetch-${baseNameOf file}" ''
        set -euo pipefail
        ${pkgs.coreutils}/bin/echo "Fetching ${url}"
        ${pkgs.curl}/bin/curl -fL --retry 5 --retry-delay 5 -C - \
          -o "${file}.part" "${url}"
        ${pkgs.coreutils}/bin/mv -f "${file}.part" "${file}"
      '';
    };
  };
in {
  systemd.tmpfiles.rules = [
    "d ${imageDir} 0755 devji users - -"
  ];

  systemd.services."eisen-image-dit" = mkFetch {
    file = "${imageDir}/qwen-image-2.1-turbo-Q8_0.gguf";
    url = "https://huggingface.co/unsloth/Qwen-Image-2.1-Turbo-GGUF/resolve/main/qwen-image-2.1-turbo-Q8_0.gguf";
  };

  systemd.services."eisen-image-encoder" = mkFetch {
    file = "${imageDir}/Qwen3VL-8B-Instruct-Q4_K_M.gguf";
    url = "https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/Qwen3VL-8B-Instruct-Q4_K_M.gguf";
  };

  systemd.services."eisen-image-vae" = mkFetch {
    file = "${imageDir}/qwen_image_2.1_vae_bf16.safetensors";
    url = "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors";
  };

  systemd.services."eisen-image-mmproj" = mkFetch {
    file = "${imageDir}/mmproj-Qwen3VL-8B-Instruct-F16.gguf";
    url = "https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-8B-Instruct-F16.gguf";
  };

  # --- Image service: persistent sd-server + socket activation + idle-stop
  # The wrapper (qwen-image-server.py) is the front-end on :8282. systemd
  # holds the port (qwen-image.socket); the first connection starts the
  # service, whose wrapper takes over systemd's listening FD. On first
  # request it unloads llama-swap (claiming the GPU, 429 if a generation
  # is running) and spawns sd-server (persistent, :8283) with the fixed
  # Turbo defaults (--steps 8 --cfg-scale 1.0 --sampling-method euler
  # --sigmas <Turbo 9-value list>). The weights stay loaded across
  # generations, so the HDD cold load is paid once per session, not per
  # image. While sd-server holds the GPU the wrapper writes
  # RUNTIME_DIRECTORY/active; the LLM router checks it and 429s chat
  # generations (LLM wins by not starting, not by killing).
  # The idle timer stops the service after 900 s with no request, killing
  # sd-server and freeing the GPU. The socket stays listening, so the next
  # request wakes it again. Nothing may `want` qwen-image — nginx and
  # tailscale-serve-image deliberately do not — or boot would pull it up
  # and defeat on-demand.
  systemd.sockets."qwen-image" = {
    description = "Qwen-Image socket (on-demand activation)";
    wantedBy = ["sockets.target"];
    socketConfig = {
      ListenStream = "127.0.0.1:${toString port}";
      Accept = false;
    };
  };

  systemd.services."qwen-image" = {
    description = "Qwen-Image-2.1-Turbo image server (OpenAI-compatible, :8282)";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    requires = ["qwen-image.socket"];
    # No wantedBy: the socket activates this on first connection.
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python ${./qwen-image-server.py}";
      Environment = [
        "PORT=${toString port}"
        "SD_SERVER=${lib.getExe' sdCpp "sd-server"}"
        "SD_PORT=8283"
        "DIT=${imageDir}/qwen-image-2.1-turbo-Q8_0.gguf"
        "ENCODER=${imageDir}/Qwen3VL-8B-Instruct-Q4_K_M.gguf"
        "VAE=${imageDir}/qwen_image_2.1_vae_bf16.safetensors"
        "MMPROJ=${imageDir}/mmproj-Qwen3VL-8B-Instruct-F16.gguf"
        "LLAMA_SWAP=http://127.0.0.1:8080"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
      # First request's cold load (HDD, ~12 GB) can take minutes.
      TimeoutStartSec = 600;
      # Holds the active lock + last-request record the idle timer reads.
      RuntimeDirectory = "qwen-image";
      # sd-server needs the GPU (Vulkan via /dev/dri). DynamicUser's
      # default device policy denies it, so sd-server hangs/fails and
      # never becomes healthy (the manual run as devji worked because
      # devji has /dev/dri). Allow the DRI nodes explicitly.
      PrivateDevices = false;
      DeviceAllow = [
        "/dev/dri/renderD128 rw"
        "/dev/dri/card0 rw"
      ];
      DynamicUser = true;
      PrivateTmp = true;
    };
  };

  # --- Idle stop: free the GPU after 900 s with no request -----------------
  # Same pattern as laya-serve-idle: the timer fires every 5 min; the
  # oneshot stops the service when no request has been served within
  # idleTimeout. The socket stays listening, so the next connection
  # re-activates the service. A stop racing a just-arrived request fails
  # that one request cleanly (502 at the caller), and the next request
  # wakes the image server again.
  systemd.services."qwen-image-idle" = {
    description = "Stop Qwen-Image if idle past the timeout";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "qwen-image-idle-check" ''
        set -eu
        systemctl=${config.systemd.package}/bin/systemctl
        if ! "$systemctl" -q is-active qwen-image.service; then
          exit 0
        fi
        last="/run/qwen-image/last-request"
        if [ ! -f "$last" ]; then
          exit 0
        fi
        now=$(${pkgs.coreutils}/bin/date +%s)
        mtime=$(${pkgs.coreutils}/bin/stat -c %Y "$last")
        if [ $((now - mtime)) -ge 900 ]; then
          "$systemctl" stop qwen-image.service
        fi
      '';
    };
  };

  systemd.timers."qwen-image-idle" = {
    description = "Stop Qwen-Image after the idle timeout";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      Unit = "qwen-image-idle.service";
    };
  };

  # --- LAN: http://eisen.lan/images/v1/images/generations -----------------
  # Merges into the eisen.lan vhost declared in llm-server.nix; the
  # /images/ prefix is stripped by the trailing slash on proxyPass, so the
  # service sees /v1/images/generations. (Same pattern as parakeet /stt/.)
  services.nginx.virtualHosts."eisen.lan".locations."/images/" = {
    proxyPass = "http://127.0.0.1:${toString port}/";
    extraConfig = ''
      # A Turbo generation can take minutes on the first run (cold weights).
      proxy_read_timeout 900s;
      proxy_send_timeout 900s;
      client_max_body_size 25m;
    '';
  };

  # --- Tailnet: https://eisen.<tailnet>.ts.net:8445/v1/images/generations -
  # Node serve (same pattern as tailscale-serve-node in llm-server.nix).
  # Idempotent — re-applying the same target is a no-op.
  systemd.services."tailscale-serve-image" = {
    description = "Serve Qwen-Image on the node's tailnet HTTPS name (:8445)";
    after = [
      "tailscaled.service"
      "tailscaled-autoconnect.service"
    ];
    wants = ["tailscaled.service"];
    wantedBy = ["multi-user.target"];
    partOf = ["tailscaled.service"];
    unitConfig = {
      StartLimitIntervalSec = 300;
      StartLimitBurst = 30;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = pkgs.writeShellScript "wait-for-tailscale-image" ''
        until ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; do sleep 2; done
      '';
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https=8445 http://127.0.0.1:${toString port}";
    };
  };
}
